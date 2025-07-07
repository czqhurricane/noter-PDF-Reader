import AVFoundation
import AVKit
import SwiftUI

// 添加一个辅助类来处理KVO
class PlayerItemObserver: NSObject {
    private var player: AVPlayer?
    private var startTime: Double
    private var onReadyToPlay: (() -> Void)?
    private var observation: NSKeyValueObservation?

    init(player: AVPlayer?, startTime: Double, onReadyToPlay: @escaping () -> Void) {
        self.player = player
        self.startTime = startTime
        self.onReadyToPlay = onReadyToPlay
        super.init()

        if let playerItem = player?.currentItem {
            observation = playerItem.observe(\.status, options: [.new, .old]) { [weak self] item, _ in
                guard let self = self else { return }
                if item.status == .readyToPlay {
                    let targetTime = CMTime(seconds: self.startTime, preferredTimescale: 1000)
                    self.player?.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
                        if finished {
                            self?.player?.play()
                            self?.onReadyToPlay?()
                        }
                        // 清理闭包避免循环引用
                        self?.observation = nil
                        self?.onReadyToPlay = nil
                    }
                }
            }
        }
    }

    deinit {
        // 不再需要手动移除观察者
    }
}

struct VideoPlayerView: View {
    let videoURL: URL
    let startTime: Double
    let endTime: Double?

    @State private var player: AVPlayer?
    @State private var isPlaying: Bool = false
    @State private var timeObserverToken: Any?
    @State private var playerViewController: AVPlayerViewController?
    @State private var playerObserver: PlayerItemObserver? // 添加观察者对象
    @State private var isRestarting = false // 添加状态变量用于跟踪重启操作
    @State private var isFullScreen = false // 添加状态以跟踪全屏

    init(videoURL: URL, startTime: Double = 0, endTime: Double? = nil) {
        self.videoURL = videoURL
        self.startTime = startTime
        self.endTime = endTime

        NSLog("✅ VideoPlayerView.swift -> VideoPlayerView.init, \(videoURL), \(startTime), \(String(describing: endTime))")
    }

    var body: some View {
        VStack {
            AVPlayerControllerRepresentable(player: player, isFullScreen: $isFullScreen, playerViewControllerCallback: { controller in
                self.playerViewController = controller
            })
            .aspectRatio(16 / 9, contentMode: .fit)
            .onAppear {
                // 创建播放器并设置起始时间
                setupPlayer()
            }
            .onDisappear {
                if !isFullScreen {
                    // 停止播放并释放资源
                    removePeriodicTimeObserver()
                    player?.pause()
                    player = nil
                    playerObserver = nil // 释放观察者
                }
            }

            HStack {
                Button(action: {
                    if isPlaying {
                        player?.pause()
                    } else {
                        player?.play()
                    }
                    isPlaying.toggle()
                }) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.blue)
                }

                Button(action: {
                    let currentTime = player?.currentTime().seconds ?? 0
                    let targetTime = CMTime(seconds: max(startTime, currentTime - 10), preferredTimescale: 1)
                    player?.seek(to: targetTime)
                }) {
                    Image(systemName: "gobackward.10")
                        .font(.system(size: 30))
                        .foregroundColor(.blue)
                }

                Button(action: {
                    let currentTime = player?.currentTime().seconds ?? 0
                    let maxTime = endTime ?? Double.infinity
                    let targetTime = CMTime(seconds: min(maxTime, currentTime + 10), preferredTimescale: 1)
                    player?.seek(to: targetTime)
                }) {
                    Image(systemName: "goforward.10")
                        .font(.system(size: 30))
                        .foregroundColor(.blue)
                }
            }
            .padding()
        }
        .navigationBarTitle("视频播放器", displayMode: .inline)
    }

    private func setupPlayer() {
        // 创建播放器
        let playerItem = AVPlayerItem(url: videoURL)
        player = AVPlayer(playerItem: playerItem)

        // 添加时间观察器来监控播放进度
        addPeriodicTimeObserver()

        // 创建并设置观察者
        playerObserver = PlayerItemObserver(player: player, startTime: startTime) {
            self.isPlaying = true
        }
    }

    private func addPeriodicTimeObserver() {
        guard let player = player else { return }

        // Capture startTime and endTime at this moment
        let startTime = self.startTime
        let endTime = self.endTime

        // 每0.5秒检查一次播放进度
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))

        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak player] time in
            guard let player = player else { return }
            if self.isRestarting { return }

            let currentTime = time.seconds

            // 如果设置了endTime并且当前时间超过了endTime，则回到startTime
            if let endTime = self.endTime, currentTime >= endTime {
                self.isRestarting = true
                let targetTime = CMTime(seconds: self.startTime, preferredTimescale: 1000)
                NSLog("✅ VideoPlayerView.swift -> VideoPlayerView.addPeriodicTimeObserver, \(targetTime)")
                player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                    player.play()
                    self.isRestarting = false
                }
            }
            // 如果没有设置endTime，则检查是否接近视频结尾
            else if self.endTime == nil {
                if let duration = player.currentItem?.duration.seconds, duration.isFinite, currentTime >= duration - 0.5 {
                    self.isRestarting = true
                    let targetTime = CMTime(seconds: self.startTime, preferredTimescale: 1000)
                    player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                        player.play()
                        self.isRestarting = false
                    }
                }
            }
        }
    }

    private func removePeriodicTimeObserver() {
        if let token = timeObserverToken, let player = player {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }
}

// 视频播放器组件
struct AVPlayerControllerRepresentable: UIViewControllerRepresentable {
    let player: AVPlayer?
    @Binding var isFullScreen: Bool
    var playerViewControllerCallback: ((AVPlayerViewController) -> Void)?

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true

        // 设置代理以处理全屏模式
        context.coordinator.playerViewController = controller
        controller.delegate = context.coordinator

        // 回调函数，传递控制器引用
        if let callback = playerViewControllerCallback {
            callback(controller)
        }

        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context _: Context) {
        uiViewController.player = player
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        var parent: AVPlayerControllerRepresentable
        var playerViewController: AVPlayerViewController?
        private var wasPlaying: Bool = false
        private var currentTime: CMTime?

        init(_ parent: AVPlayerControllerRepresentable) {
            self.parent = parent
        }

        // 处理全屏模式变化
        func playerViewController(_ playerViewController: AVPlayerViewController, willBeginFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator) {
            parent.isFullScreen = true
            // 保存当前播放器和播放状态
            let currentPlayer = playerViewController.player
            wasPlaying = currentPlayer?.rate != 0
            currentTime = currentPlayer?.currentTime()

            // 确保在全屏过程中保持播放器引用
            coordinator.animate(alongsideTransition: nil) { [weak self] _ in
                // 动画完成后恢复播放状态
                if let time = self?.currentTime {
                    currentPlayer?.seek(to: time, completionHandler: { _ in
                        if self?.wasPlaying == true {
                            currentPlayer?.play()
                        }
                    })
                }
            }
        }

        func playerViewController(_ playerViewController: AVPlayerViewController, willEndFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator) {
            parent.isFullScreen = false
            // 退出全屏模式前保存当前播放器状态
            let currentPlayer = playerViewController.player
            let wasPlayingInFullScreen = currentPlayer?.rate != 0
            let timeInFullScreen = currentPlayer?.currentTime()

            // 使用动画协调器确保平滑过渡
            coordinator.animate(alongsideTransition: nil) { [weak self] _ in
                // 动画完成后确保视频继续播放并保持时间位置
                if let time = timeInFullScreen {
                    currentPlayer?.seek(to: time, completionHandler: { _ in
                        if wasPlayingInFullScreen {
                            currentPlayer?.play()
                        }
                    })
                }
                // 更新父视图中的播放状态
                if let parentView = self?.parent.player, parentView != currentPlayer {
                    parentView.seek(to: timeInFullScreen ?? .zero)
                    if wasPlayingInFullScreen {
                        parentView.play()
                    }
                }
            }
        }
    }
}

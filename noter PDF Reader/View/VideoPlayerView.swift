import AVFoundation
import AVKit
import SwiftUI

// 一个辅助类来处理KVO
class PlayerItemObserver: NSObject {
    private var player: AVPlayer?
    private var startTime: Double
    private var onReadyToPlay: (() -> Void)?
    private var observation: NSKeyValueObservation?
    private var errorObservation: NSKeyValueObservation?

    init(player: AVPlayer?, startTime: Double, onReadyToPlay: @escaping () -> Void) {
        self.player = player
        self.startTime = startTime
        self.onReadyToPlay = onReadyToPlay
        super.init()

        if let playerItem = player?.currentItem {
            // 监听播放状态
            observation = playerItem.observe(\.status, options: [.new, .old]) { [weak self] item, _ in
                guard let self = self else { return }

                switch item.status {
                case .readyToPlay:
                    NSLog("✅ VideoPlayerView.swift -> PlayerItemObserver.init, Item ready to play")

                    let targetTime = CMTime(seconds: self.startTime, preferredTimescale: 1000)
                    self.player?.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
                        if finished {
                            self?.player?.play()
                            self?.onReadyToPlay?()
                        }
                    }
                case .failed:
                    if let error = item.error {
                        NSLog("❌ VideoPlayerView.swift -> PlayerItemObserver.init, Item failed with error: \(error.localizedDescription)")
                    }
                case .unknown:
                    NSLog("❌ VideoPlayerView.swift -> PlayerItemObserver.init, Item status unknown")
                @unknown default:
                    break
                }
            }
            // 监听加载进度
            playerItem.addObserver(self, forKeyPath: "loadedTimeRanges", options: .new, context: nil)
        }
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change _: [NSKeyValueChangeKey: Any]?, context _: UnsafeMutableRawPointer?) {
        if keyPath == "loadedTimeRanges", let playerItem = object as? AVPlayerItem {
            let loadedTimeRanges = playerItem.loadedTimeRanges
            if let timeRange = loadedTimeRanges.first?.timeRangeValue {
                let startTime = CMTimeGetSeconds(timeRange.start)
                let duration = CMTimeGetSeconds(timeRange.duration)
                let totalBuffer = startTime + duration

                NSLog("✅ VideoPlayerView.swift -> PlayerItemObserver.observeValue, Buffer progress: \(totalBuffer) seconds")
            }
        }
    }

    deinit {
        // 移除观察者
        if let playerItem = player?.currentItem {
            playerItem.removeObserver(self, forKeyPath: "loadedTimeRanges")
        }

        NSLog("❌ VideoPlayerView.swift -> PlayerItemObserver.deinit, Observer released")
    }
}

struct VideoPlayerView: View {
    let videoURL: URL
    let startTime: Double
    let endTime: Double

    private struct PlayerConfig: Equatable {
        let videoURL: URL
        let startTime: Double
        let endTime: Double
    }

    @State private var player: AVPlayer?
    @State private var isPlaying: Bool = false
    @State private var timeObserverToken: Any?
    @State private var playerViewController: AVPlayerViewController?
    @State private var playerObserver: PlayerItemObserver?       // 观察者对象
    @State private var isRestarting = false                      // 状态变量用于跟踪重启操作
    @State private var isFullScreen = false                      // 状态以跟踪全屏
    @State private var playbackError: Error? = nil
    @State private var retryCount: Int = 0
    @State private var isAccessingSecurityScopedResource = false // 安全作用域资源访问状态
    @State private var lastConfig: PlayerConfig?

    init(videoURL: URL, startTime: Double = 0, endTime: Double = 0) {
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                // 创建播放器并设置起始时间
                setupPlayer()
                lastConfig = PlayerConfig(videoURL: videoURL, startTime: startTime, endTime: endTime)
            }
            .onChange(of: videoURL) { _ in checkForConfigChange() }
            .onChange(of: startTime) { _ in checkForConfigChange() }
            .onChange(of: endTime) { _ in checkForConfigChange() }
            .onDisappear {
                if !isFullScreen {
                    // 停止播放并释放资源
                    cleanupPlayer()
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
        // 开始访问安全作用域资源
        let accessGranted = videoURL.startAccessingSecurityScopedResource()
        isAccessingSecurityScopedResource = accessGranted

        NSLog("✅ VideoPlayerView.swift -> VideoPlayerView.setupPlayer, 安全作用域资源访问状态: \(accessGranted)")

        // 创建播放器
        let asset = AVURLAsset(url: videoURL, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        let playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)

        if !accessGranted {
            NSLog("❌ VideoPlayerView.swift -> VideoPlayerView.setupPlayer, 无法获取安全作用域资源访问权限，但仍尝试播放")
            NSLog("❌ VideoPlayerView.swift -> VideoPlayerView.setupPlayer, URL: \(videoURL.absoluteString)")
            NSLog("❌ VideoPlayerView.swift -> VideoPlayerView.setupPlayer, URL scheme: \(videoURL.scheme ?? "无")")
            NSLog("❌ VideoPlayerView.swift -> VideoPlayerView.setupPlayer, URL isFileURL: \(videoURL.isFileURL)")
        }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay, .allowBluetooth, .allowBluetoothA2DP])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            NSLog("✅ VideoPlayerView.swift -> VideoPlayerView.setupPlayer, Audio session configured successfully")

        } catch {
            NSLog("❌ VideoPlayerView.swift -> VideoPlayerView.setupPlayer, Failed to set audio session category: \(error)")

            playbackError = error

            // 尝试使用默认配置
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback)
                try AVAudioSession.sharedInstance().setActive(true)

                NSLog("✅ VideoPlayerView.swift -> VideoPlayerView.setupPlayer, 使用默认配置激活音频会话成功")
            } catch {
                NSLog("❌ VideoPlayerView.swift -> VideoPlayerView.setupPlayer, 使用默认配置激活音频会话失败: \(error)")
            }
        }

        // 通知监听播放错误
        NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: playerItem, queue: .main) { notification in
            if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                NSLog("❌ VideoPlayerView.swift -> Playback failed with error: \(error.localizedDescription)")

                self.playbackError = error

                // 尝试重试播放（最多3次）
                if self.retryCount < 3 {
                    self.retryCount += 1
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.setupPlayer()
                    }
                }
            }
        }

        // 时间观察器来监控播放进度
        addPeriodicTimeObserver()

        // 创建并设置观察者
        playerObserver = PlayerItemObserver(player: player, startTime: startTime) {
            self.isPlaying = true
        }
    }

    private func cleanupPlayer() {
        // 移除所有通知观察者
        NotificationCenter.default.removeObserver(self)

        // 停止播放并释放资源
        removePeriodicTimeObserver()
        player?.pause()
        // 释放当前播放项
        player?.replaceCurrentItem(with: nil)
        player = nil
        // 释放观察者
        playerObserver = nil

        // 停用音频会话 - 错误处理
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            NSLog("✅ VideoPlayerView.swift -> cleanupPlayer, Audio session deactivated successfully")
        } catch {
            NSLog("❌ VideoPlayerView.swift -> cleanupPlayer, Failed to deactivate audio session: \(error)")
        }

        // 停止访问安全作用域资源
        if isAccessingSecurityScopedResource {
            videoURL.stopAccessingSecurityScopedResource()
            isAccessingSecurityScopedResource = false
            NSLog("✅ VideoPlayerView.swift -> cleanupPlayer, 已停止访问安全作用域资源")
        }
    }

    private func checkForConfigChange() {
        let newConfig = PlayerConfig(videoURL: videoURL, startTime: startTime, endTime: endTime)
        guard newConfig != lastConfig else { return }

        cleanupPlayer()
        setupPlayer()
        lastConfig = newConfig
    }

    private func addPeriodicTimeObserver() {
        guard let player = player else { return }

        let startTime = self.startTime
        let endTime = self.endTime

        // 每0.5秒检查一次播放进度
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))

        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak player] time in
            guard let player = player else { return }
            if self.isRestarting { return }

            let currentTime = time.seconds

            // 如果设置了 endTime 并且当前时间超过了 endTime，则回到 startTime
            if  endTime > 0 && currentTime >= endTime {
                self.isRestarting = true
                let targetTime = CMTime(seconds: self.startTime, preferredTimescale: 1000)

                NSLog("✅ VideoPlayerView.swift -> VideoPlayerView.addPeriodicTimeObserver, 设置了 endTime, \(targetTime)")

                player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                    player.play()
                    self.isRestarting = false
                }
            }
            // 如果没有设置endTime，则检查是否接近视频结尾
            else if self.endTime == 0 {
                if let duration = player.currentItem?.duration.seconds, duration.isFinite, currentTime >= duration - 0.5 {
                    self.isRestarting = true
                    let targetTime = CMTime(seconds: self.startTime, preferredTimescale: 1000)

                    NSLog("✅ VideoPlayerView.swift -> VideoPlayerView.addPeriodicTimeObserver, 没有设置 endTime, \(targetTime)")

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
        private var originalPlayer: AVPlayer?

        init(_ parent: AVPlayerControllerRepresentable) {
            self.parent = parent
        }

        // 处理全屏模式变化
        func playerViewController(_ playerViewController: AVPlayerViewController, willBeginFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator) {
            parent.isFullScreen = true
            // 保存当前播放器和播放状态
            let currentPlayer = playerViewController.player
            originalPlayer = parent.player
            wasPlaying = currentPlayer?.rate != 0
            currentTime = currentPlayer?.currentTime()

            // 暂停原始播放器，避免双重声音
            parent.player?.pause()
            // 确保完全停止
            parent.player?.rate = 0

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

            // 暂停全屏播放器
            currentPlayer?.pause()
            // 确保完全停止
            parent.player?.rate = 0

            // 使用动画协调器确保平滑过渡
            coordinator.animate(alongsideTransition: nil) { [weak self] _ in
                guard let self = self else { return }
                // 更新父视图中的播放状态
                if let parentView = self.parent.player, let time = timeInFullScreen {
                    // 确保原始播放器状态正确
                    parentView.seek(to: time, completionHandler: { _ in
                        if wasPlayingInFullScreen {
                            currentPlayer?.play()
                        }
                    })
                }

                // 延迟设置isFullScreen标志，确保资源不会过早释放
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.parent.isFullScreen = false
                }
            }
        }
    }
}

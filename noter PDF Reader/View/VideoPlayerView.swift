import AVFoundation
import SwiftUI
import AVKit

struct VideoPlayerView: View {
    let videoURL: URL
    let startTime: Double
    let endTime: Double?

    @State private var player: AVPlayer?
    @State private var isPlaying: Bool = false
    @State private var timeObserverToken: Any?
    @State private var playerViewController: AVPlayerViewController?

    init(videoURL: URL, startTime: Double = 0, endTime: Double? = nil) {
        self.videoURL = videoURL
        self.startTime = startTime
        self.endTime = endTime
        NSLog("✅ VideoPlayerView.swift -> VideoPlayerView.init, \(videoURL), \(startTime), \(endTime)")
    }

    var body: some View {
        VStack {
            AVPlayerControllerRepresentable(player: player, playerViewControllerCallback: { controller in
                self.playerViewController = controller
            })
                .aspectRatio(16/9, contentMode: .fit)
                .onAppear {
                    // 创建播放器并设置起始时间
                    setupPlayer()
                }
                .onDisappear {
                    // 停止播放并释放资源
                    removePeriodicTimeObserver()
                    player?.pause()
                    player = nil
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
        player = AVPlayer(url: videoURL)

        // 设置起始时间
        let targetTime = CMTime(seconds: startTime, preferredTimescale: 1)
        player?.seek(to: targetTime)

        // 添加时间观察器来监控播放进度
        addPeriodicTimeObserver()

        // 开始播放
        player?.play()
        isPlaying = true

        // 监听播放结束通知
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: .main
        ) { [self] _ in
            // 视频播放结束时，重新从startTime开始播放
            let targetTime = CMTime(seconds: startTime, preferredTimescale: 1)
            player?.seek(to: targetTime)
            player?.play()
        }
    }

    private func addPeriodicTimeObserver() {
        // 如果没有设置endTime，则不需要监控
        guard let endTime = endTime, let player = player else { return }

        // 每0.5秒检查一次播放进度
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))

        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            let currentTime = time.seconds

            // 如果当前时间超过了endTime，则回到startTime
            if currentTime >= endTime {
                let targetTime = CMTime(seconds: startTime, preferredTimescale: 1)
                player.seek(to: targetTime)
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

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        var parent: AVPlayerControllerRepresentable
        var playerViewController: AVPlayerViewController?

        init(_ parent: AVPlayerControllerRepresentable) {
            self.parent = parent
        }

        // 处理全屏模式变化
        func playerViewController(_ playerViewController: AVPlayerViewController, willBeginFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator) {
            // 全屏模式开始时确保视频继续播放
            coordinator.animate(alongsideTransition: nil) { _ in
                playerViewController.player?.play()
            }
        }

        func playerViewController(_ playerViewController: AVPlayerViewController, willEndFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator) {
            // 退出全屏模式时确保视频继续播放
            coordinator.animate(alongsideTransition: nil) { _ in
                playerViewController.player?.play()
            }
        }
    }
}

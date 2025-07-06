import AVFoundation
import SwiftUI
import AVKit

struct VideoPlayerView: View {
    let videoURL: URL
    let startTime: Double

    @State private var player: AVPlayer?
    @State private var isPlaying: Bool = false

    init(videoURL: URL, startTime: Double = 0) {
        self.videoURL = videoURL
        self.startTime = startTime
    }

    var body: some View {
        VStack {
            AVPlayerControllerRepresentable(player: player)
                .aspectRatio(16/9, contentMode: .fit)
                .onAppear {
                    // 创建播放器并设置起始时间
                    player = AVPlayer(url: videoURL)
                    let targetTime = CMTime(seconds: startTime, preferredTimescale: 1)
                    player?.seek(to: targetTime)
                    player?.play()
                    isPlaying = true
                }
                .onDisappear {
                    // 停止播放并释放资源
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
                    let targetTime = CMTime(seconds: max(0, currentTime - 10), preferredTimescale: 1)
                    player?.seek(to: targetTime)
                }) {
                    Image(systemName: "gobackward.10")
                        .font(.system(size: 30))
                        .foregroundColor(.blue)
                }

                Button(action: {
                    let currentTime = player?.currentTime().seconds ?? 0
                    let targetTime = CMTime(seconds: currentTime + 10, preferredTimescale: 1)
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
}

// 视频播放器组件
struct AVPlayerControllerRepresentable: UIViewControllerRepresentable {
    let player: AVPlayer?

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }
}

import SwiftUI

// 扫描进度视图
struct ScanningProgressView: View {
    @ObservedObject var accessManager: DirectoryAccessManager

    var body: some View {
        VStack {
            if accessManager.isScanning {
                ProgressView("正在扫描目录...", value: accessManager.scanningProgress, total: 1.0)
                  .progressViewStyle(LinearProgressViewStyle())
                  .padding()

                Text(String(format: "进度: %.1f%%", accessManager.scanningProgress * 100))
                  .font(.caption)
                  .foregroundColor(.secondary)
            } else if let error = accessManager.errorMessage {
                Text("错误: \(error)")
                  .foregroundColor(.red)
                  .padding()
            } else if accessManager.rootDirectoryURL != nil {
                Text("目录扫描完成")
                  .foregroundColor(.primary)
                  .padding()
            }
        }
    }
}

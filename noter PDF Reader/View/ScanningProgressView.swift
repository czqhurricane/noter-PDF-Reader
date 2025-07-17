import SwiftUI

// 扫描进度视图
struct ScanningRootDirectoryProgressView: View {
    @ObservedObject var accessManager: DirectoryAccessManager

    var body: some View {
        VStack {
            if accessManager.isScanningRootDirectory {
                ProgressView("正在扫描文件夹...", value: accessManager.scanningRootDirectoryProgress, total: 1.0)
                  .progressViewStyle(LinearProgressViewStyle())
                  .padding()

                Text(String(format: "进度: %.1f%%", accessManager.scanningRootDirectoryProgress * 100))
                  .font(.caption)
                  .foregroundColor(.secondary)
            } else if let error = accessManager.errorMessageForRootDirectory {
                Text("错误: \(error)")
                  .foregroundColor(.red)
                  .padding()
            } else if accessManager.rootDirectoryURL != nil {
                Text("PDF 根文件夹扫描完成")
                  .font(.caption)
                  .foregroundColor(.secondary)
                  .padding()
            }
        }
    }
}

struct ScanningOrgRoamDirectoryProgressView: View {
    @ObservedObject var accessManager: DirectoryAccessManager

    var body: some View {
        VStack {
            if accessManager.isScanningOrgRoamDirectory {
                ProgressView("正在扫描文件夹...", value: accessManager.scanningOrgRoamDirectoryProgress, total: 1.0)
                  .progressViewStyle(LinearProgressViewStyle())
                  .padding()

                Text(String(format: "进度: %.1f%%", accessManager.scanningOrgRoamDirectoryProgress * 100))
                  .font(.caption)
                  .foregroundColor(.secondary)
            } else if let error = accessManager.errorMessageForOrgRoamDirectory {
                Text("错误: \(error)")
                  .foregroundColor(.red)
                  .padding()
            } else if accessManager.rootDirectoryURL != nil {
                Text("Org Roam 根文件夹扫描完成")
                  .font(.caption)
                  .foregroundColor(.secondary)
                  .padding()
            }
        }
    }
}

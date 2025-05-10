import MobileCoreServices
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var convertedPdfPath: String = ""
    @State private var pdfURL: URL? = nil
    @State private var currentPage: Int = 1
    @State private var xRatio: Double = 0.0
    @State private var yRatio: Double = 0.0
    @State private var showDocumentPicker = false
    @State private var showLinkInput = false
    @State private var linkText: String = ""
    @State private var rootFolderURL: URL? = UserDefaults.standard.url(forKey: "RootFolder")
    @State private var isPDFLoaded = false
    @State private var viewPoint: CGPoint = .zero

    var body: some View {
        NavigationView {
            VStack {
                if let url = pdfURL {
                    ZStack {
                        PDFKitView(url: url, page: currentPage, xRatio: xRatio, yRatio: yRatio,
                                   isPDFLoaded: $isPDFLoaded, viewPoint: $viewPoint)

                        // if isPDFLoaded {
                        //     ArrowAnnotationView(
                        //         viewPoint: viewPoint
                        //     )
                        // }
                    }
                } else {
                    VStack {
                        Text("请先设置 PDF 根文件夹")
                            .font(.title)
                            .padding()

                        Button(action: {
                            showDocumentPicker = true
                        }) {
                            Text("选择 PDF 根文件夹")
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }

                        Button(action: {
                            showLinkInput = true
                        }) {
                            Text("输入Metanote链接")
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                }
            }
            .navigationBarTitle("PDF阅读器", displayMode: .inline)
            .navigationBarTitleDisplayMode(.automatic) // Change to automatic
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showDocumentPicker = true }) {
                        Image(systemName: "doc")
                            .padding(8) // Add padding
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showLinkInput = true }) {
                        Image(systemName: "link")
                            .padding(8) // Add padding
                    }
                }
            }.sheet(isPresented: Binding<Bool>(
                get: { showLinkInput || showDocumentPicker },
                set: {
                    if !$0 {
                        showLinkInput = false
                        showDocumentPicker = false
                    }
                }
            )) {
                Group {
                    if showLinkInput {
                        LinkInputView(linkText: $linkText, onSubmit: {
                            processMetanoteLink(linkText)
                            showLinkInput = false
                        })
                    } else {
                        DocumentPicker()
                            .onAppear {
                                NSLog("✅ ContentView.swift -> ContentView.body, 文件选择器 sheet 显示")
                            }
                            .onDisappear {
                                showDocumentPicker = false
                                NSLog("❌ ContentView.swift -> ContentView.body, 文件选择器 sheet 不显示")
                            }
                    }
                }
            }
            .onAppear {
                setupNotifications()
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("OpenPDFNotification"),
            object: nil,
            queue: .main
        ) { notification in
            guard let userInfo = notification.userInfo,
                  let path = userInfo["path"] as? String,
                  let page = userInfo["page"] as? Int,
                  let xRatio = userInfo["xRatio"] as? Double,
                  let yRatio = userInfo["yRatio"] as? Double
            else {
                return
            }

            self.convertedPdfPath = PathConverter.convertNoterPagePath(path)
            self.pdfURL = URL(fileURLWithPath: self.convertedPdfPath)
            self.currentPage = page
            self.xRatio = xRatio
            self.yRatio = yRatio

            NSLog("✅ ContentView.swift -> ContentView.setupNotifications, OpenPDFNotification 通知参数 - 转换路径: \(self.convertedPdfPath), 页码: \(self.currentPage), Y: \(self.yRatio), X: \(self.xRatio)")
            NSLog("✅ ContentView.swift -> ContentView.setupNotifications, OpenPDFNotification 通知参数 - 文件路径: \(String(describing: self.pdfURL)), 页码: \(self.currentPage), Y: \(self.yRatio), X: \(self.xRatio)")
        }
    }

    private func processMetanoteLink(_ link: String){
        guard let result = PathConverter.parseNoterPageLink(link) else {
            NSLog("❌ ContentView.swift -> ContentView.processMetanoteLink, 无效的 Metanote 链接")
            return
        }

        self.convertedPdfPath = PathConverter.convertNoterPagePath(result.pdfPath)
        self.pdfURL = URL(fileURLWithPath: convertedPdfPath)
        self.currentPage = result.page!
        self.xRatio = result.x!
        self.yRatio = result.y!
    }
}

// 添加一个新的视图用于输入链接
struct LinkInputView: View {
    @Binding var linkText: String
    var onSubmit: () -> Void
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            VStack {
                TextField("请输入Metanote链接", text: $linkText)
                    .padding()
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                Button("确定") {
                    onSubmit()
                    presentationMode.wrappedValue.dismiss()
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding()
            .navigationBarTitle("输入链接", displayMode: .inline)
            .navigationBarItems(trailing: Button("取消") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let contentTypes = [UTType.folder]

        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes)

        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator

        return picker
    }

    func updateUIViewController(_: UIDocumentPickerViewController, context _: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentPicker

        init(_ parent: DocumentPicker) {
            self.parent = parent
        }

        func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }

            // Access security-scoped resource
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer { if didStartAccessing { url.stopAccessingSecurityScopedResource() } }

            // Save folder URL to UserDefaults
            UserDefaults.standard.set(url, forKey: "RootFolder")
            NSLog("✅ ContentView.swift -> DocumentPicker.Coordinator.documentPicker, 选择 PDF 根文件夹：\(url.path)")
        }
    }
}

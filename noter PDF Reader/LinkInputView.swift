import SwiftUI

struct LinkInputView: View {
    @Binding var linkText: String
    var onSubmit: () -> Void
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            VStack {
                TextEditor(text: $linkText)
                    .frame(height: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray, lineWidth: 1)
                    )
                    .padding()

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
        }.onAppear {
            setupURLNotificationObserver()
        }
    }

    private func setupURLNotificationObserver() {
        NotificationCenter.default.addObserver(
            forName: Notification.Name("ReceivedURLNotification"),
            object: nil,
            queue: .main
        ) { notification in
            if let url = notification.userInfo?["decodedString"] as? String {
                self.linkText = url
                
                NSLog("✅ LinkInputView.swift -> LinkInputView.setupURLNotificationObserver, Updated linkText to: \(url)")
            }
        }
    }
}

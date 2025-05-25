import SwiftUI

struct ChatView: View {
    var initialText: String = ""
    var autoSend: Bool = false

    @StateObject private var viewModel = ChatViewModel()
    @State private var inputText: String = ""

    init(initialText: String = "", autoSend: Bool = false) {
        self.initialText = initialText
        self.autoSend = autoSend
        _inputText = State(initialValue: initialText)
    }

    var body: some View {
        NavigationView {
            VStack {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(viewModel.messages) { message in
                            HStack {
                                if message.isUser {
                                    Spacer()
                                    ZStack(alignment: .topTrailing) {
                                        // 使用UITextView包装器来支持文本选择
                                        SelectableText(text: message.text, textColor: .white)
                                            .padding()
                                            .background(Color.orange)
                                            .foregroundColor(.white)
                                            .cornerRadius(10)
                                            .padding(.trailing, 24)
                                            .frame(maxWidth: .infinity, alignment: .trailing) // 添加这一行
                                            .fixedSize(horizontal: false, vertical: true) // 添加这一行

                                        Button(action: {
                                            UIPasteboard.general.string = message.text
                                            let generator = UIImpactFeedbackGenerator(style: .medium)
                                            generator.impactOccurred()
                                        }) {
                                            Image(systemName: "doc.on.doc")
                                                .font(.system(size: 12))
                                                .foregroundColor(.black)
                                                .padding(6)
                                        }
                                    }
                                } else {
                                    ZStack(alignment: .topLeading) {
                                        // 使用UITextView包装器来支持文本选择
                                        SelectableText(text: message.text, textColor: .black)
                                            .padding()
                                            .background(Color.gray.opacity(0.2))
                                            .foregroundColor(.black)
                                            .cornerRadius(10)
                                            .padding(.leading, 24)
                                            .frame(maxWidth: .infinity, alignment: .leading) // 添加这一行
                                            .fixedSize(horizontal: false, vertical: true) // 添加这一行

                                        Button(action: {
                                            UIPasteboard.general.string = message.text
                                            let generator = UIImpactFeedbackGenerator(style: .medium)
                                            generator.impactOccurred()
                                        }) {
                                            Image(systemName: "doc.on.doc")
                                                .font(.system(size: 12))
                                                .foregroundColor(.black)
                                                .padding(6)
                                        }
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)

                HStack {
                    TextField("Type a message...", text: $inputText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onAppear {
                            if autoSend && !initialText.isEmpty {
                                // 如果是翻译模式且有初始文本，自动发送翻译请求
                                sendTranslationRequest()
                            }
                        }
                        .padding()

                    Button(action: {
                        if !inputText.isEmpty {
                            viewModel.sendMessage(Message(text: inputText, isUser: true))
                            inputText = ""
                        }
                    }) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.orange)
                            .font(.title2)
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("JK Bot")
                        .font(.title)
                        .fontWeight(.bold)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    // 在清除聊天记录的按钮动作中
                    Button(action: {
                        viewModel.clearMessages() // 使用 ViewModel 中的方法清除并保存
                    }) {
                        Image(systemName: "trash")
                            .font(.title2)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
    }

    private func sendTranslationRequest() {
        if !inputText.isEmpty {
            // 构建翻译请求
            let translationPrompt = "请将以下文本翻译成中文（如果原文是中文则翻译成英文）：\n\n\"\(inputText)\""

            // 发送消息
            viewModel.sendMessage(Message(text: translationPrompt, isUser: true))
            inputText = ""
        }
    }
}

struct SelectableText: UIViewRepresentable {
    var text: String
    var textColor: UIColor = .black

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear

        // 关键设置：确保文本可以正确换行
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainerInset = .zero
        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.textContainer.maximumNumberOfLines = 0

        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        // 设置文本
        uiView.text = text

        // 设置文本颜色
        uiView.textColor = textColor

        // 计算可用宽度 - 使用更可靠的方法
        let screenWidth = UIScreen.main.bounds.width
        let availableWidth = screenWidth * 0.8 // 使用屏幕宽度的80% 作为基准

        // 设置明确的宽度约束
        let containerWidth = availableWidth // 增加更多边距

        // 重要：设置preferredMaxLayoutWidth以确保文本正确换行
        uiView.textContainer.size = CGSize(width: containerWidth, height: .greatestFiniteMagnitude)

        // 清除所有现有约束
        NSLayoutConstraint.deactivate(uiView.constraints)
        uiView.translatesAutoresizingMaskIntoConstraints = false

        // 添加宽度约束，强制文本在指定宽度内换行
        NSLayoutConstraint.activate([
            uiView.widthAnchor.constraint(equalToConstant: containerWidth)
        ])

        // 强制布局更新
        uiView.setNeedsLayout()
        uiView.layoutIfNeeded()

        // 计算并设置适当的高度
        let newSize = uiView.sizeThatFits(CGSize(width: containerWidth, height: CGFloat.greatestFiniteMagnitude))
        uiView.frame.size.height = newSize.height
    }
}

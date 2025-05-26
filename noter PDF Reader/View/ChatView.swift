import SwiftUI

struct ChatView: View {
    var initialText: String = ""
    var autoSend: Bool = false

    @StateObject private var viewModel = ChatViewModel()
    @State private var inputText: String = ""
    @State private var textEditorHeight: CGFloat = 40 // 初始高度

    init(initialText: String = "", autoSend: Bool = false) {
        self.initialText = initialText
        self.autoSend = autoSend
        _inputText = State(initialValue: initialText)

        // 预先计算初始文本高度
        if !initialText.isEmpty && !autoSend {
            let estimatedHeight = min(150, initialText.height(width: UIScreen.main.bounds.width * 0.8, font: .systemFont(ofSize: 16)))
            _textEditorHeight = State(initialValue: max(40, estimatedHeight))
        }
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

                // 替换TextField为支持多行的输入区域
                HStack(alignment: .bottom) {
                    ZStack(alignment: .topLeading) {
                        // 使用TextEditor替代TextField
                        TextEditor(text: $inputText)
                            .frame(height: max(40, textEditorHeight))
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .onChange(of: inputText) { newValue in
                                // 根据内容动态调整高度
                                let estimatedHeight = newValue.isEmpty ? 40 : min(150, newValue.height(width: UIScreen.main.bounds.width * 0.8, font: .systemFont(ofSize: 16)))
                                textEditorHeight = estimatedHeight
                            }
                            .onAppear {
                                // 在视图出现时也计算一次高度，确保初始文本正确显示
                                if !inputText.isEmpty {
                                    let estimatedHeight = min(150, inputText.height(width: UIScreen.main.bounds.width * 0.8, font: .systemFont(ofSize: 16)))
                                    textEditorHeight = max(40, estimatedHeight)
                                }

                                if autoSend && !initialText.isEmpty {
                                    // 如果是翻译模式且有初始文本，自动发送翻译请求
                                    sendTranslationRequest()
                                }
                            }

                        // 当TextEditor为空时显示占位符
                        if inputText.isEmpty {
                            Text("输入消息...")
                                .foregroundColor(Color(.placeholderText))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                                .allowsHitTesting(false)
                        }
                    }

                    Button(action: {
                        if !inputText.isEmpty {
                            viewModel.sendMessage(Message(text: inputText, isUser: true))
                            inputText = ""
                            // 重置高度
                            textEditorHeight = 40
                        }
                    }) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.orange)
                            .font(.title2)
                            .padding(.bottom, 8)
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

// 扩展String来计算文本高度
extension String {
    func height(width: CGFloat, font: UIFont) -> CGFloat {
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingBox = self.boundingRect(
            with: constraintRect,
            options: .usesLineFragmentOrigin,
            attributes: [.font: font],
            context: nil
        )
        return ceil(boundingBox.height) + 20 // 添加一些额外空间
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

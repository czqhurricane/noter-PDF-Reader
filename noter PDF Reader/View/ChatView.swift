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
                                    ZStack(alignment: .topLeading) {
                                        Text(message.text)
                                            .padding()
                                            .background(Color.orange)
                                            .foregroundColor(.white)
                                            .cornerRadius(10)
                                            .padding(.leading, 24)

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
                                        Text(message.text)
                                            .padding()
                                            .background(Color.gray.opacity(0.2))
                                            .foregroundColor(.black)
                                            .cornerRadius(10)
                                            .padding(.leading, 24)

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
                    Button(action: {
                        viewModel.messages = [] // purano chat haru hatauna lai
                    }) {
                        Image(systemName: "plus")
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

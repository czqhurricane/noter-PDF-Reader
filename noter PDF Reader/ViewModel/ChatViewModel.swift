import Combine
import Foundation

class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    private let networkManager = NetworkManager()
    private let userDefaultsKey = "savedChatMessages"

    init() {
        // 从本地存储加载消息历史
        loadMessages()
    }

    func sendMessage(_ message: Message) {
        // 添加用户消息到列表
        messages.append(message)

        // 保存消息
        saveMessages()

        // 获取 API Key
        let apiKey = UserDefaults.standard.string(forKey: "DeepSeekApiKey") ?? ""

        // 如果有 API Key，则发送请求
        if !apiKey.isEmpty {
            // 使用 apiKey 调用 DeepSeek API
            networkManager.sendToDeepSeek(message: message.text, apiKey: apiKey) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case let .success(response):
                        // 添加 AI 回复到消息列表
                        let aiMessage = Message(text: response, isUser: false)
                        self?.messages.append(aiMessage)
                        self?.saveMessages() // 保存消息历史
                    case let .failure(error):
                        // 添加错误消息
                        let errorMessage = Message(text: "错误: \(error.localizedDescription)", isUser: false)
                        self?.messages.append(errorMessage)
                        self?.saveMessages() // 保存消息历史
                    }
                }
            }
        } else {
            // 如果没有 API Key，添加提示消息
            let noKeyMessage = Message(text: "请在设置中配置 DeepSeek API Key", isUser: false)
            messages.append(noKeyMessage)
            saveMessages() // 保存消息历史
        }
    }

    func clearMessages() {
        messages.removeAll()
        saveMessages()
    }

    // 保存消息到 UserDefaults
    private func saveMessages() {
        do {
            let data = try JSONEncoder().encode(messages)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            NSLog("❌ ChatViewModel.swift -> ChatViewModel.saveMessages, 保存消息失败: \(error.localizedDescription)")
        }
    }

    // 从 UserDefaults 加载消息
    private func loadMessages() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return }

        do {
            messages = try JSONDecoder().decode([Message].self, from: data)
        } catch {
            NSLog("❌ ChatViewModel.swift -> ChatViewModel.loadMessages, 加载消息失败: \(error.localizedDescription)")
        }
    }
}

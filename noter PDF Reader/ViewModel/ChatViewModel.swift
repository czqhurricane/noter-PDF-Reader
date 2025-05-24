import Foundation

class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    private let networkManager = NetworkManager()
    private let userDefaultsKey = "savedChatMessages"

    init() {
        loadMessages()
    }

    func sendMessage(_ message: Message) {
        // 添加用户消息
        messages.append(message)

        // 保存消息
        saveMessages()

        // 发送到网络
        networkManager.sendMessage(message: message.text) { reply in
            DispatchQueue.main.async {
                let botMessage = Message(text: reply, isUser: false)
                self.messages.append(botMessage)
                self.saveMessages()
            }
        }
    }

    // 保存消息到 UserDefaults
    private func saveMessages() {
        do {
            let data = try JSONEncoder().encode(messages)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            print("保存消息失败: \(error.localizedDescription)")
        }
    }

    // 从 UserDefaults 加载消息
    private func loadMessages() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return }

        do {
            messages = try JSONDecoder().decode([Message].self, from: data)
        } catch {
            print("加载消息失败: \(error.localizedDescription)")
        }
    }

    // 清除所有消息
    func clearMessages() {
        messages = []
        saveMessages()
    }
}

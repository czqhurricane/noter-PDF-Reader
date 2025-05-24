import Combine
import Foundation

class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    private let networkManager = NetworkManager()

    func sendMessage(_ message: Message) {
        // 添加用户消息到列表
        messages.append(message)

        // 发送到API
        networkManager.sendMessage(message: message.text) { reply in
            DispatchQueue.main.async {
                let botMessage = Message(text: reply, isUser: false)
                self.messages.append(botMessage)
            }
        }
    }
}

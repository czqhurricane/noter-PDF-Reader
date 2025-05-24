import Foundation

struct Message: Identifiable, Codable {
    var id = UUID()
    var text: String
    var isUser: Bool
    var timestamp: Date = Date()

    // 如果需要，可以添加自定义编码和解码方法
    enum CodingKeys: String, CodingKey {
        case id, text, isUser, timestamp
    }
}

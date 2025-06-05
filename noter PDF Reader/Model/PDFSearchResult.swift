import Foundation
import PDFKit

struct PDFSearchResult: Identifiable {
    let id = UUID()
    let fileName: String
    let filePath: String
    let pageNumber: Int
    let context: String

    init(fileName: String, filePath: String, pageNumber: Int, context: String) {
        self.fileName = fileName
        self.filePath = filePath
        self.pageNumber = pageNumber
        self.context = context
    }
}

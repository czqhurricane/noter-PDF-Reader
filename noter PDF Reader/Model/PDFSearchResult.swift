import Foundation
import PDFKit

struct PDFSearchResult: Identifiable {
    let id = UUID()
    let page: Int
    let pageLabel: String
    let text: String
    let selection: PDFSelection

    init(selection: PDFSelection) {
        self.selection = selection
        self.page = selection.pages.first?.pageRef?.pageNumber ?? 0
        // Fix: Get the page label directly without referencing self
        let pageNumber = selection.pages.first?.pageRef?.pageNumber ?? 0
        self.pageLabel = selection.pages.first?.label ?? "\(pageNumber + 1)"
        self.text = selection.string ?? ""
    }
}

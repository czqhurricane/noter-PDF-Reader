import SwiftUI

struct ArrowAnnotationView: View {
    let viewPoint: CGPoint

    var body: some View {
        GeometryReader { _ in
            Path { path in
                // 箭头大小
                let arrowSize: CGFloat = 20

                // 绘制箭头
                path.move(to: CGPoint(x: viewPoint.x - arrowSize, y: viewPoint.y))
                path.addLine(to: CGPoint(x: viewPoint.x + arrowSize / 2, y: viewPoint.y))
                path.addLine(to: CGPoint(x: viewPoint.x, y: viewPoint.y + arrowSize))
                path.addLine(to: CGPoint(x: viewPoint.x + arrowSize / 2, y: viewPoint.y))
                path.addLine(to: CGPoint(x: viewPoint.x, y: viewPoint.y - arrowSize))
            }.stroke(Color.red, style: StrokeStyle(
                lineWidth: 3,
                lineCap: .round,
                lineJoin: .round
            ))
        }
    }
}

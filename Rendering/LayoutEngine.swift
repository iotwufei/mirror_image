import CoreGraphics

final class LayoutEngine {
    private let layout: ComparisonViewLayout

    init(layout: ComparisonViewLayout = .default) {
        self.layout = layout
    }

    func frames(for count: Int, in bounds: CGRect) -> [CGRect] {
        return layout.frames(for: count, in: bounds)
    }
}

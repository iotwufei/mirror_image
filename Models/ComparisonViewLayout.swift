import CoreGraphics

struct ComparisonViewLayout {
    let spacing: CGFloat
    let margin: CGFloat
    let maxItemsPerGroup: Int

    static let `default` = ComparisonViewLayout(
        spacing: 2,
        margin: 16,
        maxItemsPerGroup: 20
    )

    func frames(for count: Int, in bounds: CGRect) -> [CGRect] {
        let actualCount = min(count, maxItemsPerGroup)
        let insetBounds = bounds.insetBy(dx: margin, dy: margin)

        switch actualCount {
        case 0:
            return []
        case 1:
            return [insetBounds]
        case 2:
            return layoutRow(cols: 2, in: insetBounds)
        case 3:
            return layoutRow(cols: 3, in: insetBounds)
        case 4:
            return layoutGrid(rows: 2, cols: 2, count: actualCount, in: insetBounds)
        case 5:
            return layoutRow(cols: 5, in: insetBounds)
        case 6:
            return layoutGrid(rows: 2, cols: 3, count: actualCount, in: insetBounds)
        default:
            return layoutFitted(count: actualCount, in: insetBounds)
        }
    }

    private func layoutRow(cols: Int, in bounds: CGRect) -> [CGRect] {
        let totalSpacing = spacing * CGFloat(cols - 1)
        let itemWidth = (bounds.width - totalSpacing) / CGFloat(cols)

        return (0..<cols).map { col in
            CGRect(
                x: bounds.minX + (itemWidth + spacing) * CGFloat(col),
                y: bounds.minY,
                width: itemWidth,
                height: bounds.height
            )
        }
    }

    private func layoutGrid(rows: Int, cols: Int, count: Int, in bounds: CGRect) -> [CGRect] {
        let totalHSpacing = spacing * CGFloat(cols - 1)
        let totalVSpacing = spacing * CGFloat(rows - 1)
        let itemWidth = (bounds.width - totalHSpacing) / CGFloat(cols)
        let itemHeight = (bounds.height - totalVSpacing) / CGFloat(rows)

        var frames: [CGRect] = []
        for row in 0..<rows {
            for col in 0..<cols {
                let frame = CGRect(
                    x: bounds.minX + (itemWidth + spacing) * CGFloat(col),
                    y: bounds.minY + (itemHeight + spacing) * CGFloat(row),
                    width: itemWidth,
                    height: itemHeight
                )
                frames.append(frame)
            }
        }
        return Array(frames.prefix(count))
    }

    private func layoutFitted(count: Int, in bounds: CGRect) -> [CGRect] {
        let screenAspect = bounds.width / bounds.height
        var cols = Int(round(sqrt(Double(count) * Double(screenAspect))))
        cols = max(1, min(count, cols))
        let rows = Int(ceil(Double(count) / Double(cols)))
        return layoutGrid(rows: rows, cols: cols, count: count, in: bounds)
    }
}

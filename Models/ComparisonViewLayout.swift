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
            return layoutColumn(rows: 3, in: insetBounds)
        case 4:
            return layoutGrid(rows: 2, cols: 2, count: actualCount, in: insetBounds)
        default:
            return layoutColumn(rows: actualCount, in: insetBounds)
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

    private func layoutColumn(rows: Int, in bounds: CGRect) -> [CGRect] {
        let totalSpacing = spacing * CGFloat(rows - 1)
        let itemHeight = (bounds.height - totalSpacing) / CGFloat(rows)

        return (0..<rows).map { row in
            CGRect(
                x: bounds.minX,
                y: bounds.minY + (itemHeight + spacing) * CGFloat(row),
                width: bounds.width,
                height: itemHeight
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

}

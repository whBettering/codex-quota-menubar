import CoreGraphics

public enum FloatingWindowPlacement {
    public static func defaultOrigin(
        size: CGSize,
        visibleFrame: CGRect,
        edgeInset: CGFloat = 5
    ) -> CGPoint {
        origin(
            forTopCenter: CGPoint(x: visibleFrame.midX, y: visibleFrame.maxY - edgeInset),
            targetSize: size
        )
    }

    public static func topCenter(of frame: CGRect) -> CGPoint {
        CGPoint(x: frame.midX, y: frame.maxY)
    }

    public static func origin(
        forTopCenter topCenter: CGPoint,
        targetSize: CGSize
    ) -> CGPoint {
        CGPoint(
            x: topCenter.x - (targetSize.width / 2),
            y: topCenter.y - targetSize.height
        )
    }

    public static func originPreservingTopCenter(
        currentFrame: CGRect,
        targetSize: CGSize
    ) -> CGPoint {
        origin(forTopCenter: topCenter(of: currentFrame), targetSize: targetSize)
    }

    public static func constrainedOrigin(
        _ origin: CGPoint,
        size: CGSize,
        visibleFrames: [CGRect]
    ) -> CGPoint {
        guard let closest = visibleFrames
            .map({ visibleFrame in
                let constrained = constrain(origin, size: size, visibleFrame: visibleFrame)
                let distance = squaredDistance(from: origin, to: constrained)
                return (origin: constrained, distance: distance)
            })
            .min(by: { $0.distance < $1.distance })
        else {
            return origin
        }

        return closest.origin
    }

    private static func constrain(
        _ origin: CGPoint,
        size: CGSize,
        visibleFrame: CGRect
    ) -> CGPoint {
        let maxX = max(visibleFrame.minX, visibleFrame.maxX - size.width)
        let maxY = max(visibleFrame.minY, visibleFrame.maxY - size.height)

        return CGPoint(
            x: min(max(origin.x, visibleFrame.minX), maxX),
            y: min(max(origin.y, visibleFrame.minY), maxY)
        )
    }

    private static func squaredDistance(from lhs: CGPoint, to rhs: CGPoint) -> CGFloat {
        let dx = lhs.x - rhs.x
        let dy = lhs.y - rhs.y
        return (dx * dx) + (dy * dy)
    }
}

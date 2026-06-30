import CoreGraphics
import CodexQuotaCore

func testDefaultFloatingWindowOriginUsesTopCenterOfVisibleFrame() throws {
    let visibleFrame = CGRect(x: 0, y: 25, width: 1440, height: 875)
    let size = CGSize(width: 206, height: 34)

    let origin = FloatingWindowPlacement.defaultOrigin(size: size, visibleFrame: visibleFrame)

    try expectEqual(origin, CGPoint(x: 617, y: 861), "default floating origin")
}

func testResizingPreservesDraggedTopCenter() throws {
    let currentFrame = CGRect(x: 120, y: 640, width: 206, height: 34)
    let expandedSize = CGSize(width: 360, height: 172)

    let origin = FloatingWindowPlacement.originPreservingTopCenter(
        currentFrame: currentFrame,
        targetSize: expandedSize
    )

    try expectEqual(origin, CGPoint(x: 43, y: 502), "expanded dragged origin")
}

func testConstrainedOriginMovesSavedPositionBackIntoVisibleFrame() throws {
    let visibleFrame = CGRect(x: 0, y: 25, width: 1440, height: 875)
    let size = CGSize(width: 206, height: 34)

    let origin = FloatingWindowPlacement.constrainedOrigin(
        CGPoint(x: 1500, y: 920),
        size: size,
        visibleFrames: [visibleFrame]
    )

    try expectEqual(origin, CGPoint(x: 1234, y: 866), "constrained saved origin")
}

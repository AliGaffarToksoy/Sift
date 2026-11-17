import CoreGraphics
import Foundation

/// Screen coordinates remain global: displays can have negative origins and different menu-bar heights.
public enum NotchLayout {
    public static func frame(screen: CGRect, visible: CGRect, topInset: CGFloat,
                             camera: CGRect?, expanded: Bool, additionalMessages: Int,
                             preview: Bool) -> CGRect {
        let inset = max(0, topInset)
        let hardware = inset > 0
        let cameraWidth = hardware ? max(0, camera?.width ?? 180) : 0
        let availableWidth = max(1, screen.width - 32)
        let width = min(max(expanded ? 560 : 460, cameraWidth + 100), availableWidth)
        let rows = min(3, max(0, additionalMessages))
        let contentHeight: CGFloat = expanded ? 218 + CGFloat(rows) * 28 + (preview ? 24 : 0) : 142
        let height = min(inset + contentHeight, max(1, visible.height - 16))
        let center = hardware ? (camera?.midX ?? screen.midX) : screen.midX
        let x = min(max(center - width / 2, screen.minX + 16), screen.maxX - width - 16)
        let top = hardware ? screen.maxY : visible.maxY - 8
        return CGRect(x: x, y: top - height, width: width, height: height)
    }
}

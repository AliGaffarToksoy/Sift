import AppKit

// Original vector artwork. Generate every macOS icon resolution from one drawing.
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
func render(_ size: Int, name: String) throws {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let context = NSGraphicsContext.current!.cgContext
    context.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    let tile = NSBezierPath(roundedRect: NSRect(x: 74, y: 74, width: 876, height: 876), xRadius: 196, yRadius: 196)
    NSGradient(starting: NSColor(calibratedWhite: 0.20, alpha: 1), ending: NSColor(calibratedWhite: 0.055, alpha: 1))!.draw(in: tile, angle: -90)
    NSColor.white.withAlphaComponent(0.16).setStroke(); tile.lineWidth = 3; tile.stroke()
    let envelope = NSBezierPath(roundedRect: NSRect(x: 226, y: 310, width: 572, height: 380), xRadius: 70, yRadius: 70)
    NSGradient(starting: NSColor(calibratedRed: 1, green: 0.72, blue: 0.30, alpha: 1), ending: NSColor(calibratedRed: 1, green: 0.36, blue: 0.12, alpha: 1))!.draw(in: envelope, angle: -90)
    let flap = NSBezierPath(); flap.move(to: NSPoint(x: 250, y: 650)); flap.line(to: NSPoint(x: 484, y: 478))
    flap.curve(to: NSPoint(x: 540, y: 478), controlPoint1: NSPoint(x: 501, y: 465), controlPoint2: NSPoint(x: 523, y: 465))
    flap.line(to: NSPoint(x: 774, y: 650)); flap.lineWidth = 27; flap.lineCapStyle = .round; flap.lineJoinStyle = .round
    NSColor(calibratedRed: 0.29, green: 0.12, blue: 0.04, alpha: 0.9).setStroke(); flap.stroke()
    let notch = NSBezierPath(roundedRect: NSRect(x: 394, y: 829, width: 236, height: 121), xRadius: 36, yRadius: 36)
    NSColor.black.setFill(); notch.fill()
    NSColor(calibratedRed: 1, green: 0.64, blue: 0.25, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: 712, y: 697, width: 56, height: 56)).fill()
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name))
}
for base in [16, 32, 128, 256, 512] {
    try render(base, name: "icon_\(base)x\(base).png")
    try render(base * 2, name: "icon_\(base)x\(base)@2x.png")
}

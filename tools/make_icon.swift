import AppKit
import CoreGraphics

// Generates the Oops app icon: the `circle.dashed` glyph in black on a white
// tile, styled after the Apple Health icon (centered glyph + soft depth shadow).
// iOS gets a full-bleed 1024 square (the system masks the corners). macOS gets a
// rounded "squircle" with transparent margins, downscaled to every required size.

let rootURL = URL(fileURLWithPath: CommandLine.arguments[1])

// MARK: - Glyph

/// A high-resolution black `circle.dashed` glyph on a transparent background.
func glyphMaster(pointSize: CGFloat) -> CGImage {
    let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)
    let symbol = NSImage(systemSymbolName: "circle.dashed", accessibilityDescription: nil)!
        .withSymbolConfiguration(config)!
    symbol.isTemplate = true
    let size = symbol.size
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(ceil(size.width)), pixelsHigh: Int(ceil(size.height)),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSColor.black.set()
    symbol.draw(in: NSRect(origin: .zero, size: size))
    NSGraphicsContext.restoreGraphicsState()
    return rep.cgImage!
}

let glyph = glyphMaster(pointSize: 1000)

// MARK: - Tile composition

func context(_ side: Int) -> CGContext {
    CGContext(
        data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}

/// Draws the glyph into an explicit rect with a soft downward depth shadow.
func drawGlyph(in ctx: CGContext, rect: CGRect, canvas: CGFloat) {
    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -canvas * 0.012),
        blur: canvas * 0.022,
        color: NSColor.black.withAlphaComponent(0.22).cgColor)
    ctx.draw(glyph, in: rect)
    ctx.restoreGState()
}

/// A smaller glyph anchored to the bottom-left of `area`, inset by `pad` on the
/// left and bottom so it clears the squircle's corner curve.
func bottomLeftRect(in area: CGRect, diameter: CGFloat, pad: CGFloat) -> CGRect {
    CGRect(x: area.minX + pad, y: area.minY + pad, width: diameter, height: diameter)
}

func writePNG(_ image: CGImage, to url: URL) {
    let rep = NSBitmapImageRep(cgImage: image)
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
}

// One renderer for both platforms: a full-bleed, fully opaque white square with
// the glyph anchored bottom-left. No rounded corners or transparency are baked
// in — iOS and macOS 26 mask the icon to the system squircle themselves, exactly
// like Apple's own icon masters (which are also flat, full-bleed, opaque PNGs).
func renderTile(side: Int) -> CGImage {
    let ctx = context(side)
    let s = CGFloat(side)
    let full = CGRect(x: 0, y: 0, width: s, height: s)
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.fill(full)
    let rect = bottomLeftRect(in: full, diameter: s * 0.38, pad: s * 0.14)
    drawGlyph(in: ctx, rect: rect, canvas: s)
    return ctx.makeImage()!
}

// MARK: - Output

let iosURL = rootURL.appendingPathComponent("iOS/Assets.xcassets/AppIcon.appiconset/icon-1024.png")
writePNG(renderTile(side: 1024), to: iosURL)
print("wrote \(iosURL.lastPathComponent)")

let macSet = rootURL.appendingPathComponent("macOS/Assets.xcassets/AppIcon.appiconset")
try! FileManager.default.createDirectory(at: macSet, withIntermediateDirectories: true)

// (size, scale, filename) entries for the macOS icon set.
let macSizes: [(Int, Int)] = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)]
var images: [String] = []
for (pt, scale) in macSizes {
    let px = pt * scale
    let name = "icon-\(pt)x\(pt)@\(scale)x.png"
    writePNG(renderTile(side: px), to: macSet.appendingPathComponent(name))
    images.append("""
        {
          "filename" : "\(name)",
          "idiom" : "mac",
          "scale" : "\(scale)x",
          "size" : "\(pt)x\(pt)"
        }
    """)
}
let contents = """
{
  "images" : [
\(images.joined(separator: ",\n"))
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""
try! contents.write(to: macSet.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
print("wrote macOS icon set (\(macSizes.count) images)")

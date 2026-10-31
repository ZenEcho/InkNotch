// InkNotch's original vector artwork. Regenerate with tools/regenerate-icon.sh.
import AppKit
import ImageIO
import UniformTypeIdentifiers

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: r, green: g, blue: b, alpha: a)
}

func rounded(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func gradient(_ context: CGContext, colors: [CGColor], start: CGPoint, end: CGPoint) {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let fill = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: nil)!
    context.drawLinearGradient(fill, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

func icon(size: Int) -> CGImage {
    let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                            bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    context.setAllowsAntialiasing(true)
    let tile = rounded(CGRect(x: 96, y: 96, width: 832, height: 832), 190)

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0, 0, 0, 0.22))
    context.addPath(tile)
    context.setFillColor(color(0.04, 0.05, 0.07))
    context.fillPath()
    context.restoreGState()
    context.saveGState()
    context.addPath(tile)
    context.clip()
    gradient(context, colors: [color(0.18, 0.20, 0.25), color(0.035, 0.045, 0.065)],
             start: CGPoint(x: 200, y: 930), end: CGPoint(x: 820, y: 96))
    context.restoreGState()
    context.addPath(tile)
    context.setStrokeColor(color(1, 1, 1, 0.16))
    context.setLineWidth(2)
    context.strokePath()

    // A black island, a quiet white dash, and one luminous blue point.
    let island = rounded(CGRect(x: 190, y: 376, width: 644, height: 272), 136)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -18), blur: 38, color: color(0, 0, 0, 0.65))
    context.setFillColor(color(0.006, 0.008, 0.012))
    context.addPath(island)
    context.fillPath()
    context.restoreGState()
    context.addPath(island)
    context.setStrokeColor(color(1, 1, 1, 0.17))
    context.setLineWidth(2)
    context.strokePath()
    context.addPath(rounded(CGRect(x: 270, y: 490, width: 232, height: 44), 22))
    context.setFillColor(color(0.91, 0.94, 0.98))
    context.fillPath()

    context.saveGState()
    context.setShadow(offset: .zero, blur: 48, color: color(0.04, 0.51, 1, 0.9))
    context.setFillColor(color(0.08, 0.58, 1))
    context.fillEllipse(in: CGRect(x: 644, y: 458, width: 108, height: 108))
    context.restoreGState()
    context.saveGState()
    context.addEllipse(in: CGRect(x: 644, y: 458, width: 108, height: 108))
    context.clip()
    gradient(context, colors: [color(0.45, 0.87, 1), color(0.04, 0.38, 1)],
             start: CGPoint(x: 674, y: 564), end: CGPoint(x: 726, y: 458))
    context.restoreGState()
    return context.makeImage()!
}

func png(_ image: CGImage, at url: URL) {
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    precondition(CGImageDestinationFinalize(destination))
}

let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let assets = root.appendingPathComponent("boringNotch/Assets.xcassets", isDirectory: true)
let iconSet = assets.appendingPathComponent("AppIcon.appiconset", isDirectory: true)
let fileManager = FileManager.default
for file in try fileManager.contentsOfDirectory(at: iconSet, includingPropertiesForKeys: nil) where file.pathExtension == "png" {
    try fileManager.removeItem(at: file)
}
var entries: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        let filename = "InkNotch-\(pixels).png"
        png(icon(size: pixels), at: iconSet.appendingPathComponent(filename))
        entries.append(["filename": filename, "idiom": "mac", "scale": "\(scale)x", "size": "\(points)x\(points)"])
    }
}
let metadata: [String: Any] = ["images": entries, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
    .write(to: iconSet.appendingPathComponent("Contents.json"))

for name in ["logo", "logo2"] {
    let directory = assets.appendingPathComponent("\(name).imageset", isDirectory: true)
    for file in try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) where file.pathExtension == "png" {
        try fileManager.removeItem(at: file)
    }
    png(icon(size: 1024), at: directory.appendingPathComponent("InkNotch.png"))
    let contents: [String: Any] = ["images": [["filename": "InkNotch.png", "idiom": "universal"]],
                                   "info": ["author": "xcode", "version": 1]]
    try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
        .write(to: directory.appendingPathComponent("Contents.json"))
}
let branding = root.appendingPathComponent("branding", isDirectory: true)
try fileManager.createDirectory(at: branding, withIntermediateDirectories: true)
png(icon(size: 1024), at: branding.appendingPathComponent("InkNotch.png"))
png(icon(size: 256), at: branding.appendingPathComponent("InkNotch-preview.png"))
print("InkNotch icon: all macOS sizes, welcome artwork, and previews generated.")

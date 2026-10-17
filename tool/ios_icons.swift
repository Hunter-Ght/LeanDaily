// Run from the repository root: swift tool/ios_icons.swift
// Reuse the Android launcher artwork, flatten its transparent corners for iOS.
import AppKit
import Foundation
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let source = root.appendingPathComponent("android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png")
guard let image = NSImage(contentsOf: source) else { fatalError("Missing Android launcher icon") }
let destination = root.appendingPathComponent("ios/Runner/Assets.xcassets/AppIcon.appiconset")
let contents = try JSONSerialization.jsonObject(with: Data(contentsOf: destination.appendingPathComponent("Contents.json"))) as! [String: Any]
for item in contents["images"] as! [[String: String]] {
    guard let file = item["filename"], let raw = item["size"]?.components(separatedBy: "x").first,
          let size = Double(raw), let scale = Double((item["scale"] ?? "1x").replacingOccurrences(of: "x", with: "")) else { continue }
    let pixels = Int((size * scale).rounded())
    let cg = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
                       bytesPerRow: pixels * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                       bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    let context = NSGraphicsContext(cgContext: cg, flipped: false)
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
    context.imageInterpolation = .high
    NSColor(srgbRed: 27/255, green: 30/255, blue: 39/255, alpha: 1).setFill()
    let rect = NSRect(x: 0, y: 0, width: pixels, height: pixels)
    rect.fill(); image.draw(in: rect)
    NSGraphicsContext.restoreGraphicsState()
    let bitmap = NSBitmapImageRep(cgImage: cg.makeImage()!)
    try bitmap.representation(using: .png, properties: [:])!.write(to: destination.appendingPathComponent(file))
}

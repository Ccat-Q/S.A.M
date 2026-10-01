// Original vector system mark, rasterized by macOS only in GitHub Actions.
import AppKit
import Foundation

let folder = URL(fileURLWithPath: "client/ios/Runner/Assets.xcassets/AppIcon.appiconset")
let json = try JSONSerialization.jsonObject(with: Data(contentsOf: folder.appendingPathComponent("Contents.json"))) as! [String: Any]
for item in json["images"] as! [[String: Any]] {
    guard let filename = item["filename"] as? String, let size = item["size"] as? String else { continue }
    let points = Double(size.split(separator: "x")[0])!
    let scale = Double((item["scale"] as? String ?? "1x").replacingOccurrences(of: "x", with: ""))!
    let pixels = Int(points * scale)
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let context = NSGraphicsContext.current!.cgContext
    context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    context.setFillColor(CGColor(red: 5/255, green: 7/255, blue: 8/255, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
    context.setStrokeColor(CGColor(red: 143/255, green: 201/255, blue: 188/255, alpha: 1))
    context.setLineWidth(9)
    context.stroke(CGRect(x: 96, y: 96, width: 832, height: 832))
    for x in [CGFloat(270), CGFloat(754)] {
        for y in [CGFloat(330), CGFloat(570)] {
            context.move(to: CGPoint(x: 512, y: 450))
            context.addLine(to: CGPoint(x: x, y: 450))
            context.addLine(to: CGPoint(x: x, y: y))
            context.strokePath()
            context.stroke(CGRect(x: x-28, y: y-28, width: 56, height: 56))
        }
    }
    context.setFillColor(CGColor(red: 143/255, green: 201/255, blue: 188/255, alpha: 1))
    context.fill(CGRect(x: 482, y: 420, width: 60, height: 60))
    let style = NSMutableParagraphStyle()
    style.alignment = .center
    ("S.A.M." as NSString).draw(in: CGRect(x: 120, y: 690, width: 784, height: 155),
        withAttributes: [.font: NSFont.monospacedSystemFont(ofSize: 128, weight: .semibold),
                         .foregroundColor: NSColor(red: 216/255, green: 226/255, blue: 223/255, alpha: 1),
                         .paragraphStyle: style])
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent(filename))
}

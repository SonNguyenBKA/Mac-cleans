// Sinh icon 1024px: swift scripts/make-icon.swift <out.png>
import AppKit

let size = 1024.0
let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
    let inset = rect.insetBy(dx: 100, dy: 100)
    let path = NSBezierPath(roundedRect: inset, xRadius: 185, yRadius: 185)
    NSGradient(colors: [NSColor(red: 0.10, green: 0.75, blue: 0.55, alpha: 1),
                        NSColor(red: 0.05, green: 0.45, blue: 0.75, alpha: 1)])!.draw(in: path, angle: -90)
    let config = NSImage.SymbolConfiguration(pointSize: 420, weight: .semibold)
        .applying(.init(paletteColors: [.white]))
    let symbol = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)!.withSymbolConfiguration(config)!
    let s = symbol.size
    symbol.draw(in: NSRect(x: rect.midX - s.width / 2, y: rect.midY - s.height / 2, width: s.width, height: s.height))
    return true
}
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))

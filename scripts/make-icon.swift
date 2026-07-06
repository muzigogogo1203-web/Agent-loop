// AgentLoop 应用图标生成器（营地感设计语言：羊皮纸底 + 篝火橙帐篷 + 火苗）
// 用法：swift scripts/make-icon.swift <输出目录>
// 产出 icon_1024.png，由 package-app.sh 降采样成 iconset → icns。
import AppKit
import CoreGraphics

let size: CGFloat = 1024
let args = CommandLine.arguments
let outDir = args.count > 1 ? args[1] : "."

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
guard let ctx = NSGraphicsContext.current?.cgContext else {
    fatalError("no graphics context")
}

func color(_ hex: Int, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha)
}

// 背景：羊皮纸圆角方（macOS 图标网格：约 100pt 外边距、232pt 圆角 @1024）
let inset: CGFloat = 100
let bgRect = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
let bgPath = CGPath(roundedRect: bgRect, cornerWidth: 232, cornerHeight: 232, transform: nil)
ctx.addPath(bgPath)
ctx.setFillColor(color(0xF7F1E6))
ctx.fillPath()

// 底部苔绿地平线
ctx.saveGState()
ctx.addPath(bgPath)
ctx.clip()
ctx.setFillColor(color(0x6F8F4F, 0.35))
ctx.fill(CGRect(x: inset, y: inset, width: size - inset * 2, height: 150))
ctx.restoreGState()

// 帐篷：篝火橙渐变三角
let tentTop = CGPoint(x: size / 2, y: 700)
let tentLeft = CGPoint(x: 290, y: 250)
let tentRight = CGPoint(x: size - 290, y: 250)
let tent = CGMutablePath()
tent.move(to: tentTop)
tent.addLine(to: tentLeft)
tent.addLine(to: tentRight)
tent.closeSubpath()
ctx.saveGState()
ctx.addPath(tent)
ctx.clip()
let tentGradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [color(0xE8894C), color(0xC4602A)] as CFArray,
    locations: [0, 1])!
ctx.drawLinearGradient(
    tentGradient,
    start: CGPoint(x: size / 2, y: 700),
    end: CGPoint(x: size / 2, y: 250),
    options: [])
ctx.restoreGState()

// 帐篷门帘（深色内三角）
let door = CGMutablePath()
door.move(to: CGPoint(x: size / 2, y: 520))
door.addLine(to: CGPoint(x: size / 2 - 95, y: 250))
door.addLine(to: CGPoint(x: size / 2 + 95, y: 250))
door.closeSubpath()
ctx.addPath(door)
ctx.setFillColor(color(0x3B3128, 0.85))
ctx.fillPath()

// 门帘里的火苗（琥珀两层）
func flame(center: CGPoint, width: CGFloat, height: CGFloat, fill: CGColor) {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: center.x, y: center.y + height / 2))
    path.addQuadCurve(
        to: CGPoint(x: center.x, y: center.y - height / 2),
        control: CGPoint(x: center.x + width, y: center.y - height * 0.1))
    path.addQuadCurve(
        to: CGPoint(x: center.x, y: center.y + height / 2),
        control: CGPoint(x: center.x - width, y: center.y - height * 0.1))
    ctx.addPath(path)
    ctx.setFillColor(fill)
    ctx.fillPath()
}
flame(center: CGPoint(x: size / 2, y: 350), width: 72, height: 170, fill: color(0xDD9F35))
flame(center: CGPoint(x: size / 2, y: 335), width: 42, height: 110, fill: color(0xF0E6D4))

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("png encode failed")
}
let outURL = URL(fileURLWithPath: outDir).appendingPathComponent("icon_1024.png")
try! png.write(to: outURL)
print("wrote \(outURL.path)")

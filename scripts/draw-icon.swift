// SPDX-License-Identifier: MIT
// Original geometric artwork for LivePDF. No fonts, system symbols, or images.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 255) / 255,
            green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: alpha)
}

enum IconError: Error { case context, image, destination }

func drawIcon(to url: URL) throws {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let context = CGContext(data: nil, width: 1024, height: 1024,
                                  bitsPerComponent: 8, bytesPerRow: 4096,
                                  space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        throw IconError.context
    }
    context.clear(CGRect(x: 0, y: 0, width: 1024, height: 1024))
    context.setAllowsAntialiasing(true)

    func gradient(_ path: CGPath, top: UInt32, bottom: UInt32) {
        context.saveGState()
        context.addPath(path)
        context.clip()
        let bounds = path.boundingBoxOfPath
        let gradient = CGGradient(colorsSpace: space,
                                  colors: [color(top), color(bottom)] as CFArray,
                                  locations: [0, 1])!
        context.drawLinearGradient(gradient,
                                   start: CGPoint(x: bounds.midX, y: bounds.maxY),
                                   end: CGPoint(x: bounds.midX, y: bounds.minY), options: [])
        context.restoreGState()
    }

    // Standard macOS canvas inset, with transparency outside the rounded tile.
    let tile = CGPath(roundedRect: CGRect(x: 78, y: 78, width: 868, height: 868),
                      cornerWidth: 190, cornerHeight: 190, transform: nil)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -15), blur: 32,
                      color: color(0x102958, alpha: 0.3))
    context.setFillColor(color(0x1764D3))
    context.addPath(tile)
    context.fillPath()
    context.restoreGState()
    gradient(tile, top: 0x2D8BF1, bottom: 0x1645B0)
    context.setStrokeColor(color(0xFFFFFF, alpha: 0.24))
    context.setLineWidth(2)
    context.addPath(CGPath(roundedRect: CGRect(x: 80, y: 80, width: 864, height: 864),
                           cornerWidth: 188, cornerHeight: 188, transform: nil))
    context.strokePath()

    let sheet = CGMutablePath()
    sheet.move(to: CGPoint(x: 304, y: 225))
    sheet.addLine(to: CGPoint(x: 710, y: 225))
    sheet.addQuadCurve(to: CGPoint(x: 744, y: 259), control: CGPoint(x: 744, y: 225))
    sheet.addLine(to: CGPoint(x: 744, y: 724))
    sheet.addLine(to: CGPoint(x: 638, y: 830))
    sheet.addLine(to: CGPoint(x: 304, y: 830))
    sheet.addQuadCurve(to: CGPoint(x: 270, y: 796), control: CGPoint(x: 270, y: 830))
    sheet.addLine(to: CGPoint(x: 270, y: 259))
    sheet.addQuadCurve(to: CGPoint(x: 304, y: 225), control: CGPoint(x: 270, y: 225))
    sheet.closeSubpath()
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -14), blur: 24,
                      color: color(0x071E59, alpha: 0.28))
    context.setFillColor(color(0xE6F4FF))
    context.addPath(sheet)
    context.fillPath()
    context.restoreGState()
    gradient(sheet, top: 0xFFFFFF, bottom: 0xE7F2FE)

    let fold = CGMutablePath()
    fold.move(to: CGPoint(x: 638, y: 830))
    fold.addLine(to: CGPoint(x: 638, y: 756))
    fold.addQuadCurve(to: CGPoint(x: 670, y: 724), control: CGPoint(x: 638, y: 724))
    fold.addLine(to: CGPoint(x: 744, y: 724))
    fold.closeSubpath()
    gradient(fold, top: 0xD8EAFF, bottom: 0xA6C9F3)

    context.setLineCap(.round)
    context.setLineWidth(25)
    context.setStrokeColor(color(0x7FA6D4))
    for (y, width) in [(704.0, 170.0), (635.0, 264.0), (566.0, 220.0)] {
        context.move(to: CGPoint(x: 341, y: y))
        context.addLine(to: CGPoint(x: 341 + width, y: y))
        context.strokePath()
    }

    let center = CGPoint(x: 650, y: 352)
    let badge = CGPath(ellipseIn: CGRect(x: center.x - 164, y: center.y - 164,
                                        width: 328, height: 328), transform: nil)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -9), blur: 18,
                      color: color(0x0A325F, alpha: 0.24))
    context.setFillColor(color(0x20C6BF))
    context.addPath(badge)
    context.fillPath()
    context.restoreGState()
    gradient(badge, top: 0x7AEED5, bottom: 0x27C6C1)
    context.setStrokeColor(color(0xD3FFF2, alpha: 0.7))
    context.setLineWidth(2)
    context.addPath(badge)
    context.strokePath()

    // Two arcs and two explicitly drawn triangles: no SF Symbols or icon font.
    let ink = color(0x124678)
    let radius: CGFloat = 91
    context.setStrokeColor(ink)
    context.setFillColor(ink)
    context.setLineWidth(27)
    context.setLineCap(.round)
    for startDegrees in [38.0, 218.0] {
        let start = CGFloat(startDegrees) * .pi / 180
        let end = start + 130 * .pi / 180
        context.addArc(center: center, radius: radius, startAngle: start,
                       endAngle: end, clockwise: false)
        context.strokePath()
        let point = CGPoint(x: center.x + radius * cos(end),
                            y: center.y + radius * sin(end))
        let tangent = CGPoint(x: -sin(end), y: cos(end))
        let normal = CGPoint(x: cos(end), y: sin(end))
        let head = CGMutablePath()
        head.move(to: CGPoint(x: point.x + tangent.x * 27, y: point.y + tangent.y * 27))
        head.addLine(to: CGPoint(x: point.x - tangent.x * 20 + normal.x * 31,
                                 y: point.y - tangent.y * 20 + normal.y * 31))
        head.addLine(to: CGPoint(x: point.x - tangent.x * 20 - normal.x * 31,
                                 y: point.y - tangent.y * 20 - normal.y * 31))
        head.closeSubpath()
        context.addPath(head)
        context.fillPath()
    }

    guard let image = context.makeImage() else { throw IconError.image }
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL,
            UTType.png.identifier as CFString, 1, nil) else { throw IconError.destination }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw IconError.destination }
}

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("Usage: swift scripts/draw-icon.swift OUTPUT.png\n".utf8))
    exit(1)
}
try drawIcon(to: URL(fileURLWithPath: CommandLine.arguments[1]))

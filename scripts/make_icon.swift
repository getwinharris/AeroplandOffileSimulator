#!/usr/bin/env swift
// Generates AppIcon iconset PNGs using only AppKit (no pip needed).
import AppKit

func drawIcon(size: CGFloat) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()
    let s = size / 1024.0
    // sky rounded square
    let bg = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: size, height: size),
                          xRadius: 230*s, yRadius: 230*s)
    NSColor(red: 0.22, green: 0.59, blue: 1.0, alpha: 1).setFill()
    bg.fill()
    // sun
    NSColor(red: 1, green: 0.84, blue: 0.25, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: 680*s, y: 684*s, width: 250*s, height: 250*s)).fill()
    // clouds
    NSColor(white: 1, alpha: 0.93).setFill()
    for (x, y, r) in [(180, 324, 90), (300, 364, 120), (430, 324, 90), (700, 244, 80), (810, 284, 100)] as [(CGFloat, CGFloat, CGFloat)] {
        NSBezierPath(ovalIn: NSRect(x: (x-r)*s, y: (y-r)*s, width: 2*r*s, height: 2*r*s)).fill()
    }
    // wings (behind body)
    NSColor(red: 1, green: 0.82, blue: 0.25, alpha: 1).setFill()
    let wl = NSBezierPath(); wl.move(to: NSPoint(x: 120*s, y: 464*s)); wl.line(to: NSPoint(x: 380*s, y: 544*s)); wl.line(to: NSPoint(x: 380*s, y: 424*s)); wl.close(); wl.fill()
    let wr = NSBezierPath(); wr.move(to: NSPoint(x: 904*s, y: 464*s)); wr.line(to: NSPoint(x: 644*s, y: 544*s)); wr.line(to: NSPoint(x: 644*s, y: 424*s)); wr.close(); wr.fill()
    // fuselage
    NSColor(red: 0.91, green: 0.25, blue: 0.25, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: 312*s, y: 312*s, width: 400*s, height: 400*s)).fill()
    // cockpit
    NSColor(red: 0.65, green: 0.9, blue: 1.0, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: 442*s, y: 504*s, width: 140*s, height: 140*s)).fill()
    // smiley eyes
    NSColor.black.setFill()
    NSBezierPath(ovalIn: NSRect(x: 450*s, y: 414*s, width: 50*s, height: 50*s)).fill()
    NSBezierPath(ovalIn: NSRect(x: 524*s, y: 414*s, width: 50*s, height: 50*s)).fill()
    NSColor.white.setFill()
    NSBezierPath(ovalIn: NSRect(x: 468*s, y: 440*s, width: 16*s, height: 16*s)).fill()
    NSBezierPath(ovalIn: NSRect(x: 542*s, y: 440*s, width: 16*s, height: 16*s)).fill()
    img.unlockFocus()
    return img
}

let out = URL(fileURLWithPath: CommandLine.arguments[1])
let iconset = out.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
let sizes = [(16,1),(16,2),(32,1),(32,2),(128,1),(128,2),(256,1),(256,2),(512,1),(512,2)]
for (pt, scale) in sizes {
    let px = pt * scale
    let img = drawIcon(size: CGFloat(px))
    guard let tiff = img.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        fputs("icon render failed at \(px)\n", stderr); exit(1)
    }
    let name = scale == 2 ? "icon_\(pt)x\(pt)@2x.png" : "icon_\(pt)x\(pt).png"
    try! png.write(to: iconset.appendingPathComponent(name))
}
print("iconset written to \(iconset.path)")

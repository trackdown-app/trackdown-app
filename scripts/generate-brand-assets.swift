#!/usr/bin/env swift
// Generates the brand SVGs from the track mark on the brand sheet (Brand.dc.html):
// - the layers of Trackdown/AppIcon.icon, in their light colors (icon.json sets the dark ones)
// - the Logo and Mark image sets in the DesignSystem package
//
// The wordmark is outlined from the bundled Barlow Condensed ExtraBold, so the SVGs hold no text.
// Run from the repository root after changing the mark or the colors:
//
//     swift scripts/generate-brand-assets.swift
//
// icon.json is edited in Icon Composer and is not touched by this script.

import CoreText
import Foundation

// MARK: Palette (brand sheet)

struct MarkColors {
    let line1: String
    let line2: String
    /// Start dot, and the stroke of the change ring and the mystery-station bar.
    let ink: String
    /// Fill of the change ring and the mystery-station bar.
    let paper: String
}

let lightMark = MarkColors(line1: "#2F45D8", line2: "#B8236F", ink: "#15181C", paper: "#FFFFFF")
let darkMark = MarkColors(line1: "#6F82FF", line2: "#F0609F", ink: "#FFFFFF", paper: "#15181C")
let lightWordmark = "#15181C"
let darkWordmark = "#EEF1EE"

// MARK: Mark geometry, in the brand sheet's 96 x 48 view box

enum MarkPart: String, CaseIterable {
    case line1 = "Line1"
    case line2 = "Line2"
    case start = "Start"
    case change = "Change"
    case mystery = "Mystery"

    func svg(_ c: MarkColors) -> String {
        switch self {
        case .line1:
            #"<path d="M10 24H44" stroke="\#(c.line1)" stroke-width="8" stroke-linecap="round"/>"#
        case .line2:
            #"<path d="M52 24H80" stroke="\#(c.line2)" stroke-width="8" stroke-linecap="round"/>"#
        case .start:
            #"<circle cx="10" cy="24" r="8" fill="\#(c.ink)"/>"#
        case .change:
            #"<circle cx="48" cy="24" r="8" fill="\#(c.paper)" stroke="\#(c.ink)" stroke-width="4"/>"#
        case .mystery:
            #"<rect x="76" y="6" width="16" height="36" rx="8" fill="\#(c.paper)" stroke="\#(c.ink)" stroke-width="4"/>"#
        }
    }
}

func markSVG(_ c: MarkColors) -> String {
    MarkPart.allCases.map { $0.svg(c) }.joined(separator: "\n")
}

// MARK: Wordmark outline

func wordmarkPath(fontURL: URL, size: CGFloat, tracking: CGFloat) -> (d: String, bounds: CGRect) {
    guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(fontURL as CFURL) as? [CTFontDescriptor],
        let descriptor = descriptors.first
    else { fatalError("Cannot read \(fontURL.path)") }
    let font = CTFontCreateWithFontDescriptor(descriptor, size, nil)
    let attributes: [CFString: Any] = [kCTFontAttributeName: font, kCTKernAttributeName: tracking]
    let string = CFAttributedStringCreate(nil, "Trackdown" as CFString, attributes as CFDictionary)!
    let line = CTLineCreateWithAttributedString(string)

    let path = CGMutablePath()
    for run in CTLineGetGlyphRuns(line) as! [CTRun] {
        let count = CTRunGetGlyphCount(run)
        var glyphs = [CGGlyph](repeating: 0, count: count)
        var positions = [CGPoint](repeating: .zero, count: count)
        CTRunGetGlyphs(run, CFRange(location: 0, length: count), &glyphs)
        CTRunGetPositions(run, CFRange(location: 0, length: count), &positions)
        for (glyph, position) in zip(glyphs, positions) {
            guard let outline = CTFontCreatePathForGlyph(font, glyph, nil) else { continue }
            // Core Text is y-up; SVG is y-down with the baseline at y = 0.
            let transform = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: position.x, ty: 0)
            path.addPath(outline, transform: transform)
        }
    }
    return (svgPathData(path), path.boundingBoxOfPath)
}

func svgPathData(_ path: CGPath) -> String {
    func f(_ v: CGFloat) -> String {
        let s = String(format: "%.2f", v)
        return s.replacingOccurrences(of: #"\.?0+$"#, with: "", options: .regularExpression)
    }
    func p(_ pt: CGPoint) -> String { "\(f(pt.x)) \(f(pt.y))" }
    var d = ""
    path.applyWithBlock { element in
        let e = element.pointee
        switch e.type {
        case .moveToPoint: d += "M\(p(e.points[0]))"
        case .addLineToPoint: d += "L\(p(e.points[0]))"
        case .addQuadCurveToPoint: d += "Q\(p(e.points[0])) \(p(e.points[1]))"
        case .addCurveToPoint: d += "C\(p(e.points[0])) \(p(e.points[1])) \(p(e.points[2]))"
        case .closeSubpath: d += "Z"
        @unknown default: break
        }
    }
    return d
}

// MARK: Output

func write(_ contents: String, to path: String) {
    let url = URL(fileURLWithPath: path)
    do {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try (contents + "\n").write(to: url, atomically: true, encoding: .utf8)
    } catch {
        fatalError("Cannot write \(path): \(error)")
    }
    print("wrote \(path)")
}

func svgDocument(width: CGFloat, height: CGFloat, body: String) -> String {
    let w = String(format: "%g", width)
    let h = String(format: "%g", height)
    return """
        <svg xmlns="http://www.w3.org/2000/svg" width="\(w)" height="\(h)" viewBox="0 0 \(w) \(h)" fill="none">
        \(body)
        </svg>
        """
}

// App icon layers: one single-color SVG per shape on the 1024 pt icon canvas, so the layers line
// up when Icon Composer stacks them and icon.json can recolor each one for the dark appearance.
// Every shape is a filled outline, no strokes: a layer fill in icon.json paints the whole shape,
// so a stroked ring would turn into a disc. The mark fills 148 of 192 pt across, as on the
// brand sheet.
func filled(_ d: String, _ color: String) -> String {
    #"<path fill-rule="evenodd" fill="\#(color)" d="\#(d)"/>"#
}
let iconLayers: [(name: String, svg: String)] = [
    // Both lines have round caps (a 4 pt cap at each end) that end under a station, so the
    // two lines look the same wherever the glass shows their edges.
    ("Line1", filled("M10 20H44A4 4 0 0 1 44 28H10A4 4 0 0 1 10 20Z", lightMark.line1)),
    ("Line2", filled("M52 20H80A4 4 0 0 1 80 28H52A4 4 0 0 1 52 20Z", lightMark.line2)),
    ("Start", filled("M2 24A8 8 0 1 0 18 24A8 8 0 1 0 2 24Z", lightMark.ink)),
    ("ChangeFill", filled("M40 24A8 8 0 1 0 56 24A8 8 0 1 0 40 24Z", lightMark.paper)),
    (
        "ChangeRing",
        filled("M38 24A10 10 0 1 0 58 24A10 10 0 1 0 38 24ZM42 24A6 6 0 1 0 54 24A6 6 0 1 0 42 24Z", lightMark.ink)
    ),
    ("MysteryFill", filled("M76 14A8 8 0 0 1 92 14V34A8 8 0 0 1 76 34Z", lightMark.paper)),
    (
        "MysteryRing",
        filled(
            "M74 14A10 10 0 0 1 94 14V34A10 10 0 0 1 74 34ZM78 14A6 6 0 0 1 90 14V34A6 6 0 0 1 78 34Z",
            lightMark.ink
        )
    ),
]
let iconCanvas: CGFloat = 1024
let iconScale = iconCanvas * 148 / 192 / 96
let iconOffset = (x: (iconCanvas - 96 * iconScale) / 2, y: (iconCanvas - 48 * iconScale) / 2)
for layer in iconLayers {
    let transform = String(format: "translate(%.3f %.3f) scale(%.5f)", iconOffset.x, iconOffset.y, iconScale)
    let body = #"<g transform="\#(transform)">\#(layer.svg)</g>"#
    write(
        svgDocument(width: iconCanvas, height: iconCanvas, body: body),
        to: "Trackdown/AppIcon.icon/Assets/\(layer.name).svg"
    )
}

// In-app mark and logo. Sizes follow the brand sheet: a 96 x 48 mark, 18 pt gap, wordmark at
// 96 pt with -0.01 em tracking, the wordmark's outline centered on the mark.
let catalog = "Packages/DesignSystem/Sources/DesignSystem/Resources/Images.xcassets"
let fontURL = URL(
    fileURLWithPath: "Packages/DesignSystem/Sources/DesignSystem/Resources/Fonts/BarlowCondensed-ExtraBold.ttf"
)
let wordmark = wordmarkPath(fontURL: fontURL, size: 96, tracking: -0.96)
let markWidth: CGFloat = 96
let markHeight: CGFloat = 48
let gap: CGFloat = 18
let wordX = markWidth + gap - wordmark.bounds.minX
let logoHeight = max(markHeight, wordmark.bounds.height)
let markY = (logoHeight - markHeight) / 2
let wordY = logoHeight / 2 - wordmark.bounds.midY
let logoWidth = (wordX + wordmark.bounds.maxX).rounded(.up)

for (suffix, mark, word) in [("", lightMark, lightWordmark), ("-Dark", darkMark, darkWordmark)] {
    write(
        svgDocument(width: markWidth, height: markHeight, body: markSVG(mark)),
        to: "\(catalog)/Mark.imageset/Mark\(suffix).svg"
    )
    let logoBody = """
        <g transform="translate(0 \(String(format: "%.2f", markY)))">
        \(markSVG(mark))
        </g>
        <path transform="translate(\(String(format: "%.2f", wordX)) \(String(format: "%.2f", wordY)))" \
        fill="\(word)" d="\(wordmark.d)"/>
        """
    write(
        svgDocument(width: logoWidth, height: logoHeight.rounded(.up), body: logoBody),
        to: "\(catalog)/Logo.imageset/Logo\(suffix).svg"
    )
}

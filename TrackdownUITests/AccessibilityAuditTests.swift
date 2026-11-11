import UIKit
import XCTest

/// XCTest is required here because accessibility auditing is an XCUIApplication API.
nonisolated final class AccessibilityAuditTests: XCTestCase {
    @MainActor
    func testAllScreensInLightMode() throws {
        try auditScreens(contentSize: "UICTContentSizeCategoryL", dark: false)
    }

    @MainActor
    func testAllScreensInDarkMode() throws {
        try auditScreens(contentSize: "UICTContentSizeCategoryL", dark: true)
    }

    @MainActor
    func testAllScreensAtAX5() throws {
        try auditScreens(contentSize: "UICTContentSizeCategoryAccessibilityXXXL", dark: false)
    }

    @MainActor
    func testAllScreensAtAX5InDarkMode() throws {
        try auditScreens(contentSize: "UICTContentSizeCategoryAccessibilityXXXL", dark: true)
    }

    @MainActor
    func testDynamicTypeSupport() throws {
        try auditScreens(contentSize: "UICTContentSizeCategoryL", dark: false, dynamicTypeOnly: true)
    }

    @MainActor
    func testKeyboardSuggestionsAtAX5() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
            "-accessibility-screen", "playing",
        ]
        app.launch()
        let field = app.textFields["Guess a station"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText("a")
        let suggestions = app.scrollViews["Matching stations"]
        XCTAssertTrue(suggestions.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(suggestions.frame.height, 44)
        XCTAssertTrue(field.isHittable)
        XCTAssertTrue(app.buttons["Guess"].isHittable)
        XCTAssertTrue(app.buttons["Amsterdam Centraal, Netherlands"].exists)
        app.terminate()
    }

    func testRenderedContrastRequiresSignificantContrastingColors() throws {
        func image(ink: UInt8, inkPixels: Int) throws -> CGImage {
            var pixels = [UInt8](repeating: 255, count: 100 * 100 * 4)
            for index in 0..<inkPixels {
                for channel in 0..<3 { pixels[index * 4 + channel] = ink }
            }
            let provider = try XCTUnwrap(CGDataProvider(data: Data(pixels) as CFData))
            let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
            return try XCTUnwrap(
                CGImage(
                    width: 100, height: 100, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 400,
                    space: space,
                    bitmapInfo: CGBitmapInfo(
                        rawValue: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue),
                    provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
        }
        let blackOnWhite = try XCTUnwrap(Self.renderedContrast(image(ink: 0, inkPixels: 1_000)))
        XCTAssertEqual(blackOnWhite.ratio, 21, accuracy: 0.001)
        let grayOnWhite = try XCTUnwrap(Self.renderedContrast(image(ink: 128, inkPixels: 1_000)))
        XCTAssertEqual(grayOnWhite.ratio, 3.95, accuracy: 0.01)
        XCTAssertLessThan(grayOnWhite.ratio, 4.5)
        XCTAssertNil(try Self.renderedContrast(image(ink: 0, inkPixels: 1)))
        XCTAssertNil(try Self.renderedContrast(image(ink: 255, inkPixels: 1_000)))
    }

    @MainActor
    private func auditScreens(contentSize: String, dark: Bool, dynamicTypeOnly: Bool = false) throws {
        continueAfterFailure = false
        // Font-scaling audits change system text size. Keep pixel audits pinned to their intended size,
        // and audit font scaling separately with the real system environment.
        let auditTypes: XCUIAccessibilityAuditType = dynamicTypeOnly ? .dynamicType : .all.subtracting(.dynamicType)
        for screen in ["solved", "missed", "playing", "how-to-play", "networks", "archive", "consent", "privacy"] {
            try XCTContext.runActivity(named: "\(screen), \(contentSize), dark: \(dark)") { _ in
                let app = XCUIApplication()
                app.launchArguments = [
                    "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
                    "-UIPreferredContentSizeCategoryName", contentSize,
                    "-accessibility-screen", screen,
                ]
                if dark { app.launchArguments.append("-accessibility-dark") }
                if dynamicTypeOnly { app.launchArguments.append("-accessibility-dynamic-type") }
                app.launch()
                guard app.wait(for: .runningForeground, timeout: 5),
                    app.descendants(matching: .any)["accessibility-fixture-\(screen)"].firstMatch
                        .waitForExistence(timeout: 10)
                else {
                    XCTFail("Accessibility fixture did not load: \(screen)")
                    app.terminate()
                    return
                }
                if screen == "playing" {
                    let networkIsLabeled = app.buttons["Network: Netherlands. Change network"].exists
                    let tripCount = app.buttons.matching(
                        NSPredicate(format: "label BEGINSWITH %@", "Guess 1, Maastricht,")
                    ).count
                    let trip = app.buttons.matching(
                        NSPredicate(format: "label BEGINSWITH %@", "Guess 1, Maastricht,")
                    ).firstMatch
                    if !networkIsLabeled || tripCount != 1 {
                        let attachment = XCTAttachment(screenshot: app.screenshot())
                        attachment.lifetime = .keepAlways
                        add(attachment)
                    }
                    XCTAssertTrue(networkIsLabeled)
                    XCTAssertEqual(tripCount, 1)
                    XCTAssertTrue(trip.label.contains("2 hours"))
                    XCTAssertTrue(trip.label.contains("25 minutes"))
                    XCTAssertTrue(trip.label.contains("hidden station"))
                }
                try auditVisibleContent(app, auditTypes: auditTypes)
                let scrollView = app.scrollViews.firstMatch
                if scrollView.exists {
                    scrollView.swipeUp(velocity: .fast)
                    try auditVisibleContent(app, auditTypes: auditTypes)
                }
                app.terminate()
            }
        }
    }

    @MainActor
    private func auditVisibleContent(_ app: XCUIApplication, auditTypes: XCUIAccessibilityAuditType) throws {
        let olderPuzzlesSample = auditTypes.contains(.contrast) ? sampleOlderPuzzlesLabel(app) : nil
        let appFrame = app.frame
        let bars =
            (app.navigationBars.allElementsBoundByIndex + app.toolbars.allElementsBoundByIndex
            + app.searchFields.allElementsBoundByIndex).map(\.frame)
        let scrollViews = app.scrollViews.allElementsBoundByIndex.map { scrollView in
            var viewport = scrollView.frame.intersection(appFrame)
            var occluders: [CGRect] = []
            // Native navigation/search bars cover scroll-edge content with system glass.
            for bounds in bars {
                guard !bounds.isEmpty, bounds.width >= viewport.width / 2, bounds.intersects(viewport) else {
                    continue
                }
                if bounds.midY < viewport.midY {
                    let bottom = viewport.maxY
                    viewport.origin.y = max(viewport.minY, bounds.maxY)
                    viewport.size.height = max(0, bottom - viewport.minY)
                } else {
                    viewport.size.height = max(0, min(viewport.maxY, bounds.minY) - viewport.minY)
                }
                occluders.append(bounds)
            }
            return (element: scrollView, viewport: viewport, occluders: occluders)
        }
        try app.performAccessibilityAudit(for: auditTypes) { issue in
            // Repository layout standards permit journey drawings to stop growing at xxxLarge.
            // Only the explicitly identified drawing is capped; the station, duration and summary scale fully.
            if issue.auditType == .dynamicType, let element = issue.element,
                element.identifier == "trip-track"
            {
                XCTContext.runActivity(named: "Intentional journey drawing scale limit") { activity in
                    let attachment = XCTAttachment(
                        string: "\(element.label)\nframe: \(element.frame)\nidentifier: trip-track\ncap: xxxLarge")
                    attachment.lifetime = .keepAlways
                    activity.add(attachment)
                }
                return true
            }
            guard issue.auditType == .contrast || issue.auditType == .textClipped,
                let element = issue.element
            else { return false }
            let frame = element.frame
            let label = element.label
            let elementType = element.elementType
            if issue.auditType == .contrast, element.identifier == "older-puzzles-label",
                let sample = olderPuzzlesSample, sample.ratio >= 4.5,
                abs(frame.minX - sample.frame.minX) <= 1, abs(frame.minY - sample.frame.minY) <= 1,
                abs(frame.width - sample.frame.width) <= 1, abs(frame.height - sample.frame.height) <= 1
            {
                XCTContext.runActivity(named: "Independent rendered label contrast verification") { activity in
                    let crop = XCTAttachment(screenshot: sample.screenshot)
                    crop.lifetime = .keepAlways
                    activity.add(crop)
                    let measurement = XCTAttachment(
                        string:
                            "Native glass-label contrast finding independently checked from sRGB screenshot pixels.\nidentifier: older-puzzles-label\nframe: \(sample.frame)\ncontrast: \(sample.ratio):1\nmean RGB buckets: \(sample.colors)\nBoth dominant buckets exceed 0.5% of crop pixels. Required ratio: 4.5:1."
                    )
                    measurement.lifetime = .keepAlways
                    activity.add(measurement)
                }
                return true
            }
            // Inactive controls are exempt from the WCAG text-contrast requirement. Keep auditing every
            // enabled button; the system glass style intentionally dims the unavailable Guess action.
            if issue.auditType == .contrast, elementType == .button, !element.isEnabled {
                XCTContext.runActivity(named: "Inactive button contrast exemption") { activity in
                    let attachment = XCTAttachment(
                        string: "\(label)\nframe: \(frame)\nenabled: false")
                    attachment.lifetime = .keepAlways
                    activity.add(attachment)
                }
                return true
            }
            for scrollView in scrollViews {
                let matchingContent = scrollView.element.descendants(matching: elementType)
                    .matching(NSPredicate(format: "label == %@", label))
                    .allElementsBoundByIndex
                guard matchingContent.contains(where: { $0.frame == frame }) else { continue }
                let viewport = scrollView.viewport
                // The audit also scans text that SwiftUI clips at scroll boundaries. These pixels are
                // intentionally invisible; audit them when scrolling brings them fully into view.
                if frame.isEmpty || !viewport.insetBy(dx: -1, dy: -1).contains(frame) {
                    XCTContext.runActivity(named: "Clipped scroll content: \(issue.compactDescription)") { activity in
                        let attachment = XCTAttachment(
                            string:
                                "\(label)\nelement: \(frame)\nviewport: \(viewport)\noccluding bars: \(scrollView.occluders)"
                        )
                        attachment.lifetime = .keepAlways
                        activity.add(attachment)
                    }
                    return true
                }
            }
            XCTContext.runActivity(named: "Visible audit finding: \(issue.compactDescription)") { activity in
                let viewports = scrollViews.map(\.viewport)
                let attachment = XCTAttachment(
                    string: "\(label)\nelement: \(frame)\nscroll views: \(viewports)")
                attachment.lifetime = .keepAlways
                activity.add(attachment)
            }
            return false
        }
    }

    private struct LabelContrastSample {
        let frame: CGRect
        let screenshot: XCUIScreenshot
        let ratio: Double
        let colors: [[Double]]
    }

    @MainActor
    private func sampleOlderPuzzlesLabel(_ app: XCUIApplication) -> LabelContrastSample? {
        let labels = app.staticTexts.matching(identifier: "older-puzzles-label")
        guard labels.count == 1 else { return nil }
        let label = labels.firstMatch
        let frame = label.frame
        guard !frame.isEmpty, app.frame.contains(frame), label.isHittable else { return nil }
        let screenshot = label.screenshot()
        guard let image = screenshot.image.cgImage, let measurement = Self.renderedContrast(image) else { return nil }
        return LabelContrastSample(
            frame: frame, screenshot: screenshot, ratio: measurement.ratio, colors: measurement.colors)
    }

    private struct PixelBucket {
        var count = 0
        var red = 0
        var green = 0
        var blue = 0

        var mean: [Double] {
            [Double(red) / Double(count), Double(green) / Double(count), Double(blue) / Double(count)]
        }
    }

    /// Measures actual rendered colors, not dynamic asset names or inferred system-glass backgrounds.
    private static func renderedContrast(_ image: CGImage) -> (ratio: Double, colors: [[Double]])? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0, let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let rendered = pixels.withUnsafeMutableBytes { bytes in
            guard
                let context = CGContext(
                    data: bytes.baseAddress, width: width, height: height, bitsPerComponent: 8,
                    bytesPerRow: width * 4, space: colorSpace,
                    bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard rendered else { return nil }
        var buckets: [Int: PixelBucket] = [:]
        for offset in stride(from: 0, to: pixels.count, by: 4) {
            // Uncomposited transparent pixels cannot establish visible text contrast.
            guard pixels[offset + 3] == 255 else { continue }
            let red = Int(pixels[offset])
            let green = Int(pixels[offset + 1])
            let blue = Int(pixels[offset + 2])
            let key = ((red >> 3) << 10) | ((green >> 3) << 5) | (blue >> 3)
            buckets[key, default: PixelBucket()].count += 1
            buckets[key, default: PixelBucket()].red += red
            buckets[key, default: PixelBucket()].green += green
            buckets[key, default: PixelBucket()].blue += blue
        }
        let dominant = buckets.values.sorted { $0.count > $1.count }.prefix(2)
        guard dominant.count == 2,
            dominant.allSatisfy({ Double($0.count) > Double(width * height) * 0.005 })
        else { return nil }
        let colors = dominant.map(\.mean)
        let luminances = colors.map { color in
            zip(color, [0.2126, 0.7152, 0.0722]).reduce(0.0) { result, component in
                let channel = component.0 / 255
                let linear = channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
                return result + linear * component.1
            }
        }
        let ratio = (max(luminances[0], luminances[1]) + 0.05) / (min(luminances[0], luminances[1]) + 0.05)
        return (ratio, colors)
    }
}

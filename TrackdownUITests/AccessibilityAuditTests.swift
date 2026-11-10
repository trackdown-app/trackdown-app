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

    @MainActor
    private func auditScreens(contentSize: String, dark: Bool, dynamicTypeOnly: Bool = false) throws {
        continueAfterFailure = true
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
                    let hasDuplicateDuration = app.staticTexts["2h 25m"].exists
                    if !networkIsLabeled || tripCount != 1 || hasDuplicateDuration {
                        let attachment = XCTAttachment(screenshot: app.screenshot())
                        attachment.lifetime = .keepAlways
                        add(attachment)
                    }
                    XCTAssertTrue(networkIsLabeled)
                    XCTAssertEqual(tripCount, 1)
                    XCTAssertFalse(hasDuplicateDuration)
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
            guard issue.auditType == .contrast || issue.auditType == .textClipped,
                let element = issue.element
            else { return false }
            let frame = element.frame
            let label = element.label
            let elementType = element.elementType
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
}

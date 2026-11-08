import Foundation
import Testing

/// Reads `Colors.xcassets` from the package sources, so the checks run on the values the app ships.
@Suite("Brand colors")
struct TrackdownColorTests {
    enum Appearance: String, CaseIterable, Sendable {
        case light, dark
    }

    struct Pair: Sendable, CustomTestStringConvertible {
        let text: String
        let background: String
        var testDescription: String { "\(text) on \(background)" }
    }

    static let names = [
        "Background", "Surface", "Ink", "Muted", "Rule", "Empty", "Grid", "Line1", "Line2", "Line3", "OnLine",
    ]

    /// Every color used as text, on every color it is drawn on.
    static let textPairs = [
        Pair(text: "Ink", background: "Background"),
        Pair(text: "Ink", background: "Surface"),
        Pair(text: "Muted", background: "Background"),
        Pair(text: "Muted", background: "Surface"),
        Pair(text: "Background", background: "Ink"),
        Pair(text: "Surface", background: "Ink"),
        Pair(text: "OnLine", background: "Line1"),
        Pair(text: "OnLine", background: "Line2"),
        Pair(text: "OnLine", background: "Line3"),
    ]

    @Test("Catalog has every brand color with a light and a dark value", arguments: names)
    func hasLightAndDark(name: String) throws {
        let values = try Self.catalogColor(name)
        #expect(values.keys.sorted() == ["dark", "light"])
    }

    @Test("Brand values match the brand sheet")
    func matchesBrandSheet() throws {
        let expected: [String: (light: String, dark: String)] = [
            "Background": ("F6F7F5", "14181D"),
            "Ink": ("15181C", "EEF1EE"),
            "Line1": ("2F45D8", "8394FF"),
            "Line2": ("B8236F", "F27AB6"),
            "Line3": ("0B7F5A", "4FD3A0"),
        ]
        for (name, hex) in expected {
            let values = try Self.catalogColor(name)
            #expect(values["light"] == RGB(hex: hex.light), "\(name) light")
            #expect(values["dark"] == RGB(hex: hex.dark), "\(name) dark")
        }
    }

    @Test(
        "Text pairs meet 4.5:1 contrast",
        arguments: textPairs, Appearance.allCases
    )
    func textContrast(pair: Pair, appearance: Appearance) throws {
        let text = try #require(try Self.catalogColor(pair.text)[appearance.rawValue])
        let background = try #require(try Self.catalogColor(pair.background)[appearance.rawValue])
        let ratio = text.contrast(with: background)
        #expect(ratio >= 4.5, "\(pair.testDescription), \(appearance): \(ratio)")
    }

    // MARK: Catalog parsing

    struct RGB: Equatable {
        let red: Double
        let green: Double
        let blue: Double

        init(red: Double, green: Double, blue: Double) {
            self.red = red
            self.green = green
            self.blue = blue
        }

        init?(hex: String) {
            guard hex.count == 6, let value = UInt32(hex, radix: 16) else { return nil }
            red = Double((value >> 16) & 0xFF) / 255
            green = Double((value >> 8) & 0xFF) / 255
            blue = Double(value & 0xFF) / 255
        }

        /// WCAG 2 relative luminance.
        var luminance: Double {
            func linear(_ c: Double) -> Double {
                c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
        }

        func contrast(with other: RGB) -> Double {
            let (a, b) = (luminance, other.luminance)
            return (max(a, b) + 0.05) / (min(a, b) + 0.05)
        }
    }

    private struct ColorSet: Decodable {
        struct Entry: Decodable {
            struct Appearance: Decodable {
                let appearance: String
                let value: String
            }
            struct Value: Decodable {
                let components: [String: String]
            }
            let appearances: [Appearance]?
            let color: Value
        }
        let colors: [Entry]
    }

    private static let catalogURL = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .appending(path: "../../Sources/DesignSystem/Resources/Colors.xcassets")
        .standardized

    /// The light and dark values of a colorset, keyed "light" and "dark".
    static func catalogColor(_ name: String) throws -> [String: RGB] {
        let url = catalogURL.appending(path: "\(name).colorset/Contents.json")
        let set = try JSONDecoder().decode(ColorSet.self, from: Data(contentsOf: url))
        var result: [String: RGB] = [:]
        for entry in set.colors {
            let isDark = entry.appearances?.contains { $0.appearance == "luminosity" && $0.value == "dark" } ?? false
            let key = isDark ? "dark" : "light"
            let c = entry.color.components
            func channel(_ name: String) throws -> Double {
                let raw = try #require(c[name])
                if raw.hasPrefix("0x"), let int = UInt8(raw.dropFirst(2), radix: 16) {
                    return Double(int) / 255
                }
                return try #require(Double(raw))
            }
            result[key] = RGB(red: try channel("red"), green: try channel("green"), blue: try channel("blue"))
        }
        return result
    }
}

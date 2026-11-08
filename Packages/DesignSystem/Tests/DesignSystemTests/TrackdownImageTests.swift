import Foundation
import Testing

/// Reads `Images.xcassets` from the package sources, so the checks run on the files the app ships.
@Suite("Brand images")
struct TrackdownImageTests {
    private struct ImageSet: Decodable {
        struct Entry: Decodable {
            struct Appearance: Decodable {
                let appearance: String
                let value: String
            }
            let filename: String
            let appearances: [Appearance]?
        }
        struct Properties: Decodable {
            let preservesVectorRepresentation: Bool?

            enum CodingKeys: String, CodingKey {
                case preservesVectorRepresentation = "preserves-vector-representation"
            }
        }
        let images: [Entry]
        let properties: Properties?
    }

    private static let catalogURL = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .appending(path: "../../Sources/DesignSystem/Resources/Images.xcassets")
        .standardized

    @Test("Image set has a light and a dark vector variant", arguments: ["Logo", "Mark"])
    func hasLightAndDarkVectors(name: String) throws {
        let folder = Self.catalogURL.appending(path: "\(name).imageset")
        let set = try JSONDecoder().decode(
            ImageSet.self,
            from: Data(contentsOf: folder.appending(path: "Contents.json"))
        )
        #expect(set.properties?.preservesVectorRepresentation == true)

        let dark = set.images.filter { entry in
            entry.appearances?.contains { $0.appearance == "luminosity" && $0.value == "dark" } ?? false
        }
        let light = set.images.filter { $0.appearances == nil }
        #expect(light.map(\.filename) == ["\(name).svg"])
        #expect(dark.map(\.filename) == ["\(name)-Dark.svg"])

        for entry in set.images {
            let svg = try String(contentsOf: folder.appending(path: entry.filename), encoding: .utf8)
            #expect(svg.hasPrefix("<svg"))
            // Text would render in a fallback font where Barlow is not installed: outline it.
            #expect(!svg.contains("<text"), "\(entry.filename) has live text")
        }
    }
}

import CoreText
import Foundation
import Testing

@testable import DesignSystem

@Suite("Fonts")
struct TrackdownFontTests {
    @Test("Registers every bundled face", arguments: TrackdownFont.Face.allCases)
    func registersFace(face: TrackdownFont.Face) {
        TrackdownFont.register()
        // CTFontCreateWithName falls back to another font when the name is unknown.
        let font = CTFontCreateWithName(face.rawValue as CFString, 17, nil)
        #expect(CTFontCopyPostScriptName(font) as String == face.rawValue)
    }

    @Test("Registering twice is harmless")
    func registersTwice() {
        TrackdownFont.register()
        TrackdownFont.register()
    }

    @Test("Ships the OFL license next to the fonts")
    func shipsLicense() throws {
        let url = try #require(Bundle.module.url(forResource: "OFL", withExtension: "txt", subdirectory: "Fonts"))
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.contains("SIL Open Font License"))
    }
}

import CoreGraphics
import Testing

@testable import DesignSystem

@Suite("Reserved content geometry")
struct ReservedContentTests {
    private let bounds = CGRect(x: 0, y: 0, width: 900, height: 600)

    @Test("Inactive or offscreen regions do not shrink content")
    func noObstacles() {
        #expect(ReservedContentGeometry.availableFrame(in: bounds, avoiding: []) == bounds)
        #expect(
            ReservedContentGeometry.availableFrame(in: bounds, avoiding: [CGRect(x: 950, y: 0, width: 10, height: 10)])
                == bounds)
    }

    @Test(
        "Content clears vertical and horizontal folds and camera occlusions",
        arguments: [
            CGRect(x: 430, y: 0, width: 40, height: 600),
            CGRect(x: 0, y: 280, width: 900, height: 40),
            CGRect(x: 820, y: 0, width: 80, height: 80),
        ])
    func avoidsRegion(_ obstacle: CGRect) {
        let result = ReservedContentGeometry.availableFrame(in: bounds, avoiding: [obstacle])
        #expect(bounds.contains(result))
        #expect(result.width > 0 && result.height > 0)
        let overlap = result.intersection(obstacle)
        #expect(overlap.isNull || overlap.width == 0 || overlap.height == 0)
    }

    @Test("Camera and fold are avoided together")
    func multipleRegions() {
        let fold = CGRect(x: 430, y: 0, width: 40, height: 600)
        let camera = CGRect(x: 700, y: 0, width: 200, height: 110)
        let result = ReservedContentGeometry.availableFrame(in: bounds, avoiding: [fold, camera])
        #expect(bounds.contains(result))
        #expect(result.width * result.height >= 430 * 600)
        for region in [fold, camera] {
            let overlap = result.intersection(region)
            #expect(overlap.isNull || overlap.width == 0 || overlap.height == 0)
        }
    }

    @Test("Equal fold regions prefer the lower or right side for controls")
    func preferredSide() {
        #expect(
            ReservedContentGeometry.availableFrame(
                in: bounds, avoiding: [CGRect(x: 430, y: 0, width: 40, height: 600)])
                == CGRect(x: 470, y: 0, width: 430, height: 600))
        #expect(
            ReservedContentGeometry.availableFrame(
                in: bounds, avoiding: [CGRect(x: 0, y: 280, width: 900, height: 40)])
                == CGRect(x: 0, y: 320, width: 900, height: 280))
    }
}

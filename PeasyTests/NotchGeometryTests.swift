import CoreGraphics
import Testing
@testable import Peasy

@MainActor
struct NotchGeometryTests {
    @Test func notchSitsBetweenAuxiliaryAreas() {
        let geometry = NotchGeometry(
            screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            topInset: 32,
            leftAreaWidth: 660,
            rightAreaWidth: 660,
            menuBarHeight: 32
        )
        #expect(geometry.hasNotch)
        #expect(geometry.notchRect == CGRect(x: 660, y: 950, width: 192, height: 32))
    }

    @Test func notchOnOffsetScreen() {
        let geometry = NotchGeometry(
            screenFrame: CGRect(x: -1512, y: 200, width: 1512, height: 982),
            topInset: 32,
            leftAreaWidth: 660,
            rightAreaWidth: 660,
            menuBarHeight: 32
        )
        #expect(geometry.notchRect == CGRect(x: -852, y: 1150, width: 192, height: 32))
    }

    @Test func screenWithoutNotchGetsVirtualIsland() {
        let geometry = NotchGeometry(
            screenFrame: CGRect(x: 0, y: 0, width: 2560, height: 1440),
            topInset: 0,
            leftAreaWidth: nil,
            rightAreaWidth: nil,
            menuBarHeight: 25
        )
        #expect(!geometry.hasNotch)
        #expect(geometry.notchRect == CGRect(x: 1190, y: 1415, width: 180, height: 25))
    }

    @Test func hiddenMenuBarUsesMinimumHeight() {
        let geometry = NotchGeometry(
            screenFrame: CGRect(x: 0, y: 0, width: 2560, height: 1440),
            topInset: 0,
            leftAreaWidth: nil,
            rightAreaWidth: nil,
            menuBarHeight: 0
        )
        #expect(geometry.notchRect.height == NotchGeometry.minimumMenuBarHeight)
        #expect(geometry.notchRect.maxY == 1440)
    }

    @Test func inconsistentAreasFallBackToVirtualIsland() {
        let geometry = NotchGeometry(
            screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            topInset: 32,
            leftAreaWidth: 800,
            rightAreaWidth: 800,
            menuBarHeight: 32
        )
        #expect(!geometry.hasNotch)
        #expect(geometry.notchRect == CGRect(x: 666, y: 950, width: 180, height: 32))
    }
}

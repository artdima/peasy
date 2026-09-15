import CoreGraphics
import Testing
@testable import Peasy

struct PanelGeometryTests {
    let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
    let size = CGSize(width: 760, height: 540)

    @Test func panelFloatsUnderTheStatusItem() {
        let item = CGRect(x: 1200, y: screen.maxY - 38, width: 50, height: 38)
        let frame = PanelPlacement(item: item, screen: screen, panelSize: size).frame
        let expectedTop = item.minY - PanelGeometry.gap
        let expectedRight = item.maxX + PanelGeometry.overhang

        #expect(frame.size == size)
        #expect(frame.maxY == expectedTop)
        #expect(frame.maxX == expectedRight)
    }

    @Test func panelPullsInNearTheRightEdge() {
        let item = CGRect(x: 1410, y: screen.maxY - 24, width: 50, height: 24)
        let frame = PanelPlacement(item: item, screen: screen, panelSize: size).frame
        let screenEdge = screen.maxX - PanelGeometry.screenMargin

        #expect(frame.maxX == screenEdge)
        #expect(frame.width == size.width)
    }

    @Test func panelSlidesRightOnANarrowScreen() {
        let narrow = CGRect(x: 0, y: 0, width: 800, height: 600)
        let item = CGRect(x: 120, y: narrow.maxY - 24, width: 50, height: 24)
        let frame = PanelPlacement(item: item, screen: narrow, panelSize: size).frame
        let leftEdge = narrow.minX + PanelGeometry.screenMargin

        #expect(frame.minX == leftEdge)
        #expect(frame.width == size.width)
    }

    @Test func panelFollowsTheScreenOrigin() {
        let external = CGRect(x: -2560, y: 0, width: 2560, height: 1440)
        let item = CGRect(x: -400, y: external.maxY - 24, width: 50, height: 24)
        let frame = PanelPlacement(item: item, screen: external, panelSize: size).frame

        #expect(frame.maxX == item.maxX + PanelGeometry.overhang)
        #expect(frame.minX >= external.minX + PanelGeometry.screenMargin)
        #expect(frame.maxY == item.minY - PanelGeometry.gap)
    }
}

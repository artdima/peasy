import CoreGraphics
import Testing
@testable import Peasy

@MainActor
struct DisplayPreferenceTests {
    struct FakeScreen: DisplayCandidate, Equatable {
        let name: String
        let frame: CGRect
        var hasNotch = false
        var isBuiltIn = false
    }

    let external = FakeScreen(name: "external", frame: CGRect(x: 0, y: 0, width: 2560, height: 1440))
    let laptop = FakeScreen(
        name: "laptop",
        frame: CGRect(x: 2560, y: 0, width: 1512, height: 982),
        hasNotch: true,
        isBuiltIn: true
    )

    @Test func builtInPrefersTheNotch() {
        #expect(DisplayPreference.builtIn.pick(from: [external, laptop], pointer: .zero) == laptop)
    }

    @Test func builtInFallsBackToMainWhenLidIsClosed() {
        #expect(DisplayPreference.builtIn.pick(from: [external], pointer: .zero) == external)
    }

    @Test func builtInWithoutNotchUsesBuiltInScreen() {
        let oldLaptop = FakeScreen(name: "old", frame: laptop.frame, isBuiltIn: true)
        #expect(DisplayPreference.builtIn.pick(from: [external, oldLaptop], pointer: .zero) == oldLaptop)
    }

    @Test func mainUsesFirstScreen() {
        #expect(DisplayPreference.main.pick(from: [external, laptop], pointer: CGPoint(x: 3000, y: 100)) == external)
    }

    @Test func pointerFollowsTheCursor() {
        #expect(DisplayPreference.pointer.pick(from: [external, laptop], pointer: CGPoint(x: 3000, y: 100)) == laptop)
        #expect(DisplayPreference.pointer.pick(from: [external, laptop], pointer: CGPoint(x: 100, y: 100)) == external)
    }

    @Test func noScreensMeansNoPanel() {
        #expect(DisplayPreference.main.pick(from: [FakeScreen](), pointer: .zero) == nil)
    }
}

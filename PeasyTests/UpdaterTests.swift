import Foundation
import Testing
@testable import Peasy

struct UpdaterTests {
    private let info = Bundle.main.infoDictionary ?? [:]

    @Test func feedIsServedOverHTTPS() throws {
        let feed = try #require(info["SUFeedURL"] as? String)
        #expect(URL(string: feed)?.scheme == "https")
    }

    @Test func sandboxedInstallerIsEnabled() {
        #expect(info["SUEnableInstallerLauncherService"] as? Bool == true)
    }

    @Test func publicKeyIsAnEd25519Key() throws {
        let key = try #require(info["SUPublicEDKey"] as? String)
        #expect(Data(base64Encoded: key)?.count == 32)
    }
}

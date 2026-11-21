import Foundation
import Testing
@testable import Peasy

@MainActor
struct ClaudeLaunchTests {
    let id = UUID()

    @Test func promptNamesTheTaskAndItsProject() {
        let prompt = ClaudeLaunch.prompt(title: "Fix sync", id: id, project: "Peasy", note: "", link: "")
        #expect(prompt.contains("Fix sync"))
        #expect(prompt.contains(id.uuidString))
        #expect(prompt.contains("Peasy"))
    }

    @Test func promptCarriesNoteAndLink() {
        let prompt = ClaudeLaunch.prompt(title: "Fix sync", id: id, project: nil, note: " Old token \n", link: "https://example.com/pr/1")
        #expect(prompt.contains("Old token"))
        #expect(prompt.contains("https://example.com/pr/1"))
        #expect(!prompt.contains("Old token \n"))
    }

    @Test func longNoteIsCutToTheLimit() {
        let note = String(repeating: "a", count: 20_000)
        let prompt = ClaudeLaunch.prompt(title: "Fix sync", id: id, project: "Peasy", note: note, link: "https://example.com", limit: 1_000)
        #expect(prompt.count <= 1_000)
        #expect(prompt.contains(id.uuidString))
        #expect(prompt.contains("https://example.com"))
        #expect(prompt.hasSuffix("…"))
    }

    @Test func linkKeepsPromptAndFolderIntact() throws {
        let prompt = "Fix A&B #1 + tests = 100% в проекте?"
        let url = try #require(ClaudeLaunch.url(prompt: prompt, folder: "/Users/me/My Repo"))
        #expect(url.scheme == "claude")
        #expect(url.host() == "code")
        #expect(url.path() == "/new")
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(items.count == 2)
        #expect(items.first { $0.name == "q" }?.value == prompt)
        #expect(items.first { $0.name == "folder" }?.value == "/Users/me/My Repo")
        #expect(!url.absoluteString.contains("A&B"))
        #expect(!url.absoluteString.contains("#"))
    }

    @Test func linkWithoutFolderHasOnlyThePrompt() throws {
        let url = try #require(ClaudeLaunch.url(prompt: "Hi", folder: nil))
        #expect(url.absoluteString == "claude://code/new?q=Hi")
        #expect(ClaudeLaunch.url(prompt: "Hi", folder: "")?.absoluteString == "claude://code/new?q=Hi")
    }
}

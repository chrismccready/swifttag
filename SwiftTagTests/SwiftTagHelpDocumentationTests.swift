import Foundation
import Testing
@testable import SwiftTag

struct SwiftTagHelpDocumentationTests {
    @Test
    func indexURLUsesBundledUserDocumentationPath() throws {
        let resourceURL = URL(fileURLWithPath: "/tmp/SwiftTag.app/Contents/Resources", isDirectory: true)

        let indexURL = try #require(SwiftTagHelpDocumentation.indexURL(resourceURL: resourceURL))

        #expect(indexURL.path == "/tmp/SwiftTag.app/Contents/Resources/UserDocumentation/index.html")
    }

    @Test
    func helpMenuLinkURLsUseReleaseAndProjectPages() {
        #expect(
            SwiftTagHelpMenuLinks.releaseNotesURL.absoluteString
                == "https://github.com/chrismccready/swifttag/releases/tag/v1.0.3"
        )
        #expect(SwiftTagHelpMenuLinks.projectURL.absoluteString == "https://github.com/chrismccready/swifttag")
    }

    @Test
    func swiftTagAppSourceDeclaresHelpMenuLinkOrder() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("SwiftTag")
            .appendingPathComponent("SwiftTagApp.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        let helpRange = try #require(source.range(of: "Button(\"SwiftTag Help\")"))
        let releaseRange = try #require(source.range(of: "Button(\"Release Notes\")"))
        let projectRange = try #require(source.range(of: "Button(\"SwiftTag project on GitHub\")"))

        #expect(helpRange.lowerBound < releaseRange.lowerBound)
        #expect(releaseRange.lowerBound < projectRange.lowerBound)
        #expect(source.contains("SwiftTagHelpMenuLinks.open(SwiftTagHelpMenuLinks.releaseNotesURL)"))
        #expect(source.contains("SwiftTagHelpMenuLinks.open(SwiftTagHelpMenuLinks.projectURL)"))
    }
}

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
}

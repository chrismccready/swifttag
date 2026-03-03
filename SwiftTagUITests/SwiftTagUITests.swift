//
//  SwiftTagUITests.swift
//  SwiftTagUITests
//
//  Created by Christopher McCready on 2/24/26.
//

import XCTest

final class SwiftTagUITests: XCTestCase {
    private enum UIID {
        static let addMiscTagButton = "miscTags.addButton"
        static let deleteMiscTagButton = "miscTags.deleteButton"
        static let miscTagTable = "miscTags.table"
        static let miscTagKeyFieldPrefix = "miscTags.keyField."
        static let albumTextField = "albumTextField"
    }

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    @MainActor
    func testMiscTagsAddAndDeleteRow() throws {
        let app = launchApp()

        let initialCount = miscTagKeyFields(in: app).count
        addMiscTagRow(in: app, key: "CUSTOM_ROW_A")
        XCTAssertTrue(waitForMiscTagKeyFieldCount(in: app, toBe: initialCount + 1))
        XCTAssertTrue(miscTagKeyField(in: app, key: "CUSTOM_ROW_A").exists)

        miscTagKeyField(in: app, key: "CUSTOM_ROW_A").tap()
        app.buttons[UIID.deleteMiscTagButton].tap()

        XCTAssertTrue(waitForMiscTagKeyFieldCount(in: app, toBe: initialCount))
        XCTAssertFalse(miscTagKeyField(in: app, key: "CUSTOM_ROW_A").exists)
    }

    @MainActor
    func testMiscTagsNewRowWithExplicitKeyIsRemovedOnBlur() throws {
        let app = launchApp()

        let initialCount = miscTagKeyFields(in: app).count
        addMiscTagRow(in: app, key: "TITLE")
        XCTAssertTrue(waitForMiscTagKeyFieldCount(in: app, toBe: initialCount))
        XCTAssertFalse(miscTagKeyField(in: app, key: "TITLE").exists)
    }

    @MainActor
    func testMiscTagsNewRowWithDuplicateKeyIsRemovedOnBlur() throws {
        let app = launchApp()

        addMiscTagRow(in: app, key: "DUPLICATE_BASE")
        let committedCount = miscTagKeyFields(in: app).count

        addMiscTagRow(in: app, key: "DUPLICATE_BASE")
        XCTAssertTrue(waitForMiscTagKeyFieldCount(in: app, toBe: committedCount))
    }

    @MainActor
    func testMiscTagsExistingRowDuplicateEditRevertsToOriginalKey() throws {
        let app = launchApp()

        addMiscTagRow(in: app, key: "ORIGINAL_KEY")
        XCTAssertTrue(miscTagKeyField(in: app, key: "ORIGINAL_KEY").waitForExistence(timeout: 2.0))
        addMiscTagRow(in: app, key: "OTHER_KEY")
        XCTAssertTrue(miscTagKeyField(in: app, key: "OTHER_KEY").waitForExistence(timeout: 2.0))

        let editedField = miscTagKeyField(in: app, key: "OTHER_KEY")
        XCTAssertTrue(editedField.waitForExistence(timeout: 2.0))
        clearAndType(in: app, element: editedField, text: "ORIGINAL_KEY")
        app.textFields[UIID.albumTextField].tap()

        XCTAssertTrue(miscTagKeyField(in: app, key: "OTHER_KEY").waitForExistence(timeout: 2.0))
        XCTAssertEqual(
            miscTagKeyFields(in: app).matching(NSPredicate(format: "value == %@", "ORIGINAL_KEY")).count,
            1
        )
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons[UIID.addMiscTagButton].waitForExistence(timeout: 2.0))
        XCTAssertTrue(app.textFields[UIID.albumTextField].waitForExistence(timeout: 2.0))
        return app
    }

    private func addMiscTagRow(in app: XCUIApplication, key: String) {
        let countBefore = miscTagKeyFields(in: app).count

        app.buttons[UIID.addMiscTagButton].tap()
        XCTAssertTrue(waitForMiscTagKeyFieldCount(in: app, toBe: countBefore + 1))

        let newField = miscTagKeyFields(in: app).element(boundBy: countBefore)
        XCTAssertTrue(newField.waitForExistence(timeout: 2.0))
        typeIntoNewField(newField, text: key)
        app.textFields[UIID.albumTextField].tap()
    }

    private func typeIntoNewField(_ element: XCUIElement, text: String) {
        element.tap()
        element.typeText(text)
    }

    private func clearAndType(in app: XCUIApplication, element: XCUIElement, text: String) {
        element.tap()
        app.typeKey(XCUIKeyboardKey.return.rawValue, modifierFlags: [])
        app.typeKey("a", modifierFlags: .command)
        app.typeText(text)
    }

    private func miscTagKeyFields(in app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", UIID.miscTagKeyFieldPrefix))
    }

    private func miscTagKeyField(in app: XCUIApplication, key: String) -> XCUIElement {
        miscTagKeyFields(in: app)
            .matching(NSPredicate(format: "value == %@", key))
            .firstMatch
    }

    private func waitForMiscTagKeyFieldCount(
        in app: XCUIApplication,
        toBe expectedCount: Int,
        timeout: TimeInterval = 2.0
    ) -> Bool {
        let query = miscTagKeyFields(in: app)
        let predicate = NSPredicate(format: "count == %d", expectedCount)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: query)

        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}

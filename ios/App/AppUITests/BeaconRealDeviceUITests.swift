import XCTest

final class BeaconRealDeviceUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["--beacon-ui-test"]
        app.launch()
    }

    func testEmergencyHomeChatAndLanguageFlow() throws {
        waitForHome()
        attachScreenshot("01-home")

        // Quick action should enter the conversation without requiring a second tap.
        tapFirstExistingButton(["迷路断联", "Lost/Disconnected", "Lost", "Lost / Offline"])
        waitForConversation()
        attachScreenshot("02-after-quick-action")
        returnHomeIfPossible()
        waitForHome()

        // Free-form user input must stay available and the Send button must not mutate into navigation.
        let input = firstExistingTextInput()
        XCTAssertTrue(input.waitForExistence(timeout: 10), "Home input field should be visible and tappable")
        input.tap()
        input.typeText("我在森林里迷路了，手机还有20%电")
        attachScreenshot("03-typed-user-message")
        tapFirstExistingButton(["发送", "Send"])
        waitForConversation()
        attachScreenshot("04-after-send")
        XCTAssertTrue(app.buttons["发送"].exists || app.buttons["Send"].exists, "Send button should remain a send action while generating")
        returnHomeIfPossible()
        waitForHome()

        // Language switcher should be reachable and visibly localize the main home copy.
        tapFirstExistingButton([
            "语言选择",
            "语言选择 简体中文",
            "语言选择: 简体中文",
            "简体中文",
            "Language selection",
            "Language selection English",
            "Language selection: English",
            "English"
        ])
        attachScreenshot("05-language-panel")
        tapFirstElementContaining(["English", "英语"])
        XCTAssertTrue(
            app.staticTexts["Survive first, think later."].waitForExistence(timeout: 8)
                || app.staticTexts["Survive first. Think later."].exists
                || app.buttons["Lost/Disconnected"].exists,
            "Switching to English should update the home copy"
        )
        attachScreenshot("06-english-home")
    }

    func testVisualEntryOpensLocalizedPicker() throws {
        waitForHome()
        tapFirstExistingButton(["视觉求助 / 拍摄创口", "Visual Help / Scan Wound", "Visual Help / Wound Photo", "Visual Help"])
        let cameraButton = app.buttons["拍照"]
        let legacyCameraButton = app.buttons["拍摄"]
        let albumButton = app.buttons["从相册选择"]
        let legacyAlbumButton = app.buttons["从相册导入"]
        let englishCamera = app.buttons["Take Photo"]
        let englishAlbum = app.buttons["Choose from Photos"]
        XCTAssertTrue(
            cameraButton.waitForExistence(timeout: 8)
                || legacyCameraButton.exists
                || albumButton.exists
                || legacyAlbumButton.exists
                || englishCamera.exists
                || englishAlbum.exists,
            "Visual entry should open a camera/photo choice instead of a dead screen"
        )
        attachScreenshot("07-visual-picker")
    }

    func testLeadingEdgeSwipeReturnsHomeFromConversation() throws {
        waitForHome()
        tapFirstExistingButton(["迷路断联", "Lost/Disconnected", "Lost", "Lost / Offline"])
        waitForConversation()
        performLeadingEdgeSwipeBack()
        waitForHome()
        attachScreenshot("08-after-edge-swipe-back")
    }

    private func waitForHome(file: StaticString = #filePath, line: UInt = #line) {
        let labels = [
            "先活下来，再想别的。",
            "Survive first, think later.",
            "Survive first. Think later.",
            "迷路断联",
            "Lost/Disconnected"
        ]
        let predicate = NSPredicate(format: "label IN %@", labels)
        let homeElement = app.descendants(matching: .any).matching(predicate).firstMatch
        XCTAssertTrue(
            homeElement.waitForExistence(timeout: 25),
            "Home screen should be visible",
            file: file,
            line: line
        )
    }

    private func waitForConversation(file: StaticString = #filePath, line: UInt = #line) {
        let labels = ["返回主页", "Return Home", "Beacon"]
        let predicate = NSPredicate(format: "label IN %@", labels)
        let conversationElement = app.descendants(matching: .any).matching(predicate).firstMatch
        XCTAssertTrue(
            conversationElement.waitForExistence(timeout: 12),
            "Conversation screen should be visible after starting a request",
            file: file,
            line: line
        )
    }

    private func returnHomeIfPossible() {
        if app.buttons["返回主页"].exists {
            app.buttons["返回主页"].tap()
        } else if app.buttons["Return Home"].exists {
            app.buttons["Return Home"].tap()
        } else if app.buttons["‹"].exists {
            app.buttons["‹"].tap()
        } else {
            app.swipeRight()
        }
    }

    private func performLeadingEdgeSwipeBack() {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.52))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.72, dy: 0.52))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    private func firstExistingTextInput() -> XCUIElement {
        let placeholders = [
            "输入你现在的情况......",
            "Describe your current situation...",
            "Describe what is happening...",
            "Tell Beacon what is happening..."
        ]
        for placeholder in placeholders {
            let field = app.textFields[placeholder]
            if field.exists { return field }
            let textView = app.textViews[placeholder]
            if textView.exists { return textView }
        }
        if app.textFields.count > 0 { return app.textFields.firstMatch }
        return app.textViews.firstMatch
    }

    private func tapFirstExistingButton(_ labels: [String], file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "label IN %@", labels)
        let element = app.descendants(matching: .any).matching(predicate).firstMatch
        if element.waitForExistence(timeout: 4) {
            element.tap()
            return
        }

        for label in labels {
            let button = app.buttons[label]
            if button.exists {
                button.tap()
                return
            }
            let staticText = app.staticTexts[label]
            if staticText.exists {
                staticText.tap()
                return
            }
            let otherElement = app.otherElements[label]
            if otherElement.exists {
                otherElement.tap()
                return
            }
        }
        XCTFail("Expected one of buttons/texts/other elements to exist: \(labels)", file: file, line: line)
    }

    private func tapFirstElementContaining(_ fragments: [String], file: StaticString = #filePath, line: UInt = #line) {
        for fragment in fragments {
            let predicate = NSPredicate(format: "label CONTAINS %@", fragment)
            let element = app.descendants(matching: .any).matching(predicate).firstMatch
            if element.waitForExistence(timeout: 2) {
                element.tap()
                return
            }
        }
        XCTFail("Expected an element containing one of labels: \(fragments)", file: file, line: line)
    }

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

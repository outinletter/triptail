import XCTest

final class TripTailUITests: XCTestCase {
    @MainActor func testSampleSaveReopenAndDelete() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["sample"].tap()
        XCTAssertTrue(app.navigationBars["여행 글 편집"].waitForExistence(timeout: 5))
        let proof = XCTAttachment(screenshot: app.screenshot())
        proof.name = "TripTail sample editor"
        proof.lifetime = .keepAlways
        add(proof)
        app.buttons["기기에 저장"].tap()
        app.alerts.buttons["확인"].tap()
        app.buttons["닫기"].tap()
        app.terminate()
        app.launch()
        app.tabBars.buttons["여행 보관함"].tap()
        let entry = app.buttons.containing(.staticText, identifier: "교토의 오후 · 예시").firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 5))
        entry.tap()
        XCTAssertTrue(app.textViews["여행 글 본문"].exists)
        app.buttons["닫기"].tap()
        entry.swipeLeft()
        let delete = app.buttons["Delete"].firstMatch
        if delete.exists { delete.tap() } else { app.buttons["삭제"].firstMatch.tap() }
        app.buttons["삭제"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["아직 저장한 여행이 없어요"].waitForExistence(timeout: 5))
    }
    @MainActor func testSampleUnsavedCloseRequiresConfirmation() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["sample"].tap()
        app.buttons["닫기"].tap()
        XCTAssertTrue(app.buttons["저장하지 않고 닫기"].waitForExistence(timeout: 3))
        app.buttons["저장하지 않고 닫기"].tap()
        XCTAssertTrue(app.buttons["sample"].exists)
    }
    @MainActor func testPrivacyAndAIUnavailableWithoutPhotos() throws {
        let app = XCUIApplication()
        app.launch()
        app.swipeUp()
        XCTAssertFalse(app.buttons["AI로 사진 분석·글쓰기"].isEnabled)
        app.tabBars.buttons["안내"].tap()
        XCTAssertTrue(app.navigationBars["안내 및 개인정보"].exists)
        app.swipeUp()
        app.swipeUp()
        XCTAssertTrue(app.links["이메일 지원 · 개인정보 삭제 요청"].exists || app.buttons["이메일 지원 · 개인정보 삭제 요청"].exists)
    }
}

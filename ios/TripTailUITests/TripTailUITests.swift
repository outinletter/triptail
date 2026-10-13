import XCTest

final class TripTailUITests: XCTestCase {
    @MainActor func testReviewWalkthrough() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launch()
        func capture(_ name: String) {
            let image = XCTAttachment(screenshot: app.screenshot())
            image.name = name
            image.lifetime = .keepAlways
            add(image)
        }
        XCTAssertTrue(app.buttons["sample"].waitForExistence(timeout: 5))
        capture("01-create-travel")
        app.buttons["sample"].tap()
        XCTAssertTrue(app.navigationBars["여행 글 편집"].waitForExistence(timeout: 5))
        if !app.buttons["기기에 저장"].waitForExistence(timeout: 5) { app.swipeUp() }
        XCTAssertTrue(app.buttons["기기에 저장"].waitForExistence(timeout: 5))
        capture("02-edit-story")
        app.buttons["기기에 저장"].tap()
        XCTAssertTrue(app.alerts.buttons["확인"].waitForExistence(timeout: 3))
        app.alerts.buttons["확인"].tap()
        capture("03-saved-story")
        app.buttons["닫기"].tap()
        app.tabBars.buttons["안내"].tap()
        capture("04-privacy-guide")
        app.swipeUp()
        capture("05-privacy-policy")
    }
    @MainActor func testSwipeDeleteSavedStory() throws {
        let app = XCUIApplication(); app.launch()
        app.buttons["sample"].tap()
        // The sample is saved first; the top library row is the latest saved item.
        if !app.buttons["기기에 저장"].isHittable { app.swipeUp() }
        app.buttons["기기에 저장"].tap()
        XCTAssertTrue(app.alerts.buttons["확인"].waitForExistence(timeout: 3))
        app.alerts.buttons["확인"].tap(); app.buttons["닫기"].tap()
        app.tabBars.buttons["여행 보관함"].tap()
        let row = app.cells.firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        row.swipeLeft()
        let delete = app.buttons["삭제"]
        XCTAssertTrue(delete.waitForExistence(timeout: 3)); delete.tap()
        XCTAssertFalse(app.sheets.firstMatch.exists)
    }
    @MainActor func testMapPreview() throws {
        let app = XCUIApplication(); app.launchArguments = ["--map-preview-test"]; app.launch()
        XCTAssertTrue(app.maps.firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Google 지도 열기"].exists)
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "Location map preview"; capture.lifetime = .keepAlways; add(capture)
        app.buttons["완료"].tap()
    }
    @MainActor func testAutomaticComposerHasNoManualTravelSection() throws {
        let app = XCUIApplication()
        app.launch()
        app.swipeUp()
        XCTAssertFalse(app.buttons["기기 내 초안 만들기"].exists)
        XCTAssertFalse(app.buttons["Google Vision으로 장소 확인"].exists)
        XCTAssertFalse(app.textFields["여행지 (모르면 비워두세요)"].exists)
        XCTAssertFalse(app.datePickers.firstMatch.exists)
        XCTAssertTrue(app.buttons["AI로 사진 분석·글쓰기"].exists)
        XCTAssertFalse(app.buttons["AI로 사진 분석·글쓰기"].isEnabled)
    }
    @MainActor func testPlaceAndSubjectMustBeConfirmed() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--verification-test"]
        app.launch()
        let write = app.buttons["확인 완료 · 블로그 작성"]
        XCTAssertTrue(write.waitForExistence(timeout: 5))
        XCTAssertFalse(write.isEnabled)
        for _ in 0..<4 { if app.textFields["정확한 장소명 또는 주소 검색"].isHittable { break }; app.swipeUp() }
        app.textFields["정확한 장소명 또는 주소 검색"].tap()
        app.textFields["정확한 장소명 또는 주소 검색"].typeText("Segovia")
        if !app.buttons["입력한 장소명으로 선택"].isHittable { app.swipeUp() }
        app.buttons["입력한 장소명으로 선택"].tap()
        XCTAssertFalse(write.isEnabled)
        let subject = app.textFields["사진 속 사물·건축물·풍경의 이름"]
        if !subject.isHittable { app.swipeUp() }
        subject.tap(); subject.typeText("Aqueduct")
        if app.buttons["입력 완료"].firstMatch.waitForExistence(timeout: 2) { app.buttons["입력 완료"].firstMatch.tap() }
        XCTAssertFalse(write.isEnabled)
        let confirm = app.switches["이 장소와 촬영 대상이 맞습니다"]
        if !confirm.isHittable { app.swipeUp() }
        confirm.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertTrue(write.isEnabled)
        XCTAssertTrue(app.buttons["Google 지도에서 위치 확인"].exists)
        let proof = XCTAttachment(screenshot: app.screenshot())
        proof.name = "TripTail verified photo location and subject"
        proof.lifetime = .keepAlways
        add(proof)
    }
    @MainActor func testStyledBlogPreview() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["sample"].tap()
        XCTAssertTrue(app.navigationBars["여행 글 편집"].waitForExistence(timeout: 5))
        if !app.buttons["꾸며진 블로그 미리보기"].isHittable { app.swipeUp() }
        app.buttons["꾸며진 블로그 미리보기"].tap()
        XCTAssertTrue(app.navigationBars["여행 블로그"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.webViews.staticTexts["서울 · 경복궁과 북촌 소개 · 예시"].waitForExistence(timeout: 5))
        let proof = XCTAttachment(screenshot: app.screenshot())
        proof.name = "TripTail styled blog preview"
        proof.lifetime = .keepAlways
        add(proof)
        app.buttons["글 편집"].tap()
        XCTAssertTrue(app.navigationBars["여행 글 편집"].waitForExistence(timeout: 5))
    }
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
        let entry = app.buttons.containing(.staticText, identifier: "서울 · 경복궁과 북촌 소개 · 예시").firstMatch
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

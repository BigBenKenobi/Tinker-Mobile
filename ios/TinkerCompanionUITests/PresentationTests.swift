// Simulator acceptance of the isolated presentation shell. Each test owns a new
// temporary SQLite store and never loads Keychain, networking or notifications.
// Screenshots are XCTest attachments; their existence is not visual acceptance.
import XCTest
import UIKit

@MainActor final class PresentationTests: XCTestCase {
    /// Launch a fresh isolated session, fail fast, and retain evidence on failure.
    private func launch(fixture: String = "empty", largeText: Bool = false) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launchEnvironment["TINKER_TEST_RUN"] = UUID().uuidString
        app.launchEnvironment["TINKER_TEST_FIXTURE"] = fixture
        if largeText { app.launchArguments += ["-UIPreferredContentSizeCategoryName","UICTContentSizeCategoryAccessibilityXXXL"] }
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        return app
    }
    /// Scroll the drawer until a destination is actually hittable at large text.
    private func navigate(_ route: String, in app: XCUIApplication) {
        app.buttons["shell.tools"].tap()
        let drawer = app.scrollViews["shell.drawer"]
        XCTAssertTrue(drawer.waitForExistence(timeout:5),"The tools drawer must open")
        let button = app.buttons["route." + route]
        for _ in 0..<10 where !button.isHittable { drawer.swipeUp() }
        if !button.isHittable {
            print("TINKER_UI_HIERARCHY_BEGIN")
            print(app.debugDescription)
            print("TINKER_UI_HIERARCHY_END")
        }
        XCTAssertTrue(button.isHittable,"Unreachable destination: " + route)
        button.tap()
        let title = ["new_chat":"Tinker","search":"Search","email":"Email","tools":"Tools","brain":"Brain","calendar":"Calendar","compare":"Model Compare","cookbook":"Cookbook","research":"Deep Research","gallery":"Gallery","library":"Library","notes":"Notes","tasks":"Tasks","companion":"Companion","theme":"Theme","settings":"Settings","account":"Account","model_selector":"Models"][route]!
        let arrived = app.navigationBars[title].waitForExistence(timeout:5)
        if !arrived { print("TINKER_UI_HIERARCHY_BEGIN"); print(app.debugDescription); print("TINKER_UI_HIERARCHY_END") }
        XCTAssertTrue(arrived,"Expected destination: " + title)
    }
    /// A composer draft must survive destination changes without a domain write.
    func testComposerSurvivesNavigation() {
        let app = launch()
        let composer = app.textViews["home.composer"]
        XCTAssertTrue(composer.waitForExistence(timeout:10))
        composer.tap(); composer.typeText("Temporary acceptance draft")
        navigate("notes",in:app)
        XCTAssertTrue(app.navigationBars["Notes"].waitForExistence(timeout:5))
        navigate("new_chat",in:app)
        XCTAssertEqual(composer.value as? String,"Temporary acceptance draft")
        let attachment = XCTAttachment(screenshot:app.screenshot())
        attachment.name = "Home-retained-draft"; attachment.lifetime = .keepAlways
        add(attachment)
    }
    /// All canonical destinations must be reachable and produce screenshot evidence.
    func testDestinationScreenshots() {
        let app = launch()
        for route in ["new_chat","search","email","tools","brain","calendar","compare","cookbook","research","gallery","library","notes","tasks","companion","theme","settings","account","model_selector"] {
            navigate(route,in:app)
            for orientation in [UIDeviceOrientation.portrait,.landscapeLeft] {
                XCUIDevice.shared.orientation = orientation
                let attachment = XCTAttachment(screenshot:app.screenshot())
                attachment.name = "Destination-" + route + (orientation == .portrait ? "-portrait" : "-landscape")
                attachment.lifetime = .keepAlways; add(attachment)
            }
            XCUIDevice.shared.orientation = .portrait
        }
    }
    /// Populated/error screenshots are labelled fixtures, never ordinary empty states.
    func testPopulatedAndErrorFixturesWithLargeText() {
        for fixture in ["populated","error"] {
            let app = launch(fixture:fixture,largeText:true)
            XCTAssertTrue(app.buttons["shell.tools"].waitForExistence(timeout:10))
            navigate("notes",in:app)
            if fixture == "populated" {
                let note = app.buttons["Preview note"]
                for _ in 0..<8 where !note.isHittable { app.swipeUp() }
                XCTAssertTrue(note.isHittable,"Populated note must remain reachable at large text")
            }
            let attachment = XCTAttachment(screenshot:app.screenshot())
            attachment.name = fixture + "-Notes-accessibility-XXXL"; attachment.lifetime = .keepAlways; add(attachment)
            app.terminate()
        }
    }
    /// The same disposable store restores routing while process drafts clear.
    func testRestartRestoresRouteAndClearsComposer() {
        let app = launch()
        let composer = app.textViews["home.composer"]
        XCTAssertTrue(composer.waitForExistence(timeout:10)); composer.tap(); composer.typeText("Session draft")
        navigate("tasks",in:app)
        app.terminate(); app.launch()
        XCTAssertTrue(app.navigationBars["Tasks"].waitForExistence(timeout:10))
        navigate("new_chat",in:app)
        XCTAssertEqual(app.textViews["home.composer"].value as? String,"")
    }
}

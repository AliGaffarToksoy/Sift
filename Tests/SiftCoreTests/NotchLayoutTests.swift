import CoreGraphics
import XCTest
@testable import SiftCore

final class NotchLayoutTests: XCTestCase {
    func testHoverTargetIncludesCameraAndItsLowerEdge() {
        let screen = CGRect(x: -1512, y: 100, width: 1512, height: 982)
        let camera = CGRect(x: -870, y: 1050, width: 180, height: 32)
        let target = NotchLayout.activationFrame(screen: screen, visible: screen, topInset: 32, camera: camera)
        XCTAssertTrue(target.contains(CGPoint(x: camera.midX, y: camera.midY)))
        XCTAssertTrue(target.contains(CGPoint(x: camera.midX, y: camera.minY - 4)))
        XCTAssertFalse(target.contains(CGPoint(x: screen.minX + 40, y: screen.maxY - 4)))
        XCTAssertEqual(target.maxY, screen.maxY)
    }
    func testExternalHoverTargetIgnoresAnotherDisplaysCamera() {
        let screen = CGRect(x: 1512, y: 0, width: 1920, height: 1080)
        let visible = CGRect(x: 1512, y: 0, width: 1920, height: 1055)
        let target = NotchLayout.activationFrame(screen: screen, visible: visible, topInset: 0,
            camera: CGRect(x: 0, y: 0, width: 180, height: 32))
        XCTAssertEqual(target.midX, screen.midX)
        XCTAssertEqual(target.maxY, visible.maxY)
    }

    func testHardwarePanelIsAnchoredToCameraAndScreenTop() {
        let screen = CGRect(x: -1512, y: 100, width: 1512, height: 982)
        let visible = CGRect(x: -1512, y: 100, width: 1512, height: 950)
        let camera = CGRect(x: -870, y: 1050, width: 180, height: 32)
        let frame = NotchLayout.frame(screen: screen, visible: visible, topInset: 32, camera: camera, expanded: false, additionalMessages: 0, preview: false)
        XCTAssertEqual(frame.maxY, screen.maxY)
        XCTAssertEqual(frame.midX, camera.midX)
        XCTAssertEqual(frame.height, 174)
    }
    func testExternalScreenIgnoresStaleCameraAndRespectsMenuBar() {
        let screen = CGRect(x: 1512, y: 0, width: 1920, height: 1080)
        let visible = CGRect(x: 1512, y: 0, width: 1920, height: 1055)
        let frame = NotchLayout.frame(screen: screen, visible: visible, topInset: 0, camera: CGRect(x: 0, y: 0, width: 900, height: 32), expanded: false, additionalMessages: 0, preview: false)
        XCTAssertEqual(frame.width, 460)
        XCTAssertEqual(frame.midX, screen.midX)
        XCTAssertEqual(frame.maxY, visible.maxY - 8)
    }
    func testExpandedHeightTracksVisibleRowsAndCapsBurst() {
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        func frame(_ count: Int) -> CGRect {
            NotchLayout.frame(screen: screen, visible: screen, topInset: 32, camera: nil, expanded: true, additionalMessages: count, preview: false)
        }
        XCTAssertEqual(frame(3).height - frame(0).height, 84)
        XCTAssertEqual(frame(500), frame(3))
        XCTAssertEqual(frame(-1), frame(0))
    }
    func testPanelFitsSmallDisplay() {
        let screen = CGRect(x: 200, y: -500, width: 400, height: 300)
        let frame = NotchLayout.frame(screen: screen, visible: screen, topInset: 0, camera: nil, expanded: true, additionalMessages: 3, preview: true)
        XCTAssertGreaterThanOrEqual(frame.minX, screen.minX)
        XCTAssertLessThanOrEqual(frame.maxX, screen.maxX)
        XCTAssertGreaterThanOrEqual(frame.minY, screen.minY)
        XCTAssertLessThan(frame.maxY, screen.maxY)
    }
}

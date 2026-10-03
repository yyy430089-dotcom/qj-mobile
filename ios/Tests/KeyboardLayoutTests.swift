// 用实际 UIKit 键盘和真实词库生成布局截图；不代替跨应用真机输入测试。
import XCTest
import UIKit

@MainActor
final class KeyboardLayoutTests: XCTestCase {
    private func descendants(_ view: UIView) -> [UIView] {
        view.subviews.flatMap { [$0] + descendants($0) }
    }

    private func checkLayout(width: CGFloat, height: CGFloat, style: UIUserInterfaceStyle, name: String) throws {
        let controller = KeyboardViewController(nibName: nil, bundle: Bundle(for: Self.self))
        // 动态颜色需要真实的窗口 trait 环境；离屏控制器会沿用浅色。
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: height))
        window.overrideUserInterfaceStyle = style
        window.rootViewController = controller
        controller.loadViewIfNeeded()
        controller.overrideUserInterfaceStyle = style
        controller.view.traitOverrides.userInterfaceStyle = style
        window.isHidden = false
        controller.view.frame = CGRect(x: 0, y: 0, width: width, height: height)
        controller.beginAppearanceTransition(true, animated: false)
        controller.endAppearanceTransition()
        controller.view.layoutIfNeeded()
        XCTAssertEqual(controller.view.traitCollection.userInterfaceStyle, style)
        let background = try XCTUnwrap(controller.view.layer.backgroundColor)
        var brightness: CGFloat = 0
        UIColor(cgColor: background).getWhite(&brightness, alpha: nil)
        if style == .dark { XCTAssertLessThan(brightness, 0.3) }
        else { XCTAssertGreaterThan(brightness, 0.7) }
        for letter in "kaifa" {
            let key = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? KeyButton }
                .first { $0.title(for: .normal) == String(letter) })
            key.action?()
        }
        let loaded = expectation(description: "Keyboard candidates drawn")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { loaded.fulfill() }
        wait(for: [loaded], timeout: 5)
        controller.view.layoutIfNeeded()
        XCTAssertTrue(descendants(controller.view).compactMap { $0 as? UILabel }.contains { $0.text == "开发" })
        let keys = descendants(controller.view).compactMap { $0 as? KeyButton }
        XCTAssertGreaterThanOrEqual(keys.count, 30)
        for key in keys {
            XCTAssertGreaterThanOrEqual(key.bounds.width, 25)
            XCTAssertGreaterThanOrEqual(key.bounds.height, 25)
            let rectangle = key.convert(key.bounds, to: controller.view)
            XCTAssertGreaterThanOrEqual(rectangle.minX, -0.5)
            XCTAssertLessThanOrEqual(rectangle.maxX, width + 0.5)
            XCTAssertLessThanOrEqual(rectangle.maxY, height + 0.5)
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let image = UIGraphicsImageRenderer(bounds: controller.view.bounds, format: format).image {
            controller.view.layer.render(in: $0.cgContext)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        controller.beginAppearanceTransition(false, animated: false)
        controller.endAppearanceTransition()
        window.isHidden = true
    }

    func testPortraitLight() throws { try checkLayout(width: 393, height: 304, style: .light, name: "keyboard-portrait-light") }
    func testPortraitDark() throws { try checkLayout(width: 393, height: 304, style: .dark, name: "keyboard-portrait-dark") }
    func testLandscapeLight() throws { try checkLayout(width: 852, height: 250, style: .light, name: "keyboard-landscape-light") }
}

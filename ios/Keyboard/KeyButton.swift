// 原生按键，提供触摸反馈与可访问性标签。
import UIKit

final class KeyButton: UIButton {
    var action: (() -> Void)?
    let functional: Bool

    init(_ title: String, functional: Bool = false) {
        self.functional = functional
        super.init(frame: .zero)
        setTitle(title, for: .normal)
        titleLabel?.font = .systemFont(ofSize: functional ? 16 : 23, weight: .regular)
        setTitleColor(.label, for: .normal)
        backgroundColor = functional ? .tertiarySystemFill : .secondarySystemGroupedBackground
        layer.cornerRadius = 6
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.12
        layer.shadowRadius = 0
        layer.shadowOffset = CGSize(width: 0, height: 1)
        addTarget(self, action: #selector(fire), for: .touchUpInside)
        accessibilityLabel = title
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc private func fire() { action?() }
    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.55 : 1.0 }
    }
}

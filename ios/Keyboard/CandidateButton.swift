// 中文为主体，英文作为较小的单行辅助信息；点击只提交中文。
import UIKit

final class CandidateButton: UIControl {
    var action: (() -> Void)?
    private let word = UILabel()
    private let annotation = UILabel()

    init(candidate: EngineFrame.Candidate, showTranslation: Bool) {
        super.init(frame: .zero)
        word.text = candidate.text
        word.font = .systemFont(ofSize: 20, weight: .medium)
        word.textColor = .label
        annotation.text = showTranslation ? candidate.annotation : nil
        annotation.font = .systemFont(ofSize: 11)
        annotation.textColor = .secondaryLabel
        annotation.lineBreakMode = .byTruncatingTail
        word.isUserInteractionEnabled = false
        annotation.isUserInteractionEnabled = false
        addSubview(word)
        addSubview(annotation)
        word.translatesAutoresizingMaskIntoConstraints = false
        annotation.translatesAutoresizingMaskIntoConstraints = false
        let textWidth = (candidate.text as NSString).size(withAttributes: [.font: word.font!]).width
        let glossWidth = ((annotation.text ?? "") as NSString).size(withAttributes: [.font: annotation.font!]).width
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: min(180, max(54, max(textWidth, glossWidth) + 22))),
            word.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            word.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -10),
            word.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            annotation.leadingAnchor.constraint(equalTo: word.leadingAnchor),
            annotation.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            annotation.topAnchor.constraint(equalTo: word.bottomAnchor, constant: 1)
        ])
        addTarget(self, action: #selector(fire), for: .touchUpInside)
        isAccessibilityElement = true
        accessibilityLabel = [candidate.text, annotation.text].compactMap { $0 }.joined(separator: ", ")
        accessibilityTraits = .button
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc private func fire() { action?() }
    override var isHighlighted: Bool {
        didSet { backgroundColor = isHighlighted ? .tertiarySystemFill : .clear }
    }
}

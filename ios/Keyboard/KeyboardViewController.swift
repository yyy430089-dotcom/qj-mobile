// iPhone 键盘扩展：原生布局和系统文本代理，不请求网络或完全访问。
import UIKit

final class KeyboardViewController: UIInputViewController {
    private let engine: EngineClient
    private let vertical = UIStackView()
    private let toolbar = UIStackView()
    private let preedit = UILabel()
    private let language = UIButton(type: .system)
    private let translation = UIButton(type: .system)
    private let scroll = UIScrollView()
    private let candidateStack = UIStackView()
    private let hint = UILabel()
    private let keyArea = UIStackView()
    private var heightConstraint: NSLayoutConstraint!
    private var frame: EngineFrame?
    private var numbers = false
    private var symbols = false
    private var shifted = false
    private var capsLock = false
    private var lastShiftTap: TimeInterval = 0
    private var showTranslation = !UserDefaults.standard.bool(forKey: "hideEnglishGloss")
    private var sequence: UInt64 = 0
    private var documentEpoch: UInt64 = 0
    private var visible = false
    private var writing = false
    private var expectedContext: String?
    private var expectedAfter: String?
    private var hasExpectedContext = false
    private var deleteTimer: Timer?
    private var cancelButton = UIButton(type: .system)
    private var engineFailed = false
    private var returnButton: KeyButton?

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        engine = EngineClient(resourceBundle: nibBundleOrNil ?? .main)
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    required init?(coder: NSCoder) {
        engine = EngineClient()
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        vertical.axis = .vertical
        vertical.spacing = 6
        view.addSubview(vertical)
        vertical.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            vertical.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
            vertical.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4),
            vertical.topAnchor.constraint(equalTo: view.topAnchor, constant: 5),
            vertical.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -5)
        ])
        heightConstraint = view.heightAnchor.constraint(equalToConstant: 304)
        heightConstraint.priority = .init(999)
        heightConstraint.isActive = true
        setupToolbar()
        setupCandidates()
        keyArea.axis = .vertical
        keyArea.spacing = 6
        vertical.addArrangedSubview(keyArea)
        rebuildKeys()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        visible = true
        rememberContext()
        send(["action": "reset"])
        rebuildKeys()
    }

    override func viewWillDisappear(_ animated: Bool) {
        visible = false
        documentEpoch += 1
        sequence += 1
        stopDeleting()
        engine.perform(["action": "reset"]) { _ in }
        super.viewWillDisappear(animated)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let landscape = view.bounds.width > 600
        let target: CGFloat = landscape ? 250 : 304
        if heightConstraint.constant != target { heightConstraint.constant = target }
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        guard visible, !writing else { return }
        // 应用主动移动光标、替换选区或更换输入框时，抛弃旧输入会话。
        if hasExpectedContext &&
            (textDocumentProxy.documentContextBeforeInput != expectedContext ||
             textDocumentProxy.documentContextAfterInput != expectedAfter) {
            documentEpoch += 1
            send(["action": "reset"])
        }
        rememberContext()
        updateReturnTitle()
    }

    private func rememberContext() {
        expectedContext = textDocumentProxy.documentContextBeforeInput
        expectedAfter = textDocumentProxy.documentContextAfterInput
        hasExpectedContext = true
    }

    private func setupToolbar() {
        toolbar.axis = .horizontal
        toolbar.spacing = 8
        preedit.font = .systemFont(ofSize: 14, weight: .medium)
        preedit.textColor = .label
        preedit.lineBreakMode = .byTruncatingHead
        preedit.setContentHuggingPriority(.defaultLow, for: .horizontal)
        language.setTitle("中 / EN", for: .normal)
        language.accessibilityLabel = "切换中英文"
        language.addTarget(self, action: #selector(toggleLanguage), for: .touchUpInside)
        translation.setTitle(showTranslation ? "译词 ✓" : "译词", for: .normal)
        translation.addTarget(self, action: #selector(toggleTranslation), for: .touchUpInside)
        cancelButton.setTitle("取消", for: .normal)
        cancelButton.addTarget(self, action: #selector(cancelComposition), for: .touchUpInside)
        for item in [preedit, cancelButton, translation, language] { toolbar.addArrangedSubview(item) }
        toolbar.heightAnchor.constraint(equalToConstant: 27).isActive = true
        vertical.addArrangedSubview(toolbar)
    }

    private func setupCandidates() {
        scroll.showsHorizontalScrollIndicator = false
        scroll.alwaysBounceHorizontal = true
        scroll.delaysContentTouches = false
        candidateStack.axis = .horizontal
        candidateStack.spacing = 0
        scroll.addSubview(candidateStack)
        candidateStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            candidateStack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            candidateStack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            candidateStack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            candidateStack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            candidateStack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor)
        ])
        scroll.heightAnchor.constraint(equalToConstant: 53).isActive = true
        hint.font = .systemFont(ofSize: 13)
        hint.textColor = .secondaryLabel
        hint.text = "输入拼音，顺便认识一个英文词"
        scroll.addSubview(hint)
        hint.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hint.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 12),
            hint.centerYAnchor.constraint(equalTo: scroll.frameLayoutGuide.centerYAnchor)
        ])
        vertical.addArrangedSubview(scroll)
    }

    private func rebuildKeys() {
        stopDeleting()
        keyArea.arrangedSubviews.forEach { keyArea.removeArrangedSubview($0); $0.removeFromSuperview() }
        keyArea.distribution = .fillEqually
        let rows: [[String]]
        if numbers {
            rows = symbols ? [Array("[]{}#%^*+=" ).map(String.init), Array("_\\|~<>€£¥•").map(String.init), ["123", ".", ",", "?", "!", "'", "⌫"]] :
                [Array("1234567890").map(String.init), Array("-/:;()$&@\"").map(String.init), ["#+=", ".", ",", "?", "!", "'", "⌫"]]
        } else {
            let upper = shifted || capsLock
            rows = [(upper ? "QWERTYUIOP" : "qwertyuiop").map { String($0) },
                    (upper ? "ASDFGHJKL" : "asdfghjkl").map { String($0) },
                    ["⇧"] + (upper ? "ZXCVBNM" : "zxcvbnm").map { String($0) } + ["⌫"]]
        }
        for (index, titles) in rows.enumerated() {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 5
            row.distribution = .fillEqually
            if index == 1 && !numbers { row.layoutMargins = UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14); row.isLayoutMarginsRelativeArrangement = true }
            for title in titles {
                let function = ["⇧", "⌫", "#+=", "123"].contains(title)
                let key = KeyButton(title, functional: function)
                key.action = { [weak self] in self?.tap(title) }
                if title == "⌫" {
                    key.accessibilityLabel = "删除"
                    key.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(longDelete(_:))))
                }
                if title == "⇧" { key.accessibilityLabel = capsLock ? "大写锁定" : "大写" }
                row.addArrangedSubview(key)
            }
            keyArea.addArrangedSubview(row)
        }
        let bottom = UIStackView()
        bottom.axis = .horizontal
        bottom.spacing = 5
        let mode = KeyButton(numbers ? "ABC" : "123", functional: true)
        mode.action = { [weak self] in self?.numbers.toggle(); self?.symbols = false; self?.rebuildKeys() }
        bottom.addArrangedSubview(mode)
        mode.widthAnchor.constraint(equalTo: bottom.widthAnchor, multiplier: 0.15).isActive = true
        if needsInputModeSwitchKey {
            let globe = KeyButton("🌐", functional: true)
            globe.accessibilityLabel = "切换输入法"
            // 用系统方法处理触摸，以支持按住地球键选择其他键盘。
            globe.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
            bottom.addArrangedSubview(globe)
            globe.widthAnchor.constraint(equalTo: bottom.widthAnchor, multiplier: 0.12).isActive = true
        }
        let comma = KeyButton(frame?.english == true ? "," : "，", functional: true)
        comma.action = { [weak self] in self?.send(["action": "input", "text": ","]) }
        bottom.addArrangedSubview(comma)
        comma.widthAnchor.constraint(equalTo: bottom.widthAnchor, multiplier: 0.1).isActive = true
        let space = KeyButton("空格", functional: true)
        space.action = { [weak self] in self?.send(["action": "space"]) }
        bottom.addArrangedSubview(space)
        let enter = KeyButton("换行", functional: true)
        enter.action = { [weak self] in self?.send(["action": "enter"]) }
        enter.backgroundColor = .systemBlue
        enter.setTitleColor(.white, for: .normal)
        bottom.addArrangedSubview(enter)
        enter.widthAnchor.constraint(equalTo: bottom.widthAnchor, multiplier: 0.2).isActive = true
        returnButton = enter
        keyArea.addArrangedSubview(bottom)
        updateReturnTitle()
    }

    private func tap(_ key: String) {
        switch key {
        case "⌫": send(["action": "backspace"])
        case "⇧":
            let now = Date.timeIntervalSinceReferenceDate
            if now - lastShiftTap < 0.35 { capsLock.toggle(); shifted = false }
            else { if capsLock { capsLock = false }; shifted.toggle() }
            lastShiftTap = now
            rebuildKeys()
        case "#+=", "123": symbols.toggle(); rebuildKeys()
        default:
            send(["action": "input", "text": key])
            if shifted && !capsLock { shifted = false; rebuildKeys() }
        }
    }

    private func updateReturnTitle() {
        let title: String
        switch textDocumentProxy.returnKeyType ?? .default {
        case .search: title = "搜索"
        case .send: title = "发送"
        case .go: title = "前往"
        case .done: title = "完成"
        case .next: title = "下一项"
        default: title = "换行"
        }
        returnButton?.setTitle(title, for: .normal)
    }

    @objc private func toggleLanguage() {
        shifted = false
        capsLock = false
        send(["action": "toggle_language"])
    }

    @objc private func toggleTranslation() {
        showTranslation.toggle()
        UserDefaults.standard.set(!showTranslation, forKey: "hideEnglishGloss")
        translation.setTitle(showTranslation ? "译词 ✓" : "译词", for: .normal)
        if let frame { render(frame, resetScroll: false) }
    }

    @objc private func cancelComposition() { send(["action": "cancel"]) }

    @objc private func longDelete(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            send(["action": "backspace"])
            deleteTimer = Timer.scheduledTimer(withTimeInterval: 0.085, repeats: true) { [weak self] _ in self?.send(["action": "backspace"]) }
        case .ended, .cancelled, .failed: stopDeleting()
        default: break
        }
    }
    private func stopDeleting() { deleteTimer?.invalidate(); deleteTimer = nil }

    private func send(_ command: [String: Any]) {
        sequence += 1
        let request = sequence
        let epoch = documentEpoch
        engine.perform(command) { [weak self] result in
            guard let self, self.visible, epoch == self.documentEpoch else { return }
            guard let result else {
                self.engineFailed = true
                self.hint.text = "中文引擎未能启动，请切换系统键盘或重新启用"
                self.hint.isHidden = false
                return
            }
            // 每次上屏都执行，候选显示只采用最新输入结果。
            self.writing = true
            if !result.committed.isEmpty { self.textDocumentProxy.insertText(result.committed) }
            if result.delete_backward { self.textDocumentProxy.deleteBackward() }
            self.rememberContext()
            self.writing = false
            guard request == self.sequence else { return }
            let languageChanged = self.frame?.english != result.english
            self.frame = result
            self.engineFailed = result.error != nil && result.error != "Candidate has expired"
            self.render(result, resetScroll: true)
            if languageChanged { self.rebuildKeys() }
            if self.showTranslation && !result.candidates.isEmpty {
                self.engine.perform(["action": "annotate", "revision": result.revision]) { [weak self] annotated in
                    guard let self, let annotated, self.visible,
                          epoch == self.documentEpoch, request == self.sequence,
                          annotated.revision == self.frame?.revision else { return }
                    self.frame = annotated
                    self.render(annotated, resetScroll: false)
                }
            }
        }
    }

    private func render(_ result: EngineFrame, resetScroll: Bool) {
        preedit.text = result.preedit.isEmpty ? "简词" : result.preedit
        language.setTitle(result.english ? "EN / 中" : "中 / EN", for: .normal)
        cancelButton.isHidden = result.input.isEmpty
        candidateStack.arrangedSubviews.forEach { candidateStack.removeArrangedSubview($0); $0.removeFromSuperview() }
        for (index, candidate) in result.candidates.enumerated() {
            let button = CandidateButton(candidate: candidate, showTranslation: showTranslation)
            button.action = { [weak self] in self?.send(["action": "choose", "revision": result.revision, "index": index]) }
            candidateStack.addArrangedSubview(button)
        }
        if !result.input.isEmpty {
            let raw = CandidateButton(candidate: .init(text: result.input, annotation: "原样输入"), showTranslation: true)
            raw.action = { [weak self] in self?.send(["action": "raw"]) }
            candidateStack.addArrangedSubview(raw)
        }
        hint.isHidden = !result.candidates.isEmpty || !result.input.isEmpty
        hint.text = result.warning ?? (result.english ? "English · 离线输入" : "输入拼音，顺便认识一个英文词")
        if engineFailed { hint.text = "输入引擎异常，请切换系统键盘后重新启用" }
        if resetScroll { scroll.setContentOffset(.zero, animated: false) }
    }
}

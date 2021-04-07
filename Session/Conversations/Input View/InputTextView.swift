
public final class InputTextView : UITextView, UITextViewDelegate {
    private weak var snDelegate: InputTextViewDelegate?
    private let maxWidth: CGFloat
    private lazy var heightConstraint = self.set(.height, to: minHeight)
    
    public override var text: String! { didSet { handleTextChanged() } }
    
    // MARK: UI Components
    private lazy var placeholderLabel: UILabel = {
        let result = UILabel()
        result.text = "Message"
        result.font = .systemFont(ofSize: Values.mediumFontSize)
        result.textColor = Colors.text.withAlphaComponent(Values.mediumOpacity)
        return result
    }()
    
    // MARK: Settings
    private let minHeight: CGFloat = 22
    private let maxHeight: CGFloat = 80

    // MARK: Lifecycle
    init(delegate: InputTextViewDelegate, maxWidth: CGFloat) {
        snDelegate = delegate
        self.maxWidth = maxWidth
        super.init(frame: CGRect.zero, textContainer: nil)
        setUpViewHierarchy()
        self.delegate = self
    }
    
    public override init(frame: CGRect, textContainer: NSTextContainer?) {
        preconditionFailure("Use init(delegate:) instead.")
    }

    public required init?(coder: NSCoder) {
        preconditionFailure("Use init(delegate:) instead.")
    }

    private func setUpViewHierarchy() {
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        backgroundColor = .clear
        textColor = Colors.text
        font = .systemFont(ofSize: Values.mediumFontSize)
        tintColor = Colors.accent
        keyboardAppearance = isLightMode ? .light : .dark
        heightConstraint.isActive = true
        let horizontalInset: CGFloat = 2
        textContainerInset = UIEdgeInsets(top: 0, left: horizontalInset, bottom: 0, right: horizontalInset)
        addSubview(placeholderLabel)
        placeholderLabel.pin(.leading, to: .leading, of: self, withInset: horizontalInset + 3) // Slight visual adjustment
        placeholderLabel.pin(.top, to: .top, of: self)
        pin(.trailing, to: .trailing, of: placeholderLabel, withInset: horizontalInset)
        pin(.bottom, to: .bottom, of: placeholderLabel)
    }

    // MARK: Updating
    public func textViewDidChange(_ textView: UITextView) {
        handleTextChanged()
    }
    
    private func handleTextChanged() {
        defer { snDelegate?.inputTextViewDidChangeContent(self) }
        placeholderLabel.isHidden = !text.isEmpty
        let height = frame.height
        let size = sizeThatFits(CGSize(width: maxWidth, height: .greatestFiniteMagnitude))
        // `textView.contentSize` isn't accurate when restoring a multiline draft, so we set it here manually
        self.contentSize = size
        let newHeight = size.height.clamp(minHeight, maxHeight)
        guard newHeight != height else { return }
        heightConstraint.constant = newHeight
        snDelegate?.inputTextViewDidChangeSize(self)
    }
}

// MARK: Delegate
protocol InputTextViewDelegate : class {
    
    func inputTextViewDidChangeSize(_ inputTextView: InputTextView)
    func inputTextViewDidChangeContent(_ inputTextView: InputTextView)
}

//
//  NoteChecklistViews.swift
//  Lunixia
//

import SwiftUI
import UIKit

struct NoteChecklistCircle: View {
    let isCompleted: Bool
    var size: CGFloat = 24
    var lineWidth: CGFloat = 2

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    isCompleted ? AnyShapeStyle(Color.clear) : AnyShapeStyle(LGradients.header),
                    lineWidth: lineWidth
                )
                .background(
                    Circle()
                        .fill(isCompleted ? AnyShapeStyle(LGradients.header) : AnyShapeStyle(Color.clear))
            )

            if isCompleted {
                Image("checkwavy")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.white)
                    .frame(width: size * 0.48, height: size * 0.48)
            }
        }
        .frame(width: size, height: size)
    }
}

struct NoteChecklistDisplay: View {
    let items: [NoteChecklistItem]
    let font: NoteFontOption
    var textColor: Color = .white
    var circleSize: CGFloat = 22
    var textSize: CGFloat = 15
    var lineLimit: Int? = nil
    var rowSpacing: CGFloat = 9

    var body: some View {
        VStack(alignment: .leading, spacing: rowSpacing) {
            ForEach(items) { item in
                HStack(alignment: .top, spacing: 9) {
                    NoteChecklistCircle(isCompleted: item.isCompleted, size: circleSize)
                        .padding(.top, 1)

                    Text(item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Checklist item" : item.title)
                        .font(font.font(size: textSize))
                        .foregroundStyle(item.isCompleted ? textColor.opacity(0.5) : textColor)
                        .strikethrough(item.isCompleted, color: textColor.opacity(0.72))
                        .lineSpacing(2)
                        .lineLimit(lineLimit)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

struct NoteChecklistInteractiveDisplay: View {
    let items: [NoteChecklistItem]
    let font: NoteFontOption
    var textColor: Color = .white
    var circleSize: CGFloat = 22
    var textSize: CGFloat = 15
    var lineLimit: Int? = nil
    var rowSpacing: CGFloat = 9
    var onToggle: (NoteChecklistItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: rowSpacing) {
            ForEach(items) { item in
                HStack(alignment: .top, spacing: 9) {
                    Button {
                        onToggle(item)
                    } label: {
                        NoteChecklistCircle(isCompleted: item.isCompleted, size: circleSize)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.isCompleted ? "Mark item incomplete" : "Mark item complete")

                    Text(item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Checklist item" : item.title)
                        .font(font.font(size: textSize))
                        .foregroundStyle(item.isCompleted ? textColor.opacity(0.5) : textColor)
                        .strikethrough(item.isCompleted, color: textColor.opacity(0.72))
                        .lineSpacing(2)
                        .lineLimit(lineLimit)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

struct NoteListMarker: View {
    let kind: NoteListItemKind
    let number: Int
    var size: CGFloat = 22
    var textColor: Color = .white

    var body: some View {
        Group {
            switch kind {
            case .bullet:
                Circle()
                    .fill(LGradients.header)
                    .frame(width: max(6, size * 0.38), height: max(6, size * 0.38))
                    .frame(width: size, height: size)
            case .numbered:
                Text("\(number).")
                    .font(.system(size: max(10, size * 0.58), weight: .black, design: .rounded))
                    .foregroundStyle(textColor)
                    .monospacedDigit()
                    .frame(width: max(size + 8, 28), height: size, alignment: .trailing)
            }
        }
    }
}

struct NoteListDisplay: View {
    let items: [NoteListItem]
    let font: NoteFontOption
    var textColor: Color = .white
    var markerSize: CGFloat = 22
    var textSize: CGFloat = 15
    var lineLimit: Int? = nil
    var rowSpacing: CGFloat = 9

    var body: some View {
        VStack(alignment: .leading, spacing: rowSpacing) {
            ForEach(Array(items.enumerated()), id: \.element.id) { _, item in
                HStack(alignment: .top, spacing: 9) {
                    NoteListMarker(
                        kind: item.kind,
                        number: number(for: item),
                        size: markerSize,
                        textColor: textColor.opacity(0.86)
                    )
                    .padding(.top, 1)

                    Text(item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "List item" : item.title)
                        .font(font.font(size: textSize))
                        .foregroundStyle(textColor)
                        .lineSpacing(2)
                        .lineLimit(lineLimit)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func number(for item: NoteListItem) -> Int {
        let numberedItems = items.filter { $0.kind == .numbered }
        guard let index = numberedItems.firstIndex(where: { $0.id == item.id }) else { return 1 }
        return index + 1
    }
}

struct NoteListTypesEditor: View {
    @Binding var listItems: [NoteListItem]
    @Binding var checklistItems: [NoteChecklistItem]
    var onShowHelp: () -> Void
    var onOpenType: (NoteListPlacementType) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("List Types")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Tap a type to add or edit its items.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.68))
                }
                Spacer()
            }

            VStack(spacing: 8) {
                ForEach(NoteListPlacementType.allCases) { type in
                    Button {
                        onOpenType(type)
                    } label: {
                        HStack(spacing: 10) {
                            Text(type.title)
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                            Spacer()
                            Text(countLabel(for: type))
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.6))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.10))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.22), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                onShowHelp()
            } label: {
                Text("Learn how to use list types")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.86))
                    .underline()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
    }

    private func countLabel(for type: NoteListPlacementType) -> String {
        let count: Int
        switch type {
        case .bullets:   count = listItems.filter { $0.kind == .bullet }.count
        case .checklist: count = checklistItems.count
        case .numbers:   count = listItems.filter { $0.kind == .numbered }.count
        }
        return count == 1 ? "1 item" : "\(count) items"
    }
}

struct NotesGradientDoneTextField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var fontOption: NoteFontOption = .system
    var fontSize: CGFloat = 15
    var textColor: UIColor = .white

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.backgroundColor = .clear
        textField.textColor = textColor
        textField.tintColor = UIColor(lunixiaNotesHex: "#03DBFC")
        textField.font = fontOption.notesUIFont(size: fontSize)
        textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.48)]
        )
        textField.inputAccessoryView = NotesKeyboardAccessoryView {
            textField.resignFirstResponder()
        }
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.isFirstResponder {
            uiView.textColor = textColor
            uiView.font = fontOption.notesUIFont(size: fontSize)
            return
        }

        if uiView.text != text { uiView.text = text }
        uiView.textColor = textColor
        uiView.font = fontOption.notesUIFont(size: fontSize)
        uiView.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.48)]
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String

        init(text: Binding<String>) {
            _text = text
        }

        @objc func textChanged(_ textField: UITextField) {
            text = textField.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }
    }
}

struct NotesGradientDoneTextView: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var fontOption: NoteFontOption
    var fontSize: CGFloat
    var textColor: UIColor = .white
    var minHeight: CGFloat = 42
    var highlightPlacementTokens: Bool = false
    var locksParentScrollWhileEditing: Bool = false
    var verticallyCentersText: Bool = false
    var growsWithContent: Bool = false
    @Binding var isFocused: Bool

    init(
        placeholder: String,
        text: Binding<String>,
        fontOption: NoteFontOption,
        fontSize: CGFloat,
        textColor: UIColor = .white,
        minHeight: CGFloat = 42,
        highlightPlacementTokens: Bool = false,
        locksParentScrollWhileEditing: Bool = false,
        verticallyCentersText: Bool = false,
        growsWithContent: Bool = false,
        isFocused: Binding<Bool> = .constant(false)
    ) {
        self.placeholder = placeholder
        _text = text
        self.fontOption = fontOption
        self.fontSize = fontSize
        self.textColor = textColor
        self.minHeight = minHeight
        self.highlightPlacementTokens = highlightPlacementTokens
        self.locksParentScrollWhileEditing = locksParentScrollWhileEditing
        self.verticallyCentersText = verticallyCentersText
        self.growsWithContent = growsWithContent
        _isFocused = isFocused
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = NotesScrollableTextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.baseTextContainerInset = UIEdgeInsets(top: 9, left: 6, bottom: 9, right: 6)
        textView.minimumHeight = minHeight
        textView.growsWithContent = growsWithContent
        textView.textContainerInset = textView.baseTextContainerInset
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.widthTracksTextView = true
        textView.textContainer.maximumNumberOfLines = 0
        textView.isScrollEnabled = !growsWithContent
        textView.alwaysBounceVertical = !growsWithContent
        textView.showsVerticalScrollIndicator = !growsWithContent
        textView.keyboardDismissMode = .none
        textView.contentInsetAdjustmentBehavior = .never
        textView.contentInset = verticallyCentersText ? .zero : UIEdgeInsets(top: 0, left: 0, bottom: 24, right: 0)
        textView.scrollIndicatorInsets = textView.contentInset
        textView.verticallyCentersText = verticallyCentersText
        textView.textColor = textColor
        textView.tintColor = UIColor(lunixiaNotesHex: "#03DBFC")
        textView.font = fontOption.notesUIFont(size: fontSize)
        textView.returnKeyType = .default
        textView.enablesReturnKeyAutomatically = false
        textView.inputAccessoryView = NotesKeyboardAccessoryView {
            textView.resignFirstResponder()
        }
        textView.onTextInsetChange = { [weak coordinator = context.coordinator] textInset in
            coordinator?.placeholderTopConstraint?.constant = textInset.top
        }

        let placeholderLabel = UILabel()
        placeholderLabel.text = placeholder
        placeholderLabel.textColor = UIColor.white.withAlphaComponent(0.48)
        placeholderLabel.font = fontOption.notesUIFont(size: fontSize)
        placeholderLabel.numberOfLines = 0
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        textView.addSubview(placeholderLabel)
        NSLayoutConstraint.activate([
            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 6),
            placeholderLabel.trailingAnchor.constraint(equalTo: textView.trailingAnchor, constant: -6),
        ])
        let placeholderTopConstraint = placeholderLabel.topAnchor.constraint(equalTo: textView.topAnchor, constant: 9)
        placeholderTopConstraint.isActive = true
        context.coordinator.placeholderLabel = placeholderLabel
        context.coordinator.placeholderTopConstraint = placeholderTopConstraint

        context.coordinator.apply(text: text, to: textView)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.parent = self
        if let notesTextView = uiView as? NotesScrollableTextView {
            notesTextView.verticallyCentersText = verticallyCentersText
            notesTextView.growsWithContent = growsWithContent
            notesTextView.minimumHeight = minHeight
            notesTextView.isScrollEnabled = !growsWithContent
            notesTextView.alwaysBounceVertical = !growsWithContent
            notesTextView.showsVerticalScrollIndicator = !growsWithContent
            notesTextView.contentInset = verticallyCentersText ? .zero : UIEdgeInsets(top: 0, left: 0, bottom: 24, right: 0)
            notesTextView.scrollIndicatorInsets = notesTextView.contentInset
        }
        context.coordinator.placeholderLabel?.isHidden = !text.isEmpty
        uiView.textColor = textColor
        uiView.font = fontOption.notesUIFont(size: fontSize)
        context.coordinator.placeholderLabel?.font = fontOption.notesUIFont(size: fontSize)
        context.coordinator.placeholderLabel?.text = placeholder

        if uiView.isFirstResponder {
            if uiView.text != text {
                context.coordinator.apply(text: text, to: uiView)
            } else if context.coordinator.needsStyleUpdate {
                context.coordinator.applyLiveAttributes(to: uiView)
            } else {
                context.coordinator.applyTypingAttributes(to: uiView)
            }
            return
        }

        context.coordinator.apply(text: text, to: uiView)

        if isFocused, !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard growsWithContent else { return nil }
        let width = proposal.width ?? uiView.bounds.width
        guard width > 0 else { return CGSize(width: 0, height: minHeight) }

        let fittingSize = CGSize(width: width, height: .greatestFiniteMagnitude)
        let fittingHeight = ceil(uiView.sizeThatFits(fittingSize).height)
        return CGSize(width: width, height: max(minHeight, fittingHeight))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    static func dismantleUIView(_ uiView: UITextView, coordinator: Coordinator) {
        coordinator.restoreParentScroll()
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: NotesGradientDoneTextView
        weak var placeholderLabel: UILabel?
        weak var placeholderTopConstraint: NSLayoutConstraint?
        weak var parentScrollView: UIScrollView?
        private var isApplyingAttributes = false
        private var appliedStyleKey: String = ""

        init(parent: NotesGradientDoneTextView) {
            self.parent = parent
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.isFocused = true
            lockParentScrollIfNeeded(from: textView)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent.isFocused = false
            restoreParentScroll()
            apply(text: parent.text, to: textView)
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isApplyingAttributes else { return }
            parent.text = textView.text ?? ""
            placeholderLabel?.isHidden = !parent.text.isEmpty

            if parent.highlightPlacementTokens {
                applyLiveAttributes(to: textView)
            }
            textView.invalidateIntrinsicContentSize()
        }

        func apply(text: String, to textView: UITextView) {
            let currentText = textView.text ?? ""
            let selectedRange = textView.selectedRange
            let baseFont = parent.fontOption.notesUIFont(size: parent.fontSize)
            let baseAttributes: [NSAttributedString.Key: Any] = [
                .font: baseFont,
                .foregroundColor: parent.textColor
            ]
            let attributed = NSMutableAttributedString(string: text, attributes: baseAttributes)

            if parent.highlightPlacementTokens {
                applyTokenHighlights(to: attributed, baseFont: baseFont)
            }

            isApplyingAttributes = true
            if currentText != text || textView.attributedText != attributed {
                textView.attributedText = attributed
            }
            textView.invalidateIntrinsicContentSize()
            textView.typingAttributes = baseAttributes
            if selectedRange.location + selectedRange.length <= attributed.length {
                textView.selectedRange = selectedRange
            } else {
                textView.selectedRange = NSRange(location: attributed.length, length: 0)
            }
            placeholderLabel?.isHidden = !text.isEmpty
            updatePlaceholderPosition(for: textView)
            appliedStyleKey = styleKey
            isApplyingAttributes = false
        }

        var needsStyleUpdate: Bool {
            appliedStyleKey != styleKey
        }

        func applyTypingAttributes(to textView: UITextView) {
            let baseFont = parent.fontOption.notesUIFont(size: parent.fontSize)
            textView.typingAttributes = [
                .font: baseFont,
                .foregroundColor: parent.textColor
            ]
        }

        private func applyTokenHighlights(to attributed: NSMutableAttributedString, baseFont: UIFont) {
            let content = attributed.string as NSString
            let tokenFont = UIFont(descriptor: baseFont.fontDescriptor, size: max(12, baseFont.pointSize - 1))

            let tokens = Set(Note.placements(in: attributed.string).map { $0.type.token(group: $0.group) })
            for token in tokens {
                var searchRange = NSRange(location: 0, length: content.length)
                while searchRange.length > 0 {
                    let foundRange = content.range(of: token, options: [], range: searchRange)
                    guard foundRange.location != NSNotFound else { break }
                    attributed.addAttributes(
                        [
                            .font: tokenFont,
                            .foregroundColor: UIColor.white.withAlphaComponent(0.95),
                            .backgroundColor: UIColor.white.withAlphaComponent(0.20)
                        ],
                        range: foundRange
                    )
                    let nextLocation = foundRange.location + foundRange.length
                    searchRange = NSRange(location: nextLocation, length: max(0, content.length - nextLocation))
                }
            }
        }

        func applyLiveAttributes(to textView: UITextView) {
            guard textView.markedTextRange == nil else { return }

            let selectedRange = textView.selectedRange
            let contentOffset = textView.contentOffset
            let textLength = textView.textStorage.length
            let baseFont = parent.fontOption.notesUIFont(size: parent.fontSize)
            let baseAttributes: [NSAttributedString.Key: Any] = [
                .font: baseFont,
                .foregroundColor: parent.textColor
            ]

            isApplyingAttributes = true
            textView.textStorage.beginEditing()
            textView.textStorage.setAttributes(baseAttributes, range: NSRange(location: 0, length: textLength))
            applyTokenHighlights(to: textView.textStorage, baseFont: baseFont)
            textView.textStorage.endEditing()
            textView.typingAttributes = baseAttributes
            if selectedRange.location + selectedRange.length <= textView.textStorage.length {
                textView.selectedRange = selectedRange
            }
            textView.setContentOffset(contentOffset, animated: false)
            textView.invalidateIntrinsicContentSize()
            updatePlaceholderPosition(for: textView)
            appliedStyleKey = styleKey
            isApplyingAttributes = false
        }

        func updatePlaceholderPosition(for textView: UITextView) {
            placeholderTopConstraint?.constant = textView.textContainerInset.top
        }

        private var styleKey: String {
            let font = parent.fontOption.notesUIFont(size: parent.fontSize)
            return [
                font.fontName,
                "\(font.pointSize)",
                "\(parent.textColor)",
                "\(parent.highlightPlacementTokens)"
            ].joined(separator: "|")
        }

        private func lockParentScrollIfNeeded(from textView: UITextView) {
            guard parent.locksParentScrollWhileEditing else { return }
            guard parentScrollView == nil else { return }

            var candidate = textView.superview
            while let view = candidate {
                if let scrollView = view as? UIScrollView, scrollView !== textView {
                    parentScrollView = scrollView
                    scrollView.isScrollEnabled = false
                    return
                }
                candidate = view.superview
            }
        }

        func restoreParentScroll() {
            parentScrollView?.isScrollEnabled = true
            parentScrollView = nil
        }

    }
}

private final class NotesScrollableTextView: UITextView {
    var minimumHeight: CGFloat = 42 {
        didSet {
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    var growsWithContent = false {
        didSet {
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    var onTextInsetChange: ((UIEdgeInsets) -> Void)?
    private var lastIntrinsicWidth: CGFloat = 0

    var baseTextContainerInset = UIEdgeInsets(top: 9, left: 6, bottom: 9, right: 6) {
        didSet {
            if !verticallyCentersText {
                textContainerInset = baseTextContainerInset
            }
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    var verticallyCentersText = false {
        didSet {
            setNeedsLayout()
        }
    }

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        delaysContentTouches = false
        canCancelContentTouches = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        delaysContentTouches = false
        canCancelContentTouches = true
    }

    override var text: String! {
        didSet {
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    override var attributedText: NSAttributedString! {
        didSet {
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    override var font: UIFont? {
        didSet {
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    override var bounds: CGRect {
        didSet {
            if abs(bounds.width - lastIntrinsicWidth) > 0.5 {
                lastIntrinsicWidth = bounds.width
                invalidateIntrinsicContentSize()
                setNeedsLayout()
            }
        }
    }

    override var intrinsicContentSize: CGSize {
        guard growsWithContent else {
            return super.intrinsicContentSize
        }

        let fittingWidth = bounds.width > 0 ? bounds.width : UIScreen.main.bounds.width - 96
        let contentWidth = max(1, fittingWidth - baseTextContainerInset.left - baseTextContainerInset.right)
        textContainer.size = CGSize(width: contentWidth, height: .greatestFiniteMagnitude)
        layoutManager.ensureLayout(for: textContainer)
        let usedHeight = ceil(layoutManager.usedRect(for: textContainer).height)
        let lineHeight = font?.lineHeight ?? 0
        let textHeight = max(lineHeight, usedHeight)
        let height = max(minimumHeight, textHeight + baseTextContainerInset.top + baseTextContainerInset.bottom)
        return CGSize(width: UIView.noIntrinsicMetric, height: ceil(height))
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateVerticalTextInsetIfNeeded()
    }

    private func updateVerticalTextInsetIfNeeded() {
        guard verticallyCentersText else {
            if textContainerInset != baseTextContainerInset {
                textContainerInset = baseTextContainerInset
                onTextInsetChange?(baseTextContainerInset)
            }
            return
        }

        layoutManager.ensureLayout(for: textContainer)
        let usedHeight = ceil(layoutManager.usedRect(for: textContainer).height)
        let lineHeight = font?.lineHeight ?? 0
        let textHeight = max(lineHeight, usedHeight)
        let centeredTop = max(baseTextContainerInset.top, floor((bounds.height - textHeight) / 2))
        let centeredBottom = max(baseTextContainerInset.bottom, bounds.height - textHeight - centeredTop)
        let centeredInset = UIEdgeInsets(
            top: centeredTop,
            left: baseTextContainerInset.left,
            bottom: centeredBottom,
            right: baseTextContainerInset.right
        )

        if textContainerInset != centeredInset {
            textContainerInset = centeredInset
            onTextInsetChange?(centeredInset)
        }
    }
}

private final class NotesKeyboardAccessoryView: UIView {
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
        super.init(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 50))
        backgroundColor = UIColor.black.withAlphaComponent(0.08)

        let button = NotesGradientDoneButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        addSubview(button)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 50),
            button.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            button.centerYAnchor.constraint(equalTo: centerYAnchor),
            button.heightAnchor.constraint(equalToConstant: 32),
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 64)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func doneTapped() {
        action()
    }
}

private final class NotesGradientDoneButton: UIButton {
    private let gradientLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setTitle("Done", for: .normal)
        setTitleColor(.white, for: .normal)
        titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
        layer.cornerRadius = 16
        layer.masksToBounds = true
        gradientLayer.colors = [
            UIColor(lunixiaNotesHex: "#7D19F7").cgColor,
            UIColor(lunixiaNotesHex: "#03DBFC").cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        layer.insertSublayer(gradientLayer, at: 0)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
}

private extension NoteFontOption {
    func notesUIFont(size: CGFloat) -> UIFont {
        _ = font(size: size)

        switch self {
        case .system:
            return .systemFont(ofSize: size)
        case .rounded:
            let descriptor = UIFont.systemFont(ofSize: size).fontDescriptor.withDesign(.rounded)
                ?? UIFont.systemFont(ofSize: size).fontDescriptor
            return UIFont(descriptor: descriptor, size: size)
        case .serif:
            let descriptor = UIFont.systemFont(ofSize: size).fontDescriptor.withDesign(.serif)
                ?? UIFont.systemFont(ofSize: size).fontDescriptor
            return UIFont(descriptor: descriptor, size: size)
        default:
            if let postScriptName, let customFont = UIFont(name: postScriptName, size: size) {
                return customFont
            }
            return .systemFont(ofSize: size)
        }
    }
}

private extension UIColor {
    convenience init(lunixiaNotesHex hex: String) {
        let cleaned = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let red = CGFloat((value >> 16) & 0xFF) / 255
        let green = CGFloat((value >> 8) & 0xFF) / 255
        let blue = CGFloat(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue, alpha: 1)
    }
}

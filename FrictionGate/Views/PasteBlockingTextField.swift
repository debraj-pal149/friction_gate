import SwiftUI
import UIKit

/// A `UITextField` wrapper that blocks paste and cut so the user must type
/// every character manually.  Used by `TypeSentenceView` and `PauseRuleView`.
struct PasteBlockingTextField: UIViewRepresentable {

    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var font: UIFont = .systemFont(ofSize: 16)
    var autocapitalizationType: UITextAutocapitalizationType = .sentences
    var onCommit: (() -> Void)? = nil

    func makeUIView(context: Context) -> NoPasteUITextField {
        let field = NoPasteUITextField()
        field.delegate        = context.coordinator
        field.placeholder     = placeholder
        field.font            = font
        field.keyboardType    = keyboardType
        field.autocorrectionType     = .no
        field.autocapitalizationType = autocapitalizationType
        field.spellCheckingType      = .no
        field.returnKeyType   = .done
        field.borderStyle     = .none
        field.backgroundColor = .clear
        field.addTarget(
            context.coordinator,
            action: #selector(Coordinator.editingChanged(_:)),
            for: .editingChanged
        )
        return field
    }

    func updateUIView(_ uiView: NoPasteUITextField, context: Context) {
        if uiView.text != text { uiView.text = text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: PasteBlockingTextField
        init(_ parent: PasteBlockingTextField) { self.parent = parent }

        @objc func editingChanged(_ field: UITextField) {
            parent.text = field.text ?? ""
        }

        func textFieldShouldReturn(_ field: UITextField) -> Bool {
            field.resignFirstResponder()
            parent.onCommit?()
            return true
        }
    }
}

/// `UITextField` subclass that blocks paste and cut from the context menu.
final class NoPasteUITextField: UITextField {
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(paste(_:)) || action == #selector(cut(_:)) {
            return false
        }
        return super.canPerformAction(action, withSender: sender)
    }
}

/// A multiline `UITextView` wrapper that blocks paste and cut so long phrases
/// can still be typed manually without layout/truncation issues.
struct PasteBlockingTextView: UIViewRepresentable {

    @Binding var text: String
    var font: UIFont = .systemFont(ofSize: 16)
    var autocapitalizationType: UITextAutocapitalizationType = .sentences

    func makeUIView(context: Context) -> NoPasteUITextView {
        let view = NoPasteUITextView()
        view.delegate = context.coordinator
        view.font = font
        view.textContainerInset = UIEdgeInsets(top: 10, left: 4, bottom: 10, right: 4)
        view.textContainer.lineFragmentPadding = 0
        view.autocorrectionType = .no
        view.autocapitalizationType = autocapitalizationType
        view.spellCheckingType = .no
        view.keyboardType = .default
        view.returnKeyType = .default
        view.backgroundColor = .clear
        view.isScrollEnabled = true
        view.alwaysBounceVertical = true
        return view
    }

    func updateUIView(_ uiView: NoPasteUITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: PasteBlockingTextView
        init(_ parent: PasteBlockingTextView) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }
    }
}

/// `UITextView` subclass that blocks paste and cut from context menu/actions.
final class NoPasteUITextView: UITextView {
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(paste(_:)) || action == #selector(cut(_:)) {
            return false
        }
        return super.canPerformAction(action, withSender: sender)
    }
}

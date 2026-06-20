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

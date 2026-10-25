import SwiftUI
import UIKit

extension Color {
    static let paperSurface = adaptive(light: 0xFFFFFF, dark: 0x141414)
    static let wardrobeBackground = adaptive(light: 0xFFFFFF, dark: 0x000000)
    static let imageMount = paperSurface
    static let cutoutSurface = Color.white
    static let stageHighlight = adaptive(light: 0xFFFFFF, dark: 0x1C1C1E)
    static let wearwiseBlue = adaptive(light: 0x355872, dark: 0xFFFFFF)
    static let onAccent = adaptive(light: 0xFFFFFF, dark: 0x000000)
    static let primaryFill = Color(uiColor: UIColor(rgb: 0x355872))
    static let onPrimaryFill = Color.white
    static let supportingText = wearwiseBlue.opacity(0.82)
    static let accentText = wearwiseBlue
    static let accentSurface = paperSurface
    static let subtleBorder = wearwiseBlue.opacity(0.22)
    static let charcoalText = wearwiseBlue
    static let shadowTint = adaptive(light: 0x355872, dark: 0x000000)

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

enum WearwiseRadius {
    static let small: CGFloat = 12
    static let medium: CGFloat = 16
    static let large: CGFloat = 22
    static let extraLarge: CGFloat = 28
}

enum WearwiseElevation: Equatable {
    case card, floating
}

private struct WearwiseShadow: ViewModifier {
    let elevation: WearwiseElevation
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let dark = scheme == .dark
        let floating = elevation == .floating
        content
            .shadow(color: Color.shadowTint.opacity(dark ? (floating ? 0.22 : 0.18) : (floating ? 0.08 : 0.05)),
                    radius: floating ? 7 : 4, y: floating ? 4 : 2)
            .shadow(color: Color.shadowTint.opacity(dark ? (floating ? 0.28 : 0.22) : (floating ? 0.10 : 0.06)),
                    radius: floating ? 20 : 12, y: floating ? 16 : 8)
    }
}

extension View {
    func wearwiseShadow(_ elevation: WearwiseElevation = .card) -> some View {
        modifier(WearwiseShadow(elevation: elevation))
    }
}

extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(red: CGFloat((rgb >> 16) & 255) / 255,
                  green: CGFloat((rgb >> 8) & 255) / 255,
                  blue: CGFloat(rgb & 255) / 255, alpha: 1)
    }
}

struct WearwiseButtonStyle: ButtonStyle {
    var filled = true
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 18)
            .frame(minHeight: 44)
            .foregroundStyle(filled ? Color.onPrimaryFill : Color.accentText)
            .background(filled ? Color.primaryFill : Color.accentSurface,
                        in: RoundedRectangle(cornerRadius: WearwiseRadius.small, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: WearwiseRadius.small, style: .continuous)
                    .strokeBorder(filled ? Color.clear : Color.subtleBorder, lineWidth: 1)
            }
            .shadow(color: filled && isEnabled ? Color.primaryFill.opacity(0.28) : .clear, radius: 4, y: 2)
            .opacity(isEnabled ? (configuration.isPressed ? 0.78 : 1) : 0.4)
            .scaleEffect(isEnabled && configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct WearwisePressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct WearwiseNotesEditor: View {
    @Binding var text: String
    var label = "Notes"

    var body: some View {
        TextEditor(text: $text)
            .font(.body)
            .frame(height: 160)
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text(label).foregroundStyle(.tertiary)
                        .padding(.top, 8).padding(.leading, 5)
                        .allowsHitTesting(false).accessibilityHidden(true)
                }
            }
            .accessibilityLabel(label)
    }
}

struct WearwiseStatusBadge: View {
    let worn: Bool

    var body: some View {
        Text(worn ? "Worn" : "Planned")
            .font(.caption.weight(.semibold))
            .foregroundStyle(worn ? Color.onAccent : Color.accentText)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(worn ? Color.wearwiseBlue : Color.paperSurface, in: Capsule())
            .overlay { Capsule().strokeBorder(Color.accentText, lineWidth: 1) }
    }
}

struct WearwiseEmptyState: View {
    var title: String
    var systemImage: String
    var description: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        ContentUnavailableView {
            Label {
                Text(title)
            } icon: {
                Image(systemName: systemImage)
                    .font(.system(size: 52, weight: .light)).foregroundStyle(Color.accentText)
            }
            .labelStyle(.titleAndIcon)
        } description: {
            if let description { Text(description) }
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, systemImage: actionTitle.hasPrefix("Clear") ? "arrow.counterclockwise" : "plus", action: action)
                    .labelStyle(.iconOnly).buttonStyle(WearwiseButtonStyle())
            }
        }
    }
}

private struct WearwiseToastCard<Actions: View>: View {
    let title: String
    let message: String?
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
            if let message, !message.isEmpty {
                Text(message).font(.footnote).foregroundStyle(Color.supportingText)
                    .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
            }
            actions()
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentText)
        .padding(16).frame(maxWidth: 330)
        .background(Color.paperSurface, in: RoundedRectangle(cornerRadius: WearwiseRadius.small))
        .overlay { RoundedRectangle(cornerRadius: WearwiseRadius.small).stroke(Color.subtleBorder, lineWidth: 0.5) }
        .wearwiseShadow(.floating)
    }
}

private struct WearwiseConfirmationToast: ViewModifier {
    @Environment(\.dynamicTypeSize) private var textSize
    @Binding var isPresented: Bool
    let title: String
    let message: String?
    let onConfirm: () -> Void

    private var card: some View {
        WearwiseToastCard(title: title, message: message) {
            if textSize.isAccessibilitySize {
                VStack(spacing: 8) { cancel; confirm }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { cancel; confirm }
                    VStack(spacing: 8) { cancel; confirm }
                }
            }
        }
        .accessibilityElement(children: .contain).accessibilityAddTraits(.isModal)
        .accessibilityIdentifier("toast.confirmation")
    }

    private var cancel: some View {
        Button("Cancel") { isPresented = false }
            .font(.subheadline.weight(.medium)).fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 44)
            .accessibilityIdentifier("toast.cancel")
    }

    private var confirm: some View {
        Button("Confirm") {
            // Item-backed bindings must keep their selection until the action finishes.
            onConfirm()
            isPresented = false
        }
        .font(.subheadline.weight(.semibold)).fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.center)
        .padding(.horizontal, 12).frame(maxWidth: .infinity, minHeight: 44)
        .foregroundStyle(Color.onPrimaryFill)
        .background(Color.primaryFill, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityIdentifier("toast.confirm")
    }

    func body(content: Content) -> some View {
        content
            .overlay {
                if isPresented {
                    GeometryReader { geometry in
                        ZStack {
                            Color.shadowTint.opacity(0.18).ignoresSafeArea()
                                .onTapGesture { isPresented = false }
                            ViewThatFits(in: .vertical) {
                                card.fixedSize(horizontal: false, vertical: true)
                                ScrollView { card }.scrollBounceBehavior(.basedOnSize)
                            }
                            .frame(maxWidth: 330, maxHeight: max(0, geometry.size.height - 32))
                            .padding(.horizontal, 20)
                        }.frame(width: geometry.size.width, height: geometry.size.height)
                    }
                    .accessibilityAction(.escape) { isPresented = false }
                    .onAppear {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        if UIAccessibility.isVoiceOverRunning { UIAccessibility.post(notification: .screenChanged, argument: title) }
                    }
                    .onDisappear {
                        if UIAccessibility.isVoiceOverRunning { UIAccessibility.post(notification: .screenChanged, argument: nil) }
                    }
                }
            }
    }
}

private struct WearwiseErrorToast: ViewModifier {
    let title: String
    @Binding var message: String?

    private func notice(_ message: String) -> some View {
        WearwiseToastCard(title: title, message: message) {
            Button("Dismiss", systemImage: "xmark") { self.message = nil }
                .labelStyle(.titleAndIcon).font(.footnote.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .trailing)
                .accessibilityIdentifier("toast.dismiss")
        }
        .accessibilityElement(children: .contain).accessibilityIdentifier("toast.notice")
        .accessibilityAction(.escape) { self.message = nil }
    }

    func body(content: Content) -> some View {
        content.overlay {
            if let message {
                GeometryReader { geometry in
                    ViewThatFits(in: .vertical) {
                        notice(message).fixedSize(horizontal: false, vertical: true)
                        ScrollView { notice(message) }.scrollBounceBehavior(.basedOnSize)
                    }
                    .frame(maxWidth: 330, maxHeight: max(0, geometry.size.height - 32))
                    .padding(.horizontal, 20)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
        }
        .task(id: message) {
            guard let shown = message else { return }
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            UIAccessibility.post(notification: .announcement, argument: "\(title). \(shown)")
            guard !UIAccessibility.isVoiceOverRunning else { return }
            do { try await Task.sleep(for: .seconds(7)) } catch { return }
            if message == shown && !UIAccessibility.isVoiceOverRunning { message = nil }
        }
    }
}

extension View {
    func wearwiseConfirmationToast(_ title: String, isPresented: Binding<Bool>,
                                  message: String? = nil, onConfirm: @escaping () -> Void) -> some View {
        modifier(WearwiseConfirmationToast(isPresented: isPresented, title: title, message: message,
            onConfirm: onConfirm))
    }

    func wearwiseErrorToast(_ title: String, message: Binding<String?>) -> some View {
        modifier(WearwiseErrorToast(title: title, message: message))
    }

    func wearwiseDiscardConfirmation(isPresented: Binding<Bool>, title: String = "Discard your changes?",
                                     onDiscard: @escaping () -> Void) -> some View {
        wearwiseConfirmationToast(title, isPresented: isPresented, onConfirm: onDiscard)
    }
}

struct BrandNoteField: View {
    let title: String
    @Binding var text: String
    var identifier = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline.weight(.medium))
            TextField("", text: $text, axis: .vertical).lineLimit(2...4)
                .font(.subheadline).padding(12)
                .background(Color.imageMount, in: RoundedRectangle(cornerRadius: WearwiseRadius.small))
                .accessibilityLabel(title).accessibilityIdentifier(identifier)
        }.padding(.vertical, 4)
    }
}

private struct WearwiseCurrencyKey: EnvironmentKey {
    static let defaultValue = ""
}

extension EnvironmentValues {
    var wearwiseCurrency: String {
        get { self[WearwiseCurrencyKey.self] }
        set { self[WearwiseCurrencyKey.self] = newValue }
    }
}

extension Notification.Name {
    static let wearwiseDefaultsChanged = Notification.Name("WearwiseDefaultsChanged")
}

enum MoneyText {
    static func format(_ amount: Decimal, currency: String) -> String {
        let number = amount.formatted(.number.precision(.fractionLength(0...2)))
        return currency.isEmpty ? number : "\(number) \(currency)"
    }
}

private struct WearwiseKeyboardDismissModifier: ViewModifier {
    @State private var keyboardShown = false

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if keyboardShown {
                    HStack {
                        Spacer()
                        Button("Done") {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                        .font(.body.weight(.semibold)).buttonStyle(.plain)
                        .frame(minWidth: 64, minHeight: 44)
                        .accessibilityIdentifier("keyboard.done")
                    }
                    .padding(.horizontal, 16)
                    .foregroundStyle(Color.accentText).background(Color.paperSurface)
                    .overlay(alignment: .top) { Divider() }
                }
            }
            .background {
                KeyboardPageVisibility { keyboardShown = $0 }.frame(width: 0, height: 0)
            }
    }
}

private struct KeyboardPageVisibility: UIViewControllerRepresentable {
    var onChange: (Bool) -> Void

    func makeUIViewController(context: Context) -> Observer {
        let controller = Observer()
        controller.onChange = onChange
        return controller
    }

    func updateUIViewController(_ controller: Observer, context: Context) {
        controller.onChange = onChange
    }

    final class Observer: UIViewController {
        var onChange: (Bool) -> Void = { _ in }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.isUserInteractionEnabled = false
            let center = NotificationCenter.default
            center.addObserver(self, selector: #selector(showKeyboard), name: UIResponder.keyboardWillShowNotification, object: nil)
            center.addObserver(self, selector: #selector(hideKeyboard), name: UIResponder.keyboardWillHideNotification, object: nil)
        }

        override func viewDidDisappear(_ animated: Bool) {
            super.viewDidDisappear(animated)
            onChange(false)
        }

        deinit { NotificationCenter.default.removeObserver(self) }

        @objc private func showKeyboard() {
            guard view.window != nil else { return }
            var ancestor = parent
            while let controller = ancestor {
                // A covered page must not add another control row behind its presented sheet.
                if controller.presentedViewController != nil { return }
                ancestor = controller.parent
            }
            onChange(true)
        }

        @objc private func hideKeyboard() { onChange(false) }
    }
}

extension View {
    func wearwiseKeyboardDismissal() -> some View { modifier(WearwiseKeyboardDismissModifier()) }
}

private struct WearwiseDefaultsKey: EnvironmentKey {
    static let defaultValue = WardrobeDefaults()
}

extension EnvironmentValues {
    var wearwiseDefaults: WardrobeDefaults {
        get { self[WearwiseDefaultsKey.self] }
        set { self[WearwiseDefaultsKey.self] = newValue }
    }
}

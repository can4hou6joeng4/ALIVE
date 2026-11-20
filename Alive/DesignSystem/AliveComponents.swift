import AliveCore
import SwiftUI
import UIKit

/// Large system-font amount with fixed currency formatting.
struct AmountText: View {
    let cents: Decimal
    var size: CGFloat = 58
    var color: Color = AliveColor.ink
    var alignment: TextAlignment = .leading
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isAccessibilitySize: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        Text(MoneyFormatter.currency(cents: cents))
            .font(AliveFont.display(size))
            .monospacedDigit()
            .tracking(isAccessibilitySize ? 0 : -0.035 * size)
            .foregroundStyle(color)
            .multilineTextAlignment(alignment)
            .lineLimit(1)
            .minimumScaleFactor(isAccessibilitySize ? 0.35 : 0.62)
            .fixedSize(horizontal: false, vertical: true)
            .contentTransition(reduceMotion ? .identity : .numericText())
            .accessibilityLabel(MoneyFormatter.spoken(cents: cents))
    }
}

struct StatusPill: View {
    let title: String
    var isEmphasized = false

    var body: some View {
        Text(title)
            .font(AliveFont.sans(12, weight: .semibold, relativeTo: .footnote))
            .foregroundStyle(isEmphasized ? AliveColor.overspend : AliveColor.inkSecondary)
            .lineLimit(1)
            .padding(.horizontal, AliveSpace.x3)
            .padding(.vertical, AliveSpace.x2)
            .background(
                Capsule().fill(isEmphasized ? AliveColor.overspend.opacity(0.12) : AliveColor.surfaceSunken)
            )
            .accessibilityLabel(title)
    }
}

struct BudgetProgress: View {
    let progress: Double
    var isOverspent = false

    private var clamped: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(AliveColor.surfaceSunken)
                Capsule()
                    .fill(isOverspent ? AliveColor.overspend : AliveColor.progress)
                    .frame(width: proxy.size.width * clamped)
            }
        }
        .frame(height: 8)
    }
}

/// Draws a label exactly as designed, dipping its opacity only while pressed.
///
/// `.plain` also dims a disabled label. The action capsules define their own
/// disabled colors; dimming those again washes the title out and lets content
/// scrolled behind a floating bar show through the capsule.
private struct SolidButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

struct PrimaryAction: View {
    let title: String
    var systemImage: String?
    var isBusy = false
    var action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: AliveSpace.x2) {
                if isBusy {
                    ProgressView()
                        .tint(isEnabled ? .white : AliveColor.inkTertiary)
                        .controlSize(.small)
                        .accessibilityHidden(true)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .semibold))
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(AliveFont.sans(16, weight: .semibold, relativeTo: .headline))
            }
            .foregroundStyle(isEnabled ? Color.white : AliveColor.inkTertiary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .padding(.horizontal, AliveSpace.x4)
            .background(
                Capsule().fill(isEnabled ? AliveColor.accentFill : AliveColor.surfaceSunken)
            )
            .overlay {
                Capsule().stroke(isEnabled ? Color.clear : AliveColor.separator, lineWidth: 0.5)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(SolidButtonStyle())
        .disabled(isBusy || !isEnabled)
    }
}

/// Circular Liquid Glass icon action for floating top chrome.
struct GlassIconButton: View {
    let systemName: String
    let accessibilityLabel: String
    var accessibilityValue: String = ""
    var accessibilityHint: String = ""
    var isEnabled = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 44, height: 44)
                .contentShape(Circle())
                .glassEffect(.regular.interactive(), in: Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(AliveColor.ink)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.44)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(accessibilityHint)
    }
}

/// Single-surface icon action for the top navigation chrome.
///
/// The glass treatment adds an inner rim and highlight that reads as a second
/// button at toolbar size. Top chrome uses one tonal surface instead; Liquid
/// Glass stays reserved for floating interaction layers.
struct TopChromeIconButton: View {
    let systemName: String
    let accessibilityLabel: String
    var accessibilityValue: String = ""
    var accessibilityHint: String = ""
    var isEnabled = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 44, height: 44)
                .contentShape(Circle())
                .background(Circle().fill(AliveColor.surfaceElevated))
        }
        .buttonStyle(.plain)
        .foregroundStyle(AliveColor.ink)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.44)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(accessibilityHint)
    }
}

extension DynamicTypeSize {
    /// Largest text size for controls that can neither wrap nor shrink: the floating
    /// action bar and the system date picker. Content text keeps the full scale.
    ///
    /// A compact `DatePicker` is exactly as wide as its date. Above this size the
    /// date alone is wider than a card and pushes the whole page off both screen edges.
    static let aliveControlLimit: DynamicTypeSize = .accessibility2
}

/// Floating glass action area above the home indicator or keyboard.
struct GlassActionBar<Content: View>: View {
    let content: Content
    var axis: Axis = .horizontal

    init(axis: Axis = .horizontal, @ViewBuilder content: () -> Content) {
        self.axis = axis
        self.content = content()
    }

    private var layout: AnyLayout {
        axis == .horizontal
            ? AnyLayout(HStackLayout(spacing: AliveSpace.x2))
            : AnyLayout(VStackLayout(spacing: AliveSpace.x2))
    }

    var body: some View {
        GlassEffectContainer(spacing: AliveSpace.x2) {
            layout {
                content
            }
            // Keep the floating controls usable at the largest accessibility sizes;
            // the scrollable content still uses the full Dynamic Type scale.
            .dynamicTypeSize(...DynamicTypeSize.aliveControlLimit)
            .padding(.horizontal, AliveSpace.pageInset)
            .padding(.top, AliveSpace.x2)
            .padding(.bottom, AliveSpace.x1)
            .frame(maxWidth: .infinity)
        }
        .background {
            LinearGradient(
                stops: [
                    .init(color: AliveColor.canvas.opacity(0), location: 0),
                    .init(color: AliveColor.canvas, location: 0.55)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
            .allowsHitTesting(false)
        }
    }
}

struct GlassActionButton: View {
    let title: String
    var systemImage: String?
    var isProminent = false
    var isBusy = false
    var accessibilityHint: String = ""
    var action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    private var fill: Color {
        if !isEnabled { return AliveColor.surfaceSunken }
        return isProminent ? AliveColor.accentFill : AliveColor.surfaceElevated
    }

    private var contentColor: Color {
        if !isEnabled { return AliveColor.inkTertiary }
        return isProminent ? Color.white : AliveColor.ink
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: AliveSpace.x2) {
                if isBusy {
                    ProgressView()
                        .tint(contentColor)
                        .controlSize(.small)
                        .accessibilityHidden(true)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .semibold))
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(AliveFont.sans(15, weight: .semibold, relativeTo: .headline))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(contentColor)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AliveSpace.x4)
            .padding(.vertical, AliveSpace.x3)
            .frame(minHeight: 50)
            .background(Capsule().fill(fill))
            .overlay {
                Capsule().stroke(
                    isEnabled && !isProminent ? AliveColor.separator : Color.clear,
                    lineWidth: 0.5
                )
            }
            .contentShape(Capsule())
        }
        .buttonStyle(SolidButtonStyle())
        .disabled(isBusy || !isEnabled)
        .accessibilityHint(accessibilityHint)
    }
}

/// The app's only keyboard dismissal control; shown while a field has focus,
/// in the `GlassActionBar` above the keyboard or next to the field.
///
/// It replaces `ToolbarItemGroup(placement: .keyboard)`, which must not be used:
/// a keyboard toolbar leaves the keyboard safe area wrong until the next key
/// press — on its own screen and on the next keyboard shown after it — so a
/// bottom action bar ends up under the keyboard or under the toolbar.
struct KeyboardDismissButton: View {
    var action: () -> Void

    var body: some View {
        GlassIconButton(
            systemName: "keyboard.chevron.compact.down",
            accessibilityLabel: "收起键盘",
            action: action
        )
    }
}

struct GhostButton: View {
    let title: String
    var isEnabled = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AliveFont.sans(14, weight: .medium, relativeTo: .subheadline))
                .foregroundStyle(isEnabled ? AliveColor.accent : AliveColor.inkTertiary)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

struct ModalCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(AliveColor.ink)
        .accessibilityLabel("关闭")
    }
}

struct SheetHeader: View {
    let title: String
    var close: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: AliveSpace.x2) {
            Text(title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(AliveColor.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: AliveSpace.x3)

            ModalCloseButton(action: close)
        }
        .padding(.bottom, AliveSpace.x3)
    }
}

struct FieldLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(AliveFont.sans(13, weight: .semibold, relativeTo: .footnote))
            .foregroundStyle(AliveColor.inkSecondary)
            .accessibilityHidden(true)
    }
}

struct InlineError: View {
    let message: String?

    var body: some View {
        if let message {
            Text(message)
                .font(AliveFont.sans(13, weight: .medium, relativeTo: .footnote))
                .foregroundStyle(AliveColor.overspend)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("错误：\(message)")
                .onAppear { announce(message) }
                .onChange(of: message) { _, newValue in announce(newValue) }
        }
    }

    private func announce(_ text: String) {
        Task { @MainActor in
            UIAccessibility.post(notification: .announcement, argument: text)
        }
    }
}

/// Reusable grouped card container for native card-flow layouts.
struct SurfaceCard<Content: View>: View {
    var padding: CGFloat = AliveSpace.x5
    let content: Content

    init(padding: CGFloat = AliveSpace.x5, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: AliveRadius.card, style: .continuous)
                    .fill(AliveColor.card)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AliveRadius.card, style: .continuous)
                    .stroke(AliveColor.separator, lineWidth: 0.5)
            }
    }
}

private struct NativeBackground: View {
    var body: some View {
        AliveColor.canvas
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

extension View {
    func aliveScreenBackground() -> some View {
        background(NativeBackground())
    }
}

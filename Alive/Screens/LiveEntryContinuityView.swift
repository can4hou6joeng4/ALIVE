import AliveCore
import SwiftUI

/// The in-app continuation of the Live Activity's "记一笔" action.
///
/// iOS cannot host a `TextField` inside a Live Activity. When the activity's
/// link opens `alive://live-entry`, this layer hides the Today screen, keeps a
/// compact activity summary pinned to the top, and unfolds the quick-entry card
/// directly underneath it. The user still enters ALIVE, but the visual context
/// stays at the top of the screen instead of revealing the full Today page.
struct LiveEntryContinuityView: View {
    let model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption2) private var brandTextSize: CGFloat = 10
    @ScaledMetric(relativeTo: .caption) private var metaTextSize: CGFloat = 11
    @ScaledMetric(relativeTo: .footnote) private var statusTextSize: CGFloat = 13

    private var headerHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 76 : 44
    }

    var body: some View {
        GeometryReader { proxy in
            let maxCardHeight = max(
                0,
                proxy.size.height
                    - headerHeight
                    - AliveSpace.x2 * 3
            )

            VStack(spacing: AliveSpace.x2) {
                if let snapshot = model.snapshot {
                    continuityHeader(snapshot)
                }

                QuickEntryCard(model: model, fillsAvailableHeight: true)
                    .frame(maxHeight: maxCardHeight, alignment: .top)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, AliveSpace.pageInset)
            .padding(.top, AliveSpace.x2)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(AliveColor.canvas.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("live-entry-continuity")
    }

    private func continuityHeader(_ snapshot: BudgetSnapshot) -> some View {
        let state = snapshot.displayState
        let amountColor = state.isOverspent ? ContinuityColor.overspend : Color.white

        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AliveSpace.x1) {
                    HStack(spacing: AliveSpace.x2) {
                        brand
                        activityLabel
                        Spacer(minLength: AliveSpace.x2)
                        daysLabel(snapshot)
                    }

                    HStack(alignment: .firstTextBaseline, spacing: AliveSpace.x1) {
                        Text(state.label)
                            .foregroundStyle(Color.white.opacity(0.68))
                        Text(continuityAmount(state))
                            .foregroundStyle(amountColor)
                            .monospacedDigit()
                        Spacer(minLength: 0)
                    }
                    .font(.system(size: min(statusTextSize, 18), weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                }
                .padding(.vertical, AliveSpace.x2)
            } else {
                HStack(spacing: AliveSpace.x2) {
                    brand
                    activityLabel
                    Spacer(minLength: AliveSpace.x2)

                    HStack(alignment: .firstTextBaseline, spacing: AliveSpace.x1) {
                        Text(state.label)
                            .foregroundStyle(Color.white.opacity(0.68))
                        Text(continuityAmount(state))
                            .foregroundStyle(amountColor)
                            .monospacedDigit()
                    }
                    .font(.system(size: min(statusTextSize, 18), weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                    daysLabel(snapshot)
                }
            }
        }
        .padding(.horizontal, AliveSpace.x4)
        .frame(maxWidth: .infinity)
        .frame(minHeight: headerHeight)
        .background(Capsule(style: .continuous).fill(Color.black))
        .overlay {
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "实时活动记账层。\(state.label) \(MoneyFormatter.spoken(cents: state.amountCents))，余额 \(MoneyFormatter.spoken(cents: Decimal(snapshot.currentBalanceCents)))，\(snapshot.daysRemaining) 天后发薪。"
        )
        .accessibilityAddTraits(.isHeader)
    }

    private var brand: some View {
        Text("ALIVE")
            .font(.system(size: min(brandTextSize, 14), weight: .semibold))
            .tracking(1.5)
            .foregroundStyle(ContinuityColor.accent)
            .lineLimit(1)
    }

    private var activityLabel: some View {
        Text("实时活动")
            .font(.system(size: min(metaTextSize, 15), weight: .medium))
            .foregroundStyle(Color.white.opacity(0.68))
            .lineLimit(1)
    }

    private func daysLabel(_ snapshot: BudgetSnapshot) -> some View {
        Text("\(snapshot.daysRemaining) 天")
            .font(.system(size: min(metaTextSize, 15), weight: .medium))
            .foregroundStyle(Color.white.opacity(0.68))
            .monospacedDigit()
            .lineLimit(1)
    }

    private func continuityAmount(_ state: BudgetDisplayState) -> String {
        state.isZeroBalance ? "—" : MoneyFormatter.currency(cents: state.amountCents)
    }
}

private enum ContinuityColor {
    static let accent = Color(red: 10 / 255, green: 132 / 255, blue: 255 / 255)
    static let overspend = Color(red: 1, green: 154 / 255, blue: 138 / 255)
}

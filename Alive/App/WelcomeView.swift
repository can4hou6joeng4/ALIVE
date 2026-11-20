import AliveCore
import SwiftUI

/// A short, in-app brand transition. It never reads or displays financial data.
struct WelcomeView: View {
    let onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var focusSize: CGFloat = 168
    @State private var cardIsVisible = false
    @State private var progress: CGFloat = 0
    @State private var brandIsVisible = false
    @State private var taglineIsVisible = false
    @State private var containerOpacity = 1.0

    private let dayBars: [CGFloat] = [18, 26, 22, 34, 28, 40, 32]

    var body: some View {
        GeometryReader { proxy in
            let size = min(focusSize, max(120, proxy.size.width - 96))

            ZStack {
                AliveColor.canvas.ignoresSafeArea()

                RadialGradient(
                    gradient: Gradient(colors: [
                        AliveColor.accent.opacity(0.16),
                        AliveColor.accent.opacity(0)
                    ]),
                    center: UnitPoint(x: 0.5, y: 0.38),
                    startRadius: 16,
                    endRadius: 320
                )
                .ignoresSafeArea()
                .accessibilityHidden(true)

                VStack(spacing: AliveSpace.x8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .fill(AliveColor.surfaceElevated)
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(AliveColor.separator, lineWidth: 0.5)

                        VStack(spacing: AliveSpace.x5) {
                            HStack(alignment: .bottom, spacing: AliveSpace.x2) {
                                ForEach(Array(dayBars.enumerated()), id: \.offset) { _, height in
                                    Capsule()
                                        .fill(AliveColor.accent.opacity(0.72))
                                        .frame(width: 8, height: height)
                                }
                            }

                            GeometryReader { bar in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(AliveColor.surfaceSunken)
                                    Capsule()
                                        .fill(AliveColor.accentFill)
                                        .frame(width: bar.size.width * progress)
                                }
                            }
                            .frame(height: 6)
                            .padding(.horizontal, AliveSpace.x5)
                        }
                    }
                    .frame(width: size, height: size)
                    .scaleEffect(cardIsVisible ? 1 : 0.94)
                    .opacity(cardIsVisible ? 1 : 0)
                    .shadow(color: .black.opacity(0.08), radius: 20, y: 8)
                    .accessibilityHidden(true)

                    VStack(spacing: AliveSpace.x2) {
                        Text("ALIVE")
                            .font(AliveFont.sans(34, weight: .heavy, relativeTo: .title))
                            .tracking(6)
                            .foregroundStyle(AliveColor.ink)
                        Text("让余额活到发薪日")
                            .font(AliveFont.sans(15, weight: .medium, relativeTo: .body))
                            .foregroundStyle(AliveColor.inkSecondary)
                    }
                    .opacity(brandIsVisible && taglineIsVisible ? 1 : 0)
                }
                .padding(.bottom, AliveSpace.x10)

                VStack {
                    Spacer()
                    Button(action: onComplete) {
                        Text("跳过")
                            .font(AliveFont.sans(13, weight: .medium, relativeTo: .footnote))
                            .foregroundStyle(AliveColor.inkTertiary)
                            .frame(minHeight: 44)
                            .padding(.horizontal, AliveSpace.x5)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("跳过开屏")
                }
            }
            .opacity(containerOpacity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("ALIVE，让余额活到发薪日")
            .accessibilityHint("点击或轻点跳过可进入应用。")
            .contentShape(Rectangle())
            .onTapGesture(perform: onComplete)
            .accessibilityAction(.escape, onComplete)
        }
        .task {
            await runIntro()
        }
    }

    @MainActor
    private func runIntro() async {
        if reduceMotion {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                cardIsVisible = true
                progress = 1
                brandIsVisible = true
                taglineIsVisible = true
            }
            try? await Task.sleep(for: .milliseconds(150))
            onComplete()
            return
        }

        do {
            await Task.yield()
            try Task.checkCancellation()

            withAnimation(.easeOut(duration: 0.40)) { cardIsVisible = true }
            try await Task.sleep(for: .milliseconds(120))

            withAnimation(.timingCurve(0.22, 0.7, 0.18, 1, duration: 0.60)) { progress = 1 }
            try await Task.sleep(for: .milliseconds(180))

            withAnimation(.easeOut(duration: 0.30)) { brandIsVisible = true }
            try await Task.sleep(for: .milliseconds(120))

            withAnimation(.easeOut(duration: 0.30)) { taglineIsVisible = true }
            try await Task.sleep(for: .milliseconds(250))

            withAnimation(.easeInOut(duration: 0.35)) { containerOpacity = 0 }
            try await Task.sleep(for: .milliseconds(360))

            try Task.checkCancellation()
            onComplete()
        } catch {
            // Parent removal cancels this sequence.
        }
    }
}

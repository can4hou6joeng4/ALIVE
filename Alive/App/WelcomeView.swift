import AliveCore
import SwiftUI

/// A short, in-app brand transition. It never reads or displays financial data.
struct WelcomeView: View {
    let onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var focusSize: CGFloat = 168
    @State private var cardIsVisible = false
    @State private var progress: CGFloat = 0
    @State private var dotIsVisible = false
    @State private var brandIsVisible = false
    @State private var taglineIsVisible = false
    @State private var containerOpacity = 1.0

    var body: some View {
        GeometryReader { proxy in
            let size = min(focusSize, max(120, proxy.size.width - 96))

            ZStack {
                AliveColor.canvas.ignoresSafeArea()

                RadialGradient(
                    gradient: Gradient(colors: [
                        AliveColor.accent.opacity(0.18),
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
                        RoundedRectangle(cornerRadius: 36, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 14 / 255, green: 21 / 255, blue: 37 / 255),
                                        Color(red: 7 / 255, green: 11 / 255, blue: 20 / 255)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        RoundedRectangle(cornerRadius: 36, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 0.75)

                        RadialGradient(
                            gradient: Gradient(colors: [
                                AliveColor.accent.opacity(0.28),
                                AliveColor.accent.opacity(0)
                            ]),
                            center: .center,
                            startRadius: 4,
                            endRadius: size * 0.48
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))

                        ZStack {
                            WelcomeRibbonShape()
                                .trim(from: 0, to: progress)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            .white,
                                            Color(red: 112 / 255, green: 215 / 255, blue: 1),
                                            Color(red: 10 / 255, green: 132 / 255, blue: 1)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    style: StrokeStyle(
                                        lineWidth: max(6, size * 0.056),
                                        lineCap: .round,
                                        lineJoin: .round
                                    )
                                )
                                .shadow(color: AliveColor.accent.opacity(0.6), radius: 10)

                            Circle()
                                .fill(Color(red: 112 / 255, green: 215 / 255, blue: 1))
                                .frame(width: max(6, size * 0.056), height: max(6, size * 0.056))
                                .shadow(color: AliveColor.accent.opacity(0.85), radius: 6)
                                .offset(y: -size * 0.21)
                                .scaleEffect(dotIsVisible ? 1 : 0.2)
                                .opacity(dotIsVisible ? 1 : 0)
                        }
                        .padding(size * 0.18)
                    }
                    .frame(width: size, height: size)
                    .scaleEffect(cardIsVisible ? 1 : 0.94)
                    .opacity(cardIsVisible ? 1 : 0)
                    .shadow(color: .black.opacity(0.16), radius: 24, y: 10)
                    .accessibilityHidden(true)

                    VStack(spacing: AliveSpace.x2) {
                        Text("ALIVE")
                            .font(AliveFont.sans(34, weight: .heavy, relativeTo: .title))
                            .tracking(6)
                            .foregroundStyle(AliveColor.ink)
                            .opacity(brandIsVisible ? 1 : 0)
                        Text("让余额活到发薪日")
                            .font(AliveFont.sans(15, weight: .medium, relativeTo: .body))
                            .foregroundStyle(AliveColor.inkSecondary)
                            .opacity(taglineIsVisible ? 1 : 0)
                    }
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
                dotIsVisible = true
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

            withAnimation(.easeOut(duration: 0.36)) { cardIsVisible = true }
            try await Task.sleep(for: .milliseconds(100))

            withAnimation(.timingCurve(0.22, 0.7, 0.18, 1, duration: 0.56)) { progress = 1 }
            try await Task.sleep(for: .milliseconds(260))

            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { dotIsVisible = true }
            withAnimation(.easeOut(duration: 0.28)) { brandIsVisible = true }
            try await Task.sleep(for: .milliseconds(110))

            withAnimation(.easeOut(duration: 0.28)) { taglineIsVisible = true }
            try await Task.sleep(for: .milliseconds(240))

            withAnimation(.easeInOut(duration: 0.32)) { containerOpacity = 0 }
            try await Task.sleep(for: .milliseconds(340))

            try Task.checkCancellation()
            onComplete()
        } catch {
            // Parent removal cancels this sequence.
        }
    }
}

private struct WelcomeRibbonShape: Shape {
    func path(in rect: CGRect) -> Path {
        func pt(_ nx: CGFloat, _ ny: CGFloat) -> CGPoint {
            CGPoint(
                x: rect.minX + nx * rect.width,
                y: rect.minY + (1 - ny) * rect.height
            )
        }

        var path = Path()
        path.move(to: pt(0.05, 0.22))
        path.addCurve(to: pt(0.23, 0.78), control1: pt(0.11, 0.40), control2: pt(0.16, 0.78))
        path.addCurve(to: pt(0.39, 0.22), control1: pt(0.29, 0.78), control2: pt(0.33, 0.22))
        path.addCurve(to: pt(0.55, 0.69), control1: pt(0.45, 0.22), control2: pt(0.49, 0.69))
        path.addCurve(to: pt(0.71, 0.22), control1: pt(0.60, 0.69), control2: pt(0.65, 0.22))
        path.addCurve(to: pt(0.90, 0.71), control1: pt(0.78, 0.22), control2: pt(0.82, 0.71))
        path.addCurve(to: pt(0.97, 0.56), control1: pt(0.95, 0.71), control2: pt(0.97, 0.64))
        path.addCurve(to: pt(0.84, 0.41), control1: pt(0.97, 0.46), control2: pt(0.91, 0.41))
        return path
    }
}

import SwiftUI

/// The lensing drag puck (glass moment #2 / motion grammar #6): a small glass drop that
/// refracts the cover beneath the active drag. Geometry is the pure `LensingPuck` value;
/// this view is only its glass rendering — an interactive glass circle with an `aqua`
/// meniscus edge, plus the Reduce Transparency opaque fallback (apple/CLAUDE.md
/// §Accessibility). Decorative and non-interactive: it never takes hits.
struct LensingPuckView: View {
    let puck: LensingPuck
    var reduceTransparency: Bool = false

    var body: some View {
        lens
            .frame(width: puck.diameter, height: puck.diameter)
            .position(puck.center)
            .opacity(puck.opacity)
            // Position tracks the finger directly; only the fade in/out is animated.
            .animation(.easeOut(duration: 0.16), value: puck.opacity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var lens: some View {
        if reduceTransparency {
            // Token-tinted matte stand-in — no refraction, but the focus point still reads.
            Circle()
                .fill(Palette.surface.opacity(0.55))
                .overlay(Circle().strokeBorder(Palette.sky.opacity(0.5), lineWidth: 1))
        } else {
            Color.clear
                .glassEffect(
                    .regular.tint(Palette.sky.opacity(0.14)).interactive(),
                    in: Circle()
                )
                // Meniscus rim — the glass drop's bulged edge (glass-meniscus grammar).
                .overlay(Circle().strokeBorder(Palette.aqua.opacity(0.32), lineWidth: 1))
        }
    }
}

#Preview("Lensing puck — over a cover (dark)") {
    ZStack {
        Palette.canvas.ignoresSafeArea()
        HardbackCoverView(book: BookSeed.shelf[3])
            .frame(width: 320)
        LensingPuckView(
            puck: LensingPuck.at(location: CGPoint(x: 200, y: 300), dragSpeed: 240, in: CGSize(width: 393, height: 600))
        )
    }
    .frame(width: 393, height: 600)
    .preferredColorScheme(.dark)
}

import SwiftUI

/// The figure overlay's glass carrier card (V20; glass moment #8) — the figure under
/// discussion floats over the reading body on glass: the FRAME is glass (aqua tint —
/// it's the live/active moment), the figure image itself stays matte paper (the rule's
/// one sanctioned content-adjacent glass case). When several spans overlap the cards
/// stack — backing edges peek behind the top card and chevrons page through, wrapping.
/// Parameterized (not self-tracking) so it renders identically live and in snapshots.
struct FigureCarrierView: View {
    /// The figures active at the playhead, in span order. Must be non-empty.
    let figures: [FigureDTO]
    /// Which stacked figure is on top (`FigureOverlaySelection.index`).
    let selectedIndex: Int
    /// Cached figure images keyed by source block id (`PlayerController.blockImages`).
    var images: [String: Image] = [:]
    var reduceTransparency: Bool = false
    var onPrevious: () -> Void = {}
    var onNext: () -> Void = {}

    @ScaledMetric(relativeTo: .caption) private var labelSize: CGFloat = 12
    @ScaledMetric(relativeTo: .body) private var captionSize: CGFloat = 15

    private var figure: FigureDTO {
        figures[min(max(selectedIndex, 0), figures.count - 1)]
    }

    var body: some View {
        card
            .background(alignment: .bottom) { stackHint }
            .accessibilityElement(children: .contain)
    }

    /// The top card: matte figure content in a glass frame.
    private var card: some View {
        VStack(spacing: 10) {
            content
            footer
        }
        .padding(12)
        .background {
            let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
            if reduceTransparency {
                // Opaque fallback (apple/CLAUDE.md §Accessibility): token-tinted matte.
                shape.fill(Palette.surface)
                    .overlay(shape.strokeBorder(Palette.aqua.opacity(0.5), lineWidth: 1))
            } else {
                Color.clear.glassEffect(
                    .regular.tint(Palette.aqua.opacity(0.20)), in: shape
                )
            }
        }
    }

    /// The figure itself — matte paper (image, or its caption when no image is cached;
    /// best-effort parity with the downloader).
    @ViewBuilder
    private var content: some View {
        if let image = images[figure.figureId] {
            image
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 170)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
                .accessibilityLabel(figure.caption ?? figure.label ?? "Figure")
        } else if let caption = figure.caption, !caption.isEmpty {
            Text(caption)
                .font(.system(size: captionSize, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(Palette.textPrimary.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 6)
                .padding(.top, 4)
        }
    }

    /// Label line + the pager when spans overlap.
    private var footer: some View {
        HStack(spacing: 8) {
            Text(figure.label ?? figure.caption ?? "")
                .font(.system(size: labelSize, weight: .medium))
                .foregroundStyle(Palette.textPrimary.opacity(0.6))
                .lineLimit(1)
            Spacer(minLength: 0)
            if figures.count > 1 {
                pager
            }
        }
    }

    private var pager: some View {
        HStack(spacing: 6) {
            pageButton("chevron.left", label: "Previous figure", action: onPrevious)
            Text("\(selectedIndex + 1) / \(figures.count)")
                .font(.system(size: labelSize, weight: .medium).monospacedDigit())
                .foregroundStyle(Palette.textPrimary.opacity(0.75))
            pageButton("chevron.right", label: "Next figure", action: onNext)
        }
    }

    private func pageButton(
        _ symbol: String, label: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.textPrimary)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /// Stacked-spans hint: matte edges peeking from behind the top card (depth is
    /// scale + offset + shadow, never blur — apple/CLAUDE.md §Physical book rendering).
    @ViewBuilder
    private var stackHint: some View {
        if figures.count > 1 {
            ForEach(1..<min(figures.count, 3), id: \.self) { depth in
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Palette.surface.opacity(depth == 1 ? 0.85 : 0.55))
                    .scaleEffect(1 - 0.04 * CGFloat(depth), anchor: .bottom)
                    .offset(y: 7 * CGFloat(depth))
                    .zIndex(-Double(depth))
            }
        }
    }
}

#Preview("Figure carrier — caption only") {
    FigureCarrierView(
        figures: [
            FigureDTO(
                figureId: "f1", kind: "figure", asset: nil,
                caption: "The analytical engine's mill, as Lovelace sketched it.",
                label: "Figure 1", startPara: "p1", endPara: "p2",
                startMs: 0, endMs: 1000, image: nil
            ),
            FigureDTO(
                figureId: "f2", kind: "figure", asset: nil, caption: "Second",
                label: "Figure 2", startPara: "p3", endPara: "p4",
                startMs: 0, endMs: 1000, image: nil
            ),
        ],
        selectedIndex: 0
    )
    .frame(maxWidth: 380)
    .padding(40)
    .background(Palette.canvas)
    .preferredColorScheme(.dark)
}

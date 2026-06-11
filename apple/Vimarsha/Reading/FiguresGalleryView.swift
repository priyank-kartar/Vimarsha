import SwiftUI

/// The Figures gallery (V20; apple/CLAUDE.md §UI map state 4) — every figure in the
/// chapter regardless of timing, as a **morphed grid state of the reading surface**
/// (never a sheet): the paper body reflows into a grid of matte figure cards on the
/// same canvas. Selecting a figure jumps narration to where it's discussed (Flutter
/// `FiguresGallery` design ported). Content is paper — the cards are matte; only the
/// button that opened this state is glass.
struct FiguresGalleryView: View {
    let figures: [FigureDTO]
    /// Cached figure images keyed by source block id (`PlayerController.blockImages`).
    var images: [String: Image] = [:]
    /// Jump narration to the figure's span (and morph back to reading).
    var onSelect: ((FigureDTO) -> Void)?

    @ScaledMetric(relativeTo: .caption) private var labelSize: CGFloat = 10

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                Text("FIGURES")
                    .font(.system(size: labelSize, weight: .medium))
                    .tracking(4)
                    .foregroundStyle(Palette.textPrimary.opacity(0.55))
                    .padding(.top, 76)
                    .accessibilityAddTraits(.isHeader)
                FigureGridView(figures: figures, images: images, onSelect: onSelect)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 150)
            }
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
    }
}

/// The grid itself, extracted from the ScrollView so snapshots can render it directly
/// (`ImageRenderer` doesn't rasterize ScrollView content — the V14 gotcha).
struct FigureGridView: View {
    let figures: [FigureDTO]
    var images: [String: Image] = [:]
    var onSelect: ((FigureDTO) -> Void)?

    @ScaledMetric(relativeTo: .caption) private var labelSize: CGFloat = 12
    @ScaledMetric(relativeTo: .footnote) private var captionSize: CGFloat = 13

    var body: some View {
        if figures.isEmpty {
            Text("No figures in this chapter")
                .font(.system(size: captionSize))
                .foregroundStyle(Palette.textPrimary.opacity(0.55))
                .padding(.vertical, 40)
        } else {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 150), spacing: 14)],
                spacing: 14
            ) {
                ForEach(figures, id: \.figureId) { figure in
                    card(figure)
                }
            }
        }
    }

    private func card(_ figure: FigureDTO) -> some View {
        Button { onSelect?(figure) } label: {
            VStack(spacing: 8) {
                tile(figure)
                HStack(spacing: 5) {
                    Text(figure.label ?? figure.caption ?? figure.kind)
                        .font(.system(size: labelSize, weight: .medium))
                        .foregroundStyle(Palette.textPrimary.opacity(0.65))
                        .lineLimit(1)
                    if figure.startMs != nil {
                        // This figure has a narration span — selecting it seeks there.
                        Image(systemName: "waveform")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Palette.aqua.opacity(0.8))
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background {
                // Matte paper tile — depth from shadow, never glass (content rule).
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Palette.surface)
                    .shadow(color: .black.opacity(0.14), radius: 8, y: 4)
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(figure.label ?? figure.caption ?? "Figure")
        .accessibilityHint(
            figure.startMs != nil ? "Jumps narration to where it is discussed" : ""
        )
    }

    /// The figure content: matte image, or its caption as quiet serif when no image
    /// is cached (best-effort parity with the downloader).
    @ViewBuilder
    private func tile(_ figure: FigureDTO) -> some View {
        if let image = images[figure.figureId] {
            image
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 110)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            Text(figure.caption ?? "")
                .font(.system(size: captionSize, design: .serif))
                .italic()
                .foregroundStyle(Palette.textPrimary.opacity(0.8))
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .frame(maxWidth: .infinity, minHeight: 64)
        }
    }
}

#Preview("Figures gallery — dark") {
    FiguresGalleryView(
        figures: [
            FigureDTO(
                figureId: "f1", kind: "figure", asset: nil, caption: "The mill",
                label: "Figure 1", startPara: "p1", endPara: "p2",
                startMs: 0, endMs: 1000, image: nil
            ),
            FigureDTO(
                figureId: "f2", kind: "figure", asset: nil,
                caption: "The store, holding a thousand fifty-digit numbers.",
                label: "Figure 2", startPara: "p3", endPara: "p4",
                startMs: nil, endMs: nil, image: nil
            ),
        ]
    )
    .background(Palette.canvas)
    .preferredColorScheme(.dark)
}

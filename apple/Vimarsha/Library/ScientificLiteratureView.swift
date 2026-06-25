import SwiftUI

/// The second library section, swiped to from "My Books": scientific papers narrated with math
/// support — arXiv LaTeX source (and Z.AI GLM OCR for PDFs) → spoken equations + rendered LaTeX,
/// onto the same ChapterBundle pipeline as books. Phase 1 is the shell + empty state; ingestion
/// (arXiv fetch / PDF parse) lands next. Mirrors the My Books editorial header + palette.
struct ScientificLiteratureView: View {
    /// Add a paper — paste an arXiv link or share a PDF (wired in Phase 2).
    var onAddPaper: () -> Void = {}

    @ScaledMetric(relativeTo: .caption) private var labelSize: CGFloat = 10
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 40
    @ScaledMetric(relativeTo: .title) private var sectionSize: CGFloat = 28

    var body: some View {
        VStack(spacing: 0) {
            header.padding(.top, 64)
            Spacer(minLength: 0)
            emptyState
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.canvas.ignoresSafeArea())
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("VIMARSHA")
                .font(.system(size: titleSize, weight: .light, design: .serif))
                .tracking(6)
                .foregroundStyle(Palette.textPrimary.opacity(0.28))
            Text("RESEARCH")
                .font(.system(size: labelSize, weight: .medium))
                .tracking(4)
                .foregroundStyle(Palette.textPrimary.opacity(0.55))
            Text("SCIENTIFIC LITERATURE")
                .font(.system(size: sectionSize, weight: .regular, design: .serif))
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "function")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Palette.sky.opacity(0.8))
            Text("No papers yet")
                .font(.system(size: 19, weight: .regular, design: .serif))
                .foregroundStyle(Palette.textPrimary)
            Text("Paste an arXiv link or share a PDF — Vimarsha narrates the paper with the equations read aloud and rendered on screen.")
                .font(.system(size: 14))
                .foregroundStyle(Palette.textPrimary.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
            addButton
                .padding(.top, 4)
        }
    }

    private var addButton: some View {
        Button(action: onAddPaper) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                Text("Add a paper")
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Palette.textPrimary)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
        .background {
            Color.clear.glassEffect(.regular.tint(Palette.sky.opacity(0.26)).interactive(), in: .capsule)
        }
        .accessibilityLabel("Add a scientific paper")
    }
}

#Preview("Scientific Literature — dark") {
    ScientificLiteratureView()
        .preferredColorScheme(.dark)
}

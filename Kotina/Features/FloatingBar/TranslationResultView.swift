import SwiftUI

struct TranslationResultView: View {
    let result: TranslationResult
    var textScale: CGFloat = 1
    let copy: () -> Void
    @State private var isHovering = false

    var body: some View {
        translatedTextCard
            .padding(.horizontal, 18)
            .padding(.bottom, 16)
    }

    private var translatedTextCard: some View {
        Button(action: copy) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Text("번역된 문장")
                        .font(.caption.weight(.semibold))
                    Text("\(result.sourceLanguage.uppercased()) → \(result.targetLanguage.uppercased())")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                    Spacer()
                    if isHovering {
                        Label("누르면 복사", systemImage: "doc.on.doc")
                            .font(.caption2.weight(.semibold))
                            .transition(.opacity)
                    }
                }
                .foregroundStyle(.secondary)

                ScrollView {
                    Text(result.translatedText)
                        .font(.system(size: 17 * textScale, weight: .medium))
                        .lineSpacing(4)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                (isHovering ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(.ultraThinMaterial)),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(isHovering ? 0.28 : 0.16), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
        .help("번역문 복사")
        .accessibilityLabel("번역문 복사")
    }
}

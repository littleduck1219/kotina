import SwiftUI

struct SpellingResultView: View {
    let result: SpellingResult
    var textScale: CGFloat = 1
    let copy: () -> Void
    @State private var isHoveringCorrectedText = false

    var body: some View {
        correctedTextCard
            .padding(.horizontal, 18)
            .padding(.bottom, 16)
    }

    private var correctedTextCard: some View {
        Button(action: copy) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Text("교정된 문장")
                        .font(.caption.weight(.semibold))
                    if result.issues.isEmpty {
                        Label("확신할 수 있는 오류 없음", systemImage: "checkmark.circle.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                    Spacer()
                    if isHoveringCorrectedText {
                        Label("누르면 복사", systemImage: "doc.on.doc")
                            .font(.caption2.weight(.semibold))
                            .transition(.opacity)
                    }
                }
                .foregroundStyle(.secondary)

                ScrollView {
                    annotatedCorrectedText
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(14)
            .background(
                (isHoveringCorrectedText ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(.ultraThinMaterial)),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(isHoveringCorrectedText ? 0.28 : 0.16), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHoveringCorrectedText = hovering
            }
        }
        .help("교정문 복사")
        .accessibilityLabel("교정문 복사")
    }

    private var annotatedCorrectedText: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(annotatedSegments) { segment in
                if let original = segment.original {
                    VStack(spacing: 2) {
                        Text(original)
                            .font(.system(size: 10 * textScale, weight: .semibold))
                            .strikethrough()
                            .foregroundStyle(.red)
                        Text(segment.text)
                            .font(.system(size: 15 * textScale, weight: .semibold))
                            .foregroundStyle(.green)
                    }
                    .help(segment.reason ?? "")
                } else {
                    Text(segment.text)
                        .font(.system(size: 15 * textScale, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .lineLimit(2)
    }

    private var annotatedSegments: [CorrectedSegment] {
        var segments: [CorrectedSegment] = []
        var originalCursor = 0
        var correctedCursor = result.correctedText.startIndex

        for issue in result.issues {
            let unchangedCount = issue.range.lowerBound - originalCursor
            if unchangedCount > 0,
               let unchangedEnd = result.correctedText.index(
                correctedCursor,
                offsetBy: unchangedCount,
                limitedBy: result.correctedText.endIndex
               ) {
                segments.append(CorrectedSegment(text: String(result.correctedText[correctedCursor..<unchangedEnd])))
                correctedCursor = unchangedEnd
            }

            if let suggestionEnd = result.correctedText.index(
                correctedCursor,
                offsetBy: issue.suggestion.count,
                limitedBy: result.correctedText.endIndex
            ) {
                segments.append(
                    CorrectedSegment(
                        text: String(result.correctedText[correctedCursor..<suggestionEnd]),
                        original: issue.original,
                        reason: issue.reason
                    )
                )
                correctedCursor = suggestionEnd
            }
            originalCursor = issue.range.upperBound
        }

        if correctedCursor < result.correctedText.endIndex {
            segments.append(CorrectedSegment(text: String(result.correctedText[correctedCursor...])))
        }
        return segments
    }
}

private struct CorrectedSegment: Identifiable {
    let id = UUID()
    let text: String
    var original: String?
    var reason: String?
}

private extension View {
    func glassCard() -> some View {
        background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            }
    }
}

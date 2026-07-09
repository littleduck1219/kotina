import SwiftUI

struct SpellingResultView: View {
    let result: SpellingResult
    let copy: () -> Void
    @State private var isHoveringCorrectedText = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if result.issues.isEmpty {
                        Label("확신할 수 있는 오류를 찾지 못했어요", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.callout.weight(.medium))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .glassCard()
                    }

                    correctedTextCard
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 16)
    }

    private var correctedTextCard: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                Text("교정된 문장")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                annotatedCorrectedText
            }
            Spacer()
            Button(action: copy) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 15, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(.top, 22)
            .help("교정문 복사")
            .accessibilityLabel("교정문 복사")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            (isHoveringCorrectedText ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(.thinMaterial)),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(isHoveringCorrectedText ? 0.34 : 0.2), lineWidth: 1)
        }
        .onHover { isHoveringCorrectedText = $0 }
    }

    private var annotatedCorrectedText: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(annotatedSegments) { segment in
                if let original = segment.original {
                    VStack(spacing: 2) {
                        Text(original)
                            .font(.caption2.weight(.semibold))
                            .strikethrough()
                            .foregroundStyle(.red)
                        Text(segment.text)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                    .help(segment.reason ?? "")
                } else {
                    Text(segment.text)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
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

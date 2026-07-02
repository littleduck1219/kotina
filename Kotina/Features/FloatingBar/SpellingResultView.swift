import SwiftUI

struct SpellingResultView: View {
    let result: SpellingResult
    let copy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if result.issues.isEmpty {
                        Label("맞춤법 오류를 찾지 못했어요", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.callout.weight(.medium))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 12))
                    } else {
                        ForEach(Array(result.issues.enumerated()), id: \.offset) { _, issue in
                            VStack(alignment: .leading, spacing: 7) {
                                HStack(spacing: 8) {
                                    Text(issue.original)
                                        .strikethrough()
                                        .foregroundStyle(.red)
                                    Image(systemName: "arrow.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                    Text(issue.suggestion)
                                        .foregroundStyle(.green)
                                        .fontWeight(.semibold)
                                }
                                Text(issue.reason)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        Text("교정된 문장")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(result.correctedText)
                            .font(.body)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 12))
                }
            }

            HStack {
                Spacer()
                Button(action: copy) {
                    Label("교정문 복사", systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 16)
    }
}


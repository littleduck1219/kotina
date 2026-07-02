import SwiftUI

struct TranslationResultView: View {
    let result: TranslationResult
    let copy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("ENGLISH")
                            .font(.caption2.weight(.bold))
                            .tracking(1.2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(result.sourceLanguage.uppercased()) → \(result.targetLanguage.uppercased())")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.tertiary)
                    }
                    Text(result.translatedText)
                        .font(.system(size: 17, weight: .medium))
                        .lineSpacing(4)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
                .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 12))
            }

            HStack {
                Spacer()
                Button(action: copy) {
                    Label("번역문 복사", systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 16)
    }
}


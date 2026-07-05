import SwiftUI
import Translation

enum FloatingBarMetrics {
    static let horizontalInset: CGFloat = 10
    static let verticalInset: CGFloat = 4
    static let contentWidth = FloatingPanelLayout.width - horizontalInset * 2
    static let inputHeight = FloatingPanelLayout.collapsedHeight - verticalInset * 2
    static let resultHeight = FloatingPanelLayout.expandedHeight
        - FloatingPanelLayout.collapsedHeight
}

struct FloatingBarView: View {
    @Bindable var model: FloatingBarViewModel
    let expansionChanged: (Bool) -> Void

    var body: some View {
        VStack(spacing: 0) {
            inputBar

            if model.isExpanded {
                resultArea
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(width: FloatingBarMetrics.contentWidth, alignment: .top)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.28), radius: 20, y: 10)
        .padding(.horizontal, FloatingBarMetrics.horizontalInset)
        .padding(.vertical, FloatingBarMetrics.verticalInset)
        .animation(.snappy(duration: 0.22), value: model.isExpanded)
        .onChange(of: model.isExpanded) { _, expanded in
            expansionChanged(expanded)
        }
        .translationTask(model.translationConfiguration) { session in
            await model.handleTranslationSession(session)
        }
    }

    private var inputBar: some View {
        HStack(spacing: 12) {
            appMark

            TextField(
                "텍스트를 입력하거나 붙여넣으세요",
                text: $model.sourceText
            )
            .textFieldStyle(.plain)
            .font(.system(size: 15, weight: .medium))
            .accessibilityLabel("검사할 텍스트")

            if activeTabIsLoading {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("처리 중")
            }

            if !model.sourceText.isEmpty {
                Button(action: model.clear) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("입력 지우기")
            }

            Menu {
                Button("Kotina 종료", systemImage: "power", action: model.quit)
                    .keyboardShortcut("q")
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .help("Kotina 메뉴")
            .accessibilityLabel("Kotina 메뉴")
        }
        .frame(height: FloatingBarMetrics.inputHeight)
        .padding(.horizontal, 18)
    }

    private var appMark: some View {
        Image(systemName: "character.cursor.ibeam")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(
                Color.accentColor,
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
            .accessibilityHidden(true)
    }

    private var resultArea: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.35)

            HStack(spacing: 8) {
                tabButton(.spelling, title: spellingTabTitle)
                tabButton(.translation, title: "번역")
                Spacer()

                if let copyMessage = model.copyMessage {
                    Text(copyMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                        .accessibilityLabel(copyMessage)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)

            Group {
                if let validationMessage = model.validationMessage {
                    messageView(
                        icon: "exclamationmark.triangle.fill",
                        title: validationMessage,
                        actionTitle: nil,
                        action: nil
                    )
                } else {
                    selectedResult
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: FloatingBarMetrics.resultHeight)
    }

    @ViewBuilder
    private var selectedResult: some View {
        switch model.selectedTab {
        case .spelling:
            spellingContent
        case .translation:
            translationContent
        }
    }

    @ViewBuilder
    private var spellingContent: some View {
        switch model.spellingPhase {
        case .idle, .loading:
            loadingView("맞춤법을 살펴보고 있어요")
        case let .success(result):
            SpellingResultView(result: result, copy: model.copyCorrectedText)
        case let .failure(message):
            messageView(
                icon: "arrow.clockwise.circle.fill",
                title: message,
                actionTitle: "다시 검사",
                action: model.retrySpelling
            )
        }
    }

    @ViewBuilder
    private var translationContent: some View {
        switch model.translationPhase {
        case .idle, .checkingResources:
            loadingView("번역 언어를 확인하고 있어요")
        case .preparing:
            loadingView("번역 모델을 준비하고 있어요")
        case .translating:
            loadingView("영어로 옮기고 있어요")
        case .needsPreparation:
            messageView(
                icon: "arrow.down.circle.fill",
                title: "한국어→영어 번역 모델이 필요해요.",
                actionTitle: "번역 모델 준비",
                action: model.prepareTranslation
            )
        case let .success(result):
            TranslationResultView(result: result, copy: model.copyTranslation)
        case let .failure(message):
            messageView(
                icon: "arrow.clockwise.circle.fill",
                title: message,
                actionTitle: "다시 번역",
                action: model.retryTranslation
            )
        case .unavailable:
            messageView(
                icon: "xmark.circle.fill",
                title: "이 기기에서는 한국어→영어 번역을 사용할 수 없어요.",
                actionTitle: nil,
                action: nil
            )
        }
    }

    private var activeTabIsLoading: Bool {
        switch model.selectedTab {
        case .spelling:
            if case .loading = model.spellingPhase { return true }
        case .translation:
            switch model.translationPhase {
            case .checkingResources, .preparing, .translating:
                return true
            default:
                break
            }
        }
        return false
    }

    private var spellingTabTitle: String {
        let count = model.currentSpellingResult?.issues.count
        return count.map { "맞춤법 · \($0)" } ?? "맞춤법"
    }

    private func tabButton(_ tab: ResultTab, title: String) -> some View {
        Button {
            model.selectedTab = tab
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(model.selectedTab == tab ? .primary : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    model.selectedTab == tab
                        ? Color.primary.opacity(0.09)
                        : Color.clear,
                    in: RoundedRectangle(cornerRadius: 8)
                )
        }
        .buttonStyle(.plain)
    }

    private func loadingView(_ title: String) -> some View {
        VStack(spacing: 10) {
            ProgressView()
            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func messageView(
        icon: String,
        title: String,
        actionTitle: String?,
        action: (() -> Void)?
    ) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.callout)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
            }
        }
        .padding(24)
    }
}

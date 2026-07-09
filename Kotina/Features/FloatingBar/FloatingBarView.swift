import SwiftUI
import Translation

enum PanelResizeEvent {
    case began
    case changed(width: CGFloat, height: CGFloat)
    case ended
}

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
    let stayOnTopChanged: (Bool) -> Void
    let resizeEvent: (PanelResizeEvent) -> Void
    @State private var isHoveringModeButton = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            inputBar

            if model.isExpanded {
                resultArea
                    .transition(.opacity)
            }
        }
        // 접힘·펼침 애니메이션 중에도 입력 바가 창 상단에 고정되도록 세로로 꽉 채운 뒤 상단 정렬한다.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            GlassBackground(cornerRadius: 18)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.22), lineWidth: 1)
        }
        .overlay(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.09), .clear],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )
                .allowsHitTesting(false)
        }
        // 패널 여백(가로 10pt·세로 4pt)을 넘는 그림자는 사각형으로 잘려 보이므로 여백 안에 들어가게 유지한다.
        .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
        .padding(.horizontal, FloatingBarMetrics.horizontalInset)
        .padding(.vertical, FloatingBarMetrics.verticalInset)
        .overlay(alignment: .bottomTrailing) {
            resizeGrip
                .offset(x: 3, y: 3)
        }
        .onChange(of: model.isExpanded) { _, expanded in
            expansionChanged(expanded)
        }
        .onChange(of: model.staysOnTop) { _, staysOnTop in
            stayOnTopChanged(staysOnTop)
        }
        .translationTask(model.translationConfiguration) { session in
            await model.handleTranslationSession(session)
        }
    }

    private var inputBar: some View {
        HStack(spacing: 12) {
            modeButton

            TextField(
                "텍스트를 입력하거나 붙여넣으세요",
                text: $model.sourceText
            )
            .textFieldStyle(.plain)
            .font(.system(size: 15 * model.textSize.factor, weight: .medium))
            .focused($isInputFocused)
            // 편집 중이 아닐 때는 긴 텍스트를 지우기 버튼 앞에서 …으로 줄인다.
            .foregroundStyle(showsTruncatedInput ? AnyShapeStyle(.clear) : AnyShapeStyle(.primary))
            .overlay(alignment: .leading) {
                if showsTruncatedInput {
                    Text(model.sourceText)
                        .font(.system(size: 15 * model.textSize.factor, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .allowsHitTesting(false)
                }
            }
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
                Toggle("항상 위에 표시", isOn: $model.staysOnTop)
                Picker("글자 크기", selection: $model.textSize) {
                    ForEach(TextSizeOption.allCases, id: \.self) { option in
                        Text(option.label).tag(option)
                    }
                }
                Divider()
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

    private var modeButton: some View {
        Button(action: toggleModeAnimated) {
            Image(systemName: model.mode == .spelling ? "checkmark.seal.fill" : "globe")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(
                    model.mode == .spelling ? Color.accentColor : Color.indigo,
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHoveringModeButton = hovering
            }
        }
        // 레이아웃을 밀지 않도록 안내는 떠 있는 오버레이로 보여준다.
        .overlay(alignment: .leading) {
            if isHoveringModeButton {
                Text(model.mode == .spelling ? "번역 모드로 전환" : "맞춤법 모드로 전환")
                    .font(.caption.weight(.semibold))
                    .fixedSize()
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.regularMaterial, in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.22), lineWidth: 1))
                    .offset(x: 38)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .zIndex(1)
        .help(
            model.mode == .spelling
                ? "맞춤법 모드 · 누르면 번역 모드로 전환"
                : "번역 모드 · 누르면 맞춤법 모드로 전환"
        )
        .accessibilityLabel(
            model.mode == .spelling
                ? "맞춤법 모드, 누르면 번역 모드로 전환"
                : "번역 모드, 누르면 맞춤법 모드로 전환"
        )
    }

    private func toggleModeAnimated() {
        withAnimation(.easeInOut(duration: 0.15)) {
            model.toggleMode()
        }
    }

    private var resizeGrip: some View {
        PanelResizeGrip(onEvent: resizeEvent)
            .frame(width: 22, height: 22)
            .background(.ultraThinMaterial, in: Circle())
            .overlay {
                Circle()
                    .stroke(.white.opacity(0.24), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .overlay {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .allowsHitTesting(false)
            }
            .help("드래그해서 크기 조절")
            .accessibilityLabel("크기 조절")
    }

    private var resultArea: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.35)

            HStack(spacing: 8) {
                Text(modeTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
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
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private var selectedResult: some View {
        switch model.mode {
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
            SpellingResultView(
                result: result,
                textScale: model.textSize.factor,
                copy: model.copyCorrectedText
            )
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
            TranslationResultView(
                result: result,
                textScale: model.textSize.factor,
                copy: model.copyTranslation
            )
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
        switch model.mode {
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

    private var modeTitle: String {
        switch model.mode {
        case .spelling:
            let count = model.currentSpellingResult?.issues.count
            return count.map { "맞춤법 · \($0)" } ?? "맞춤법"
        case .translation:
            return "번역"
        }
    }

    private var showsTruncatedInput: Bool {
        !isInputFocused && !model.sourceText.isEmpty
    }

    private func loadingView(_ title: String) -> some View {
        VStack(spacing: 10) {
            ProgressView()
                .tint(.white)
            Text(title)
                .font(.callout)
                .foregroundStyle(.white)
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

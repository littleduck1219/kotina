# Floating Bar MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and verify a macOS 14+ A-layout floating glass bar that accepts text, shows concurrent mocked spelling and translation results, and copies either result without passive focus theft.

**Architecture:** XcodeGen generates a native macOS app project. SwiftUI renders a single-column tabbed result view while an AppKit nonactivating `NSPanel` owns global floating behavior, top-edge positioning, and focus policy. Protocol-backed services and pasteboard adapters keep the observable state model deterministic and testable.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Observation, XCTest, Xcode 26.6, XcodeGen 2.45.4, macOS 14 deployment target.

---

## File Map

- `project.yml`: generated project source of truth, app/test targets, deployment target, and Info.plist keys.
- `Kotina/App/KotinaApp.swift`: SwiftUI application entry point without a normal document window.
- `Kotina/App/AppDelegate.swift`: dependency composition and panel lifecycle.
- `Kotina/Domain/SpellingResult.swift`: spelling issue/result value types.
- `Kotina/Domain/TranslationResult.swift`: translation value type.
- `Kotina/Services/TextProcessingServices.swift`: spelling/translation protocols and service error.
- `Kotina/Services/MockSpellingChecker.swift`: deterministic spelling mock.
- `Kotina/Services/MockTranslator.swift`: deterministic translation mock.
- `Kotina/Services/PasteboardWriter.swift`: pasteboard protocol and system adapter.
- `Kotina/Features/FloatingBar/FloatingBarViewModel.swift`: debounce, concurrent processing, stale-response protection, validation, retry, and copy feedback.
- `Kotina/Features/FloatingBar/FloatingBarView.swift`: approved A-layout input and tab shell.
- `Kotina/Features/FloatingBar/SpellingResultView.swift`: issue list and corrected-text action.
- `Kotina/Features/FloatingBar/TranslationResultView.swift`: translation content and copy action.
- `Kotina/Panel/FloatingPanel.swift`: nonactivating key-on-demand panel.
- `Kotina/Panel/FloatingPanelController.swift`: hosting, panel configuration, positioning, and expansion.
- `KotinaTests/MockServicesTests.swift`: deterministic mock contract tests.
- `KotinaTests/FloatingBarViewModelTests.swift`: state, validation, debounce, stale response, retry, and copy tests.
- `KotinaTests/FloatingPanelTests.swift`: panel level, collection behavior, and key-window policy tests.
- `KotinaTests/TestDoubles.swift`: controlled service and pasteboard test doubles.

### Task 1: Generate the macOS app and test targets

**Files:**
- Create: `project.yml`
- Create: `Kotina/App/KotinaApp.swift`
- Create: `Kotina/App/AppDelegate.swift`
- Test: `KotinaTests/AppSmokeTests.swift`

- [ ] **Step 1: Write the smoke test**

```swift
import XCTest
@testable import Kotina

final class AppSmokeTests: XCTestCase {
    func testApplicationNameIsKotina() {
        XCTAssertEqual(AppIdentity.name, "Kotina")
    }
}
```

- [ ] **Step 2: Add the minimal generated-project manifest and app identity**

```yaml
name: Kotina
options:
  deploymentTarget:
    macOS: "14.0"
settings:
  base:
    SWIFT_VERSION: "6.0"
    MACOSX_DEPLOYMENT_TARGET: "14.0"
targets:
  Kotina:
    type: application
    platform: macOS
    sources: [Kotina]
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.littleduck.kotina
        GENERATE_INFOPLIST_FILE: YES
        INFOPLIST_KEY_LSUIElement: YES
        CODE_SIGNING_ALLOWED: NO
  KotinaTests:
    type: bundle.unit-test
    platform: macOS
    sources: [KotinaTests]
    dependencies:
      - target: Kotina
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES
        CODE_SIGNING_ALLOWED: NO
schemes:
  Kotina:
    build:
      targets:
        Kotina: all
        KotinaTests: [test]
    test:
      targets: [KotinaTests]
```

```swift
enum AppIdentity { static let name = "Kotina" }
```

- [ ] **Step 3: Generate and run the smoke test**

Run:

```bash
xcodegen generate
xcodebuild -project Kotina.xcodeproj -scheme Kotina -destination 'platform=macOS' test
```

Expected: `** TEST SUCCEEDED **` with one passing test.

- [ ] **Step 4: Commit the generated-project source**

```bash
git add project.yml Kotina KotinaTests
git commit -m "build: scaffold native macOS app"
```

### Task 2: Define processing contracts and deterministic mocks

**Files:**
- Create: `Kotina/Domain/SpellingResult.swift`
- Create: `Kotina/Domain/TranslationResult.swift`
- Create: `Kotina/Services/TextProcessingServices.swift`
- Create: `Kotina/Services/MockSpellingChecker.swift`
- Create: `Kotina/Services/MockTranslator.swift`
- Test: `KotinaTests/MockServicesTests.swift`

- [ ] **Step 1: Write failing mock contract tests**

```swift
import XCTest
@testable import Kotina

final class MockServicesTests: XCTestCase {
    func testKnownSpellingSampleProducesCorrection() async throws {
        let result = try await MockSpellingChecker(delay: .zero)
            .check("오늘 회의는 몇일 뒤로 미뤄졌어요.")
        XCTAssertEqual(result.issues.map(\.suggestion), ["며칠"])
        XCTAssertEqual(result.correctedText, "오늘 회의는 며칠 뒤로 미뤄졌어요.")
    }

    func testKnownTranslationSampleProducesEnglish() async throws {
        let result = try await MockTranslator(delay: .zero)
            .translate("오늘 회의는 몇일 뒤로 미뤄졌어요.")
        XCTAssertEqual(result.translatedText, "Today's meeting has been postponed for a few days.")
    }
}
```

- [ ] **Step 2: Run the tests and verify the missing-type failure**

Run: `xcodebuild -project Kotina.xcodeproj -scheme Kotina -destination 'platform=macOS' test`

Expected: compile failure naming `MockSpellingChecker` and `MockTranslator`.

- [ ] **Step 3: Implement the contracts and mocks**

```swift
struct SpellingIssue: Equatable, Sendable {
    let original: String
    let suggestion: String
    let reason: String
}

struct SpellingResult: Equatable, Sendable {
    let originalText: String
    let issues: [SpellingIssue]
    let correctedText: String
}

struct TranslationResult: Equatable, Sendable {
    let sourceLanguage: String
    let targetLanguage: String
    let translatedText: String
}

protocol SpellingChecking: Sendable {
    func check(_ text: String) async throws -> SpellingResult
}

protocol Translating: Sendable {
    func translate(_ text: String) async throws -> TranslationResult
}
```

The spelling mock replaces `몇일` with `며칠`, reports one issue, and otherwise returns a no-issue result. The translation mock returns the exact known sentence above and returns `[Mock translation] <source>` for other input. Both sleep for their injected `Duration` before returning.

- [ ] **Step 4: Run tests and commit**

Run: `xcodebuild -project Kotina.xcodeproj -scheme Kotina -destination 'platform=macOS' test`

Expected: `** TEST SUCCEEDED **`.

```bash
git add Kotina/Domain Kotina/Services KotinaTests/MockServicesTests.swift
git commit -m "feat: add deterministic text processing mocks"
```

### Task 3: Build the observable processing state with TDD

**Files:**
- Create: `Kotina/Services/PasteboardWriter.swift`
- Create: `Kotina/Features/FloatingBar/FloatingBarViewModel.swift`
- Create: `KotinaTests/TestDoubles.swift`
- Test: `KotinaTests/FloatingBarViewModelTests.swift`

- [ ] **Step 1: Write failing state and validation tests**

```swift
@MainActor
final class FloatingBarViewModelTests: XCTestCase {
    func testWhitespaceKeepsPanelCollapsed() async {
        let model = makeModel(debounce: .zero)
        model.sourceText = "   "
        await Task.yield()
        XCTAssertFalse(model.isExpanded)
        XCTAssertEqual(model.spellingPhase, .idle)
    }

    func testLongInputShowsValidationWithoutCallingServices() async {
        let spelling = ControlledSpellingChecker()
        let model = makeModel(spelling: spelling, debounce: .zero)
        model.sourceText = String(repeating: "가", count: 5_001)
        await Task.yield()
        XCTAssertEqual(model.validationMessage, "5,000자 이하로 입력해 주세요.")
        XCTAssertEqual(await spelling.callCount, 0)
    }
}
```

- [ ] **Step 2: Run tests and verify the missing-view-model failure**

Run: `xcodebuild -project Kotina.xcodeproj -scheme Kotina -destination 'platform=macOS' test`

Expected: compile failure naming `FloatingBarViewModel`.

- [ ] **Step 3: Implement core phases, validation, and processing**

```swift
enum LoadPhase<Value: Equatable & Sendable>: Equatable, Sendable {
    case idle
    case loading
    case success(Value)
    case failure(String)
}

@MainActor
@Observable
final class FloatingBarViewModel {
    var sourceText = "" { didSet { sourceDidChange() } }
    private(set) var spellingPhase: LoadPhase<SpellingResult> = .idle
    private(set) var translationPhase: LoadPhase<TranslationResult> = .idle
    private(set) var validationMessage: String?
    var selectedTab: ResultTab = .spelling
    var isExpanded: Bool { validationMessage != nil || spellingPhase != .idle || translationPhase != .idle }
}
```

`sourceDidChange()` cancels the previous task, trims input, resets on empty input, rejects more than 5,000 characters, waits for the injected debounce duration, assigns a UUID request identity, and uses `async let` to start both services. Completion handlers compare the request identity before assigning their independent phase.

- [ ] **Step 4: Add concurrency, stale-response, retry, and copy tests**

Tests prove:

```swift
XCTAssertEqual(model.spellingPhase, .loading)
XCTAssertEqual(model.translationPhase, .loading)
XCTAssertEqual(model.currentSpellingResult?.correctedText, "최신 문장")
XCTAssertEqual(pasteboard.values, ["교정문"])
XCTAssertEqual(model.copyMessage, "복사했어요")
```

Use controlled continuations in `ControlledSpellingChecker` and `ControlledTranslator` so an older request completes after a newer request and cannot overwrite it. Use `RecordingPasteboardWriter(succeeds: false)` to assert `복사하지 못했어요`.

- [ ] **Step 5: Run all state tests and commit**

Run: `xcodebuild -project Kotina.xcodeproj -scheme Kotina -destination 'platform=macOS' test`

Expected: all state tests pass.

```bash
git add Kotina/Services/PasteboardWriter.swift Kotina/Features/FloatingBar/FloatingBarViewModel.swift KotinaTests
git commit -m "feat: add debounced floating bar state"
```

### Task 4: Implement and verify the nonactivating floating panel

**Files:**
- Create: `Kotina/Panel/FloatingPanel.swift`
- Create: `Kotina/Panel/FloatingPanelController.swift`
- Test: `KotinaTests/FloatingPanelTests.swift`

- [ ] **Step 1: Write failing panel-policy tests**

```swift
@MainActor
final class FloatingPanelTests: XCTestCase {
    func testPanelFloatsAcrossSpacesWithoutHidingOnDeactivate() {
        let panel = FloatingPanel(contentRect: .init(x: 0, y: 0, width: 720, height: 64))
        XCTAssertEqual(panel.level, .floating)
        XCTAssertTrue(panel.styleMask.contains(.nonactivatingPanel))
        XCTAssertTrue(panel.collectionBehavior.contains(.canJoinAllSpaces))
        XCTAssertTrue(panel.collectionBehavior.contains(.fullScreenAuxiliary))
        XCTAssertFalse(panel.hidesOnDeactivate)
        XCTAssertTrue(panel.becomesKeyOnlyIfNeeded)
    }
}
```

- [ ] **Step 2: Run tests and verify the missing-panel failure**

Run: `xcodebuild -project Kotina.xcodeproj -scheme Kotina -destination 'platform=macOS' test`

Expected: compile failure naming `FloatingPanel`.

- [ ] **Step 3: Implement the panel policy**

```swift
final class FloatingPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .floating
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
```

The controller uses `orderFrontRegardless()` and never calls `NSApp.activate`. It preserves the top edge while animating between 64-point collapsed and 360-point expanded frames.

- [ ] **Step 4: Run panel tests and commit**

Run: `xcodebuild -project Kotina.xcodeproj -scheme Kotina -destination 'platform=macOS' test`

Expected: all panel tests pass.

```bash
git add Kotina/Panel KotinaTests/FloatingPanelTests.swift
git commit -m "feat: add nonactivating floating panel"
```

### Task 5: Build the approved A-layout SwiftUI interface

**Files:**
- Create: `Kotina/Features/FloatingBar/FloatingBarView.swift`
- Create: `Kotina/Features/FloatingBar/SpellingResultView.swift`
- Create: `Kotina/Features/FloatingBar/TranslationResultView.swift`
- Modify: `Kotina/Panel/FloatingPanelController.swift`

- [ ] **Step 1: Add the A-layout shell**

```swift
struct FloatingBarView: View {
    @Bindable var model: FloatingBarViewModel
    let expansionChanged: (Bool) -> Void

    var body: some View {
        VStack(spacing: 0) {
            inputBar
            if model.isExpanded { resultArea.transition(.move(edge: .top).combined(with: .opacity)) }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.18)))
        .shadow(color: .black.opacity(0.28), radius: 24, y: 12)
        .animation(.snappy(duration: 0.22), value: model.isExpanded)
        .onChange(of: model.isExpanded) { _, expanded in expansionChanged(expanded) }
    }
}
```

The input row contains the gradient app mark, a `TextField("텍스트를 입력하거나 붙여넣으세요", text: $model.sourceText)`, a clear button, and no automatic first-responder request.

- [ ] **Step 2: Add tabbed result content**

Use a two-button segmented header labeled `맞춤법 · <issue count>` and `번역`. Render `ProgressView`, inline validation/failure with retry, `SpellingResultView`, or `TranslationResultView` from the corresponding phase. Each result view calls the model copy method and exposes the temporary copy status through an accessibility label.

- [ ] **Step 3: Build and inspect SwiftUI compilation**

Run: `xcodebuild -project Kotina.xcodeproj -scheme Kotina -configuration Debug -destination 'platform=macOS' build`

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit the approved visual implementation**

```bash
git add Kotina/Features Kotina/Panel/FloatingPanelController.swift
git commit -m "feat: build tabbed glass floating bar"
```

### Task 6: Compose the app and verify the complete automated suite

**Files:**
- Modify: `Kotina/App/KotinaApp.swift`
- Modify: `Kotina/App/AppDelegate.swift`
- Modify: `Kotina/Panel/FloatingPanelController.swift`

- [ ] **Step 1: Compose production dependencies**

```swift
@main
struct KotinaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    var body: some Scene { Settings { EmptyView() } }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panelController: FloatingPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let model = FloatingBarViewModel(
            spellingChecker: MockSpellingChecker(),
            translator: MockTranslator(),
            pasteboard: SystemPasteboardWriter()
        )
        let controller = FloatingPanelController(model: model)
        controller.show()
        panelController = controller
    }
}
```

- [ ] **Step 2: Regenerate and run the full build/test suite**

Run:

```bash
xcodegen generate
xcodebuild -project Kotina.xcodeproj -scheme Kotina -configuration Debug -destination 'platform=macOS' build
xcodebuild -project Kotina.xcodeproj -scheme Kotina -destination 'platform=macOS' test
```

Expected: `** BUILD SUCCEEDED **` and `** TEST SUCCEEDED **`.

- [ ] **Step 3: Commit the runnable app composition**

```bash
git add Kotina project.yml KotinaTests
git commit -m "feat: compose runnable Kotina MVP"
```

### Task 7: Runtime verification and durable project records

**Files:**
- Modify: `.gitignore` only if runtime artifacts appear unignored.
- Modify externally: AI OS `kotina Active Context`, `kotina Runbook`, `kotina Decision Log`, and `kotina Work Records`.

- [ ] **Step 1: Launch the built application**

Find the product path:

```bash
xcodebuild -project Kotina.xcodeproj -scheme Kotina -configuration Debug -showBuildSettings | rg 'TARGET_BUILD_DIR|WRAPPER_NAME'
```

Launch the resulting `Kotina.app` and confirm the top-center collapsed bar appears without a Dock icon.

- [ ] **Step 2: Verify MVP behavior interactively**

Check all items:

- Another application remains active while Kotina passively shows and updates.
- Clicking the text field permits typing and paste.
- `오늘 회의는 몇일 뒤로 미뤄졌어요.` produces `몇일 → 며칠`.
- The translation tab produces `Today's meeting has been postponed for a few days.`.
- Both copy buttons place exact expected text on the system pasteboard.
- Clearing input collapses the result area.
- The bar remains above a normal window and appears after switching Spaces.
- A 5,001-character input shows local validation without processing.

- [ ] **Step 3: Record verified commands and current state in AI OS**

Replace the unverified Runbook build/test/run entries with exact successful commands and product path. Add the implemented architecture and any focus caveat to Decision Log. Add a concise work record with commit IDs and verification evidence. Update Active Context to the next real milestone.

- [ ] **Step 4: Verify repository state and commit final record pointers if needed**

Run:

```bash
git status --short
git log --oneline --decorate -8
```

Expected: only intentional source/document changes are present; AI OS pointer files remain ignored.


# Kotina Local Processing Beta Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace production mocks with conservative local Korean proofreading and Apple on-device translation, add a discoverable quit path, and produce a reproducible unsigned Apple silicon beta archive.

**Architecture:** Keep the existing service protocols and view-model request identity. Add a deterministic correction pipeline whose final edits come from versioned rules and whose optional morphology evidence comes from Kiwi 0.23.2. Drive macOS 15 Translation sessions through a SwiftUI configuration broker, and keep app lifecycle and release packaging behind small testable boundaries.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Translation framework, XCTest, XcodeGen 2.45.4, Kiwi C API 0.23.2, shell release tooling.

**Implementation status (2026-07-07):** Tasks 1–8 are implemented on `feature/floating-bar-mvp` through commit `49e5b8d`. Task 9 verification is in progress: full XCTest now reports `testsCount=46` with 46 `Success` statuses and no skipped tests after `KotinaTests/KiwiAnalyzerTests.swift` was changed to use the bundled Kiwi model when `KOTINA_KIWI_MODEL_PATH` is absent. Release packaging for `0.1.0-beta.1` generated `dist/0.1.0-beta.1/Kotina-0.1.0-beta.1-macOS-arm64.zip` with SHA-256 `e0c6943944628db45dd7070902b8a3513e261cbf7eb58129f66dfefd4f885adf`; `unzip -tq` and `shasum -a 256 -c` pass when run from the package directory. Runtime checks verified real proofreading samples, Apple Translation output, copy buttons, focus preservation, menu quit, and `Command-Q` termination. Remaining work is durable record update, documentation commit, GitHub authentication/push/release creation, and a future clean-Mac offline smoke test.

---

## File Map

- Modify `project.yml`: macOS 15 target, Translation framework, Kiwi module/link/copy settings, Release version metadata.
- Modify `.gitignore`: ignore downloaded Kiwi binary/model assets and generated release output.
- Create `scripts/fetch-kiwi.sh`: download and verify pinned Kiwi arm64 dynamic library and base model.
- Create `Vendor/Kiwi/module/module.modulemap`: expose Kiwi's C API to Swift.
- Create `THIRD_PARTY_NOTICES.md`: Kiwi version, origin, LGPL v3 obligations, and asset provenance.
- Create `Kotina/App/ApplicationTerminating.swift`: production termination adapter.
- Modify `Kotina/App/AppDelegate.swift`: production dependency composition and shutdown.
- Modify `Kotina/App/KotinaApp.swift`: replace the default termination command with the app's quit path.
- Modify `Kotina/Features/FloatingBar/FloatingBarView.swift`: quit menu, translation preparation state, translation task modifier.
- Modify `Kotina/Features/FloatingBar/FloatingBarViewModel.swift`: quit/shutdown and translation-resource states.
- Create `Kotina/Services/KoreanCorrectionRule.swift`: accepted edit and rule contracts.
- Create `Kotina/Services/KoreanRuleEngine.swift`: initial conservative correction rules.
- Create `Kotina/Services/CorrectionDiffBuilder.swift`: apply sorted nonoverlapping edits and build issues.
- Create `Kotina/Services/KiwiAnalyzer.swift`: Swift wrapper around the pinned Kiwi C API.
- Create `Kotina/Services/LocalKoreanChecker.swift`: normalization, Kiwi evidence, rules, and final result.
- Create `Kotina/Services/TranslationSessionBroker.swift`: macOS 15 session/configuration bridge.
- Create `Kotina/Services/AppleTranslator.swift`: availability, preparation, translation, cancellation.
- Modify `Kotina/Services/TextProcessingServices.swift`: local-engine and translation-resource error cases.
- Modify `Kotina/Features/FloatingBar/SpellingResultView.swift`: qualified no-issue language.
- Modify `Kotina/Features/FloatingBar/TranslationResultView.swift`: preparation/error actions where applicable.
- Create `KotinaTests/ApplicationTerminationTests.swift`.
- Create `KotinaTests/KoreanRuleEngineTests.swift`.
- Create `KotinaTests/CorrectionDiffBuilderTests.swift`.
- Create `KotinaTests/KiwiAnalyzerTests.swift`.
- Create `KotinaTests/LocalKoreanCheckerTests.swift`.
- Create `KotinaTests/TranslationSessionBrokerTests.swift`.
- Modify `KotinaTests/FloatingBarViewModelTests.swift` and `KotinaTests/TestDoubles.swift`.
- Create `scripts/package-beta.sh`: build, inspect, ZIP, and checksum an unsigned beta.
- Create `README.md`: compatibility, local processing, install, Gatekeeper, verification, quit, and uninstall guidance.

### Task 1: Raise the supported OS and preserve a green baseline

**Files:**
- Modify: `project.yml`
- Modify: `KotinaTests/AppSmokeTests.swift`

- [ ] **Step 1: Write the failing deployment-target test**

Add a test that reads `Bundle.main.object(forInfoDictionaryKey: "LSMinimumSystemVersion")` and expects `15.0`.

```swift
func testMinimumSystemVersionIsMacOS15() {
    XCTAssertEqual(
        Bundle.main.object(forInfoDictionaryKey: "LSMinimumSystemVersion") as? String,
        "15.0"
    )
}
```

- [ ] **Step 2: Run the focused test and verify red**

Run:

```bash
xcodegen generate
xcodebuild -quiet -project Kotina.xcodeproj -scheme Kotina \
  -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/KotinaDerivedData \
  -only-testing:KotinaTests/AppSmokeTests test
```

Expected: failure reporting `14.0` instead of `15.0`.

- [ ] **Step 3: Change both deployment target values**

Set `options.deploymentTarget.macOS` and `MACOSX_DEPLOYMENT_TARGET` to `"15.0"` in `project.yml`.

- [ ] **Step 4: Run the focused test and the full baseline**

Run the focused command above, then the full existing test command. Expected: all current tests pass.

- [ ] **Step 5: Commit**

```bash
git add project.yml KotinaTests/AppSmokeTests.swift
git commit -m "build: target macOS 15 for local translation"
```

### Task 2: Add a discoverable and testable application quit path

**Files:**
- Create: `Kotina/App/ApplicationTerminating.swift`
- Modify: `Kotina/App/AppDelegate.swift`
- Modify: `Kotina/App/KotinaApp.swift`
- Modify: `Kotina/Features/FloatingBar/FloatingBarViewModel.swift`
- Modify: `Kotina/Features/FloatingBar/FloatingBarView.swift`
- Create: `KotinaTests/ApplicationTerminationTests.swift`
- Modify: `KotinaTests/TestDoubles.swift`

- [ ] **Step 1: Write failing quit tests**

Use a recording terminator and assert that `quit()` cancels state and calls it exactly once.

```swift
@MainActor
final class RecordingApplicationTerminator: ApplicationTerminating {
    private(set) var callCount = 0
    func terminate() { callCount += 1 }
}

@MainActor
func testQuitClearsWorkAndTerminatesApplication() {
    let terminator = RecordingApplicationTerminator()
    let model = makeModel(terminator: terminator)
    model.sourceText = "진행 중인 문장"

    model.quit()

    XCTAssertEqual(terminator.callCount, 1)
    XCTAssertEqual(model.sourceText, "")
    XCTAssertEqual(model.spellingPhase, .idle)
    XCTAssertEqual(model.translationPhase, .idle)
}
```

- [ ] **Step 2: Run the focused test and verify missing types/methods**

Run `xcodebuild` with `-only-testing:KotinaTests/ApplicationTerminationTests`. Expected: compile failure for `ApplicationTerminating` and `quit()`.

- [ ] **Step 3: Implement the lifecycle boundary**

```swift
import AppKit

@MainActor
protocol ApplicationTerminating: AnyObject {
    func terminate()
}

@MainActor
final class SystemApplicationTerminator: ApplicationTerminating {
    func terminate() {
        NSApp.terminate(nil)
    }
}
```

Inject it into `FloatingBarViewModel`, default only in production composition, and implement `shutdown()` plus `quit()` so all processing and copy-feedback tasks are cancelled before termination.

- [ ] **Step 4: Add the visible menu and standard command**

Add this trailing control after the clear button:

```swift
Menu {
    Button("Kotina 종료", systemImage: "power", action: model.quit)
        .keyboardShortcut("q")
} label: {
    Image(systemName: "ellipsis.circle")
}
.menuStyle(.borderlessButton)
.help("Kotina 메뉴")
.accessibilityLabel("Kotina 메뉴")
```

Replace the app termination command in `KotinaApp` with a `Command-Q` button that calls `appDelegate.terminate()`, which forwards to the same model quit path. In `applicationWillTerminate`, call `model.shutdown()` as a defensive path.

- [ ] **Step 5: Run focused and full tests**

Expected: quit tests pass; existing debounce, copy, panel, and geometry tests remain green.

- [ ] **Step 6: Commit**

```bash
git add Kotina/App Kotina/Features/FloatingBar KotinaTests
git commit -m "feat: add in-panel application quit"
```

### Task 3: Build the deterministic Korean correction core

**Files:**
- Create: `Kotina/Services/KoreanCorrectionRule.swift`
- Create: `Kotina/Services/KoreanRuleEngine.swift`
- Create: `Kotina/Services/CorrectionDiffBuilder.swift`
- Create: `Kotina/Services/LocalKoreanChecker.swift`
- Create: `KotinaTests/KoreanRuleEngineTests.swift`
- Create: `KotinaTests/CorrectionDiffBuilderTests.swift`
- Create: `KotinaTests/LocalKoreanCheckerTests.swift`

- [ ] **Step 1: Add correction and preservation fixtures first**

Define table-driven fixtures with at least 25 corrections and 20 byte-preserving normal inputs. Include these required examples:

```swift
let corrections: [(String, String)] = [
    ("오늘 회의는 몇일 뒤로 미뤄졌어요.", "오늘 회의는 며칠 뒤로 미뤄졌어요."),
    ("이렇게 하면 되요.", "이렇게 하면 돼요."),
    ("지금은 안되요.", "지금은 안 돼요."),
    ("\u{C660} 이렇게 복잡한지 모르겠어요.", "\u{C6EC} 이렇게 복잡한지 모르겠어요."),
    ("\u{C660}지 낯설지 않아요.", "\u{C660}지 낯설지 않아요."),
    ("할수 있어요.", "할 수 있어요."),
    ("두  칸을  띄웠어요.", "두 칸을 띄웠어요.")
]
```

Use Unicode escapes in source where visually similar Hangul syllables could be confused, especially `왠` (`U+C660`) and `웬` (`U+C6EC`). Keep `왜` (`U+C65C`, “why”) separate from both.

- [ ] **Step 2: Run tests and verify missing engine types**

Expected: compile failure for `KoreanRuleEngine`, `CorrectionEdit`, and `CorrectionDiffBuilder`.

- [ ] **Step 3: Implement focused edit contracts**

```swift
struct CorrectionEdit: Equatable, Sendable {
    let range: Range<String.Index>
    let replacement: String
    let reason: String
}

protocol KoreanCorrectionRule: Sendable {
    func edits(in text: String) -> [CorrectionEdit]
}
```

Use literal/context rules rather than a generic free-form replacement API. Sort accepted edits by source position, reject overlaps, compute integer offsets from the original string, and apply replacements from the end of the string toward the start.

- [ ] **Step 4: Implement the initial rule set**

Implement separate private rule types for day-count `몇일`, `되요`, negative `안 되-` endings, `왠/웬` with an explicit `왠지` exception, dependent-noun `수`, and runs of two or more horizontal spaces. Each issue reason names the rule instead of claiming general correctness.

- [ ] **Step 5: Implement `LocalKoreanChecker` without Kiwi first**

Normalize to NFC, collect rule edits, build `SpellingResult`, and preserve arbitrary unsupported text unchanged. Do not return a mock label.

- [ ] **Step 6: Run fixture, focused, and full tests**

Expected: 25+ corrections pass, 20+ preservation inputs are unchanged, and existing tests stay green.

- [ ] **Step 7: Commit**

```bash
git add Kotina/Services KotinaTests
git commit -m "feat: add conservative Korean correction rules"
```

### Task 4: Pin, fetch, and integrate Kiwi morphology evidence

**Files:**
- Modify: `.gitignore`
- Modify: `project.yml`
- Create: `scripts/fetch-kiwi.sh`
- Create: `Vendor/Kiwi/module/module.modulemap`
- Create: `THIRD_PARTY_NOTICES.md`
- Create: `Kotina/Services/KiwiAnalyzer.swift`
- Modify: `Kotina/Services/LocalKoreanChecker.swift`
- Create: `KotinaTests/KiwiAnalyzerTests.swift`

- [ ] **Step 1: Write the failing adapter contract tests**

```swift
func testMissingModelPathThrowsInitializationError() {
    XCTAssertThrowsError(try KiwiAnalyzer(modelPath: "/missing/kiwi/model")) {
        XCTAssertEqual($0 as? TextProcessingError, .localEngineUnavailable)
    }
}
```

Add an integration test gated by `KOTINA_KIWI_MODEL_PATH`; when present it must analyze `아버지가방에들어가신다` and return nonempty tokens with valid UTF-16 ranges.

- [ ] **Step 2: Add a checksum-pinned fetch script**

Pin these official release assets:

```text
Kiwi version: 0.23.2
kiwi_mac_arm64_v0.23.2.tgz
sha256 ac124e32e013e2089cb4d842e2b735a1e6b4f3b126cdf692d78fda1130b8a382
kiwi_model_v0.23.2_base.tgz
sha256 15f35787ab07281688a321f5d6bc24a117008190d9fcccb11dca188e81eba814
```

The script downloads into a temporary directory, verifies both checksums before extraction, then installs headers, the versioned dylib as `Vendor/Kiwi/lib/libkiwi.0.dylib`, and `models/cong/base` below `Vendor/Kiwi`. Renaming the copied binary to its install name preserves `@rpath/libkiwi.0.dylib`; the script must never accept an unverified asset.

- [ ] **Step 3: Expose the C module and link a replaceable dylib**

```modulemap
module KiwiC [system] {
    header "../include/kiwi/capi.h"
    export *
}
```

Configure header/module search paths, linker search path, `-lkiwi`, `@executable_path/../Frameworks`, a copy-files phase that embeds `libkiwi.0.dylib`, and a resource copy for the base model. Confirm the built app contains both the dylib and model directory.

- [ ] **Step 4: Implement the narrow C wrapper**

Wrap `kiwi_init`, `kiwi_analyze_w`, `kiwi_res_word_num`, `kiwi_res_form`, `kiwi_res_tag`, `kiwi_res_token_info`, `kiwi_res_close`, and `kiwi_close`. Own every handle with one close path. Convert `chr_position` and `length` from UTF-16 offsets into Swift ranges and expose only `form`, `tag`, `range`, and `typoCost`.

- [ ] **Step 5: Use Kiwi only as rule evidence**

Inject a `KoreanAnalyzing` protocol into `LocalKoreanChecker`. Dependent-noun spacing rules may require matching Kiwi tags, but Kiwi output alone must never mutate text.

- [ ] **Step 6: Verify linking and offline analysis**

Run fetch, generate, focused integration test with `KOTINA_KIWI_MODEL_PATH`, full tests, and `otool -L` on the app executable. Expected: the app resolves Kiwi through its embedded Frameworks path and has no Homebrew/local absolute dependency.

- [ ] **Step 7: Commit tracked integration files only**

```bash
git add .gitignore project.yml scripts/fetch-kiwi.sh Vendor/Kiwi/module \
  THIRD_PARTY_NOTICES.md Kotina/Services/KiwiAnalyzer.swift \
  Kotina/Services/LocalKoreanChecker.swift KotinaTests/KiwiAnalyzerTests.swift
git commit -m "feat: integrate pinned Kiwi morphology engine"
```

### Task 5: Add translation resource states and a session broker

**Files:**
- Modify: `Kotina/Services/TextProcessingServices.swift`
- Create: `Kotina/Services/TranslationSessionBroker.swift`
- Create: `Kotina/Services/AppleTranslator.swift`
- Create: `KotinaTests/TranslationSessionBrokerTests.swift`
- Modify: `KotinaTests/TestDoubles.swift`

- [ ] **Step 1: Write broker state tests with a fake driver**

```swift
enum TranslationResourceState: Equatable, Sendable {
    case checking
    case needsPreparation
    case ready
    case unavailable
}
```

Test `supported -> needsPreparation`, `installed -> ready`, successful preparation, cancellation preserving `needsPreparation`, translated output, and stale request rejection. The fake driver must not import Apple's concrete session type.

- [ ] **Step 2: Run focused tests and verify red**

Expected: missing `TranslationSessionBroker`, resource state, and driver protocol.

- [ ] **Step 3: Implement the broker boundary**

The broker owns an optional `TranslationSession.Configuration`, one pending operation, and checked continuations. It emits a configuration only for an installed translation request or an explicit preparation request. A second request cancels and resumes the first continuation with `CancellationError`.

- [ ] **Step 4: Implement Apple availability mapping**

Map `LanguageAvailability.Status.installed` to `.ready`, `.supported` to `.needsPreparation`, and `.unsupported` to `.unavailable`. Use `Locale.Language(identifier: "ko")` and `Locale.Language(identifier: "en")`.

- [ ] **Step 5: Run broker tests and commit**

```bash
git add Kotina/Services KotinaTests
git commit -m "feat: add on-device translation session broker"
```

### Task 6: Connect Apple Translation to the floating UI

**Files:**
- Modify: `Kotina/Features/FloatingBar/FloatingBarViewModel.swift`
- Modify: `Kotina/Features/FloatingBar/FloatingBarView.swift`
- Modify: `Kotina/Features/FloatingBar/TranslationResultView.swift`
- Modify: `KotinaTests/FloatingBarViewModelTests.swift`
- Modify: `KotinaTests/TestDoubles.swift`

- [ ] **Step 1: Write failing view-model tests**

Test that a nonempty input with `.needsPreparation` succeeds in proofreading while translation shows a preparation state, explicit `prepareTranslation()` calls the service, a successful preparation retries the current text, and clearing input cancels both paths.

- [ ] **Step 2: Add explicit translation phases**

Extend the UI state without encoding preparation as a generic error string:

```swift
enum TranslationPhase: Equatable, Sendable {
    case idle
    case checkingResources
    case needsPreparation
    case preparing
    case translating
    case success(TranslationResult)
    case failure(String)
    case unavailable
}
```

- [ ] **Step 3: Apply the SwiftUI translation task**

Import `Translation`, bind the broker configuration, and forward sessions:

```swift
.translationTask(model.translationConfiguration) { session in
    await model.handleTranslationSession(session)
}
```

The Translation tab shows `번역 모델 준비` only in `.needsPreparation`, shows progress during `.preparing`, and keeps proofreading usable throughout.

- [ ] **Step 4: Verify no passive activation regression**

Run focused view-model tests, panel tests, the full suite, and an interactive check with another app frontmost. Expected: resource and result updates do not activate Kotina; only an explicit preparation click can open Apple's system flow.

- [ ] **Step 5: Commit**

```bash
git add Kotina/Features/FloatingBar KotinaTests
git commit -m "feat: connect Apple on-device translation UI"
```

### Task 7: Switch production composition away from mocks

**Files:**
- Modify: `Kotina/App/AppDelegate.swift`
- Modify: `Kotina/Features/FloatingBar/SpellingResultView.swift`
- Modify: `Kotina/Services/MockSpellingChecker.swift`
- Modify: `Kotina/Services/MockTranslator.swift`
- Modify: `KotinaTests/AppSmokeTests.swift`

- [ ] **Step 1: Write a composition smoke test**

Extract a `ProductionDependencies.make(bundle:)` factory and assert its concrete service names contain `LocalKoreanChecker` and `AppleTranslator`, not `Mock`.

- [ ] **Step 2: Run and verify red**

Expected: missing production factory.

- [ ] **Step 3: Compose production services**

Resolve the bundled Kiwi model path, initialize `KiwiAnalyzer`, create `LocalKoreanChecker`, broker, Apple translator, system pasteboard, and system terminator. Keep mocks only in test targets and explicit previews.

- [ ] **Step 4: Qualify the no-issue copy**

Change `맞춤법 오류를 찾지 못했어요` to `확신할 수 있는 오류를 찾지 못했어요`.

- [ ] **Step 5: Run full tests, build, and runtime samples**

Verify arbitrary unsupported text is unchanged without `[Mock ...]`, required Korean fixtures correct properly, and installed translation returns real English.

- [ ] **Step 6: Commit**

```bash
git add Kotina KotinaTests
git commit -m "feat: enable local processing in production"
```

### Task 8: Package the unsigned GitHub beta

**Files:**
- Modify: `.gitignore`
- Create: `scripts/package-beta.sh`
- Create: `README.md`
- Modify: `THIRD_PARTY_NOTICES.md`
- Modify: `project.yml`

- [ ] **Step 1: Add a failing packaging preflight**

The script must exit nonzero if the version argument is missing, Kiwi assets are absent, the built executable is not arm64, `LSUIElement` is not true, the minimum OS is not 15.0, or the third-party notice is missing.

- [ ] **Step 2: Implement reproducible packaging**

Build Release into `/private/tmp/KotinaReleaseDerivedData`, copy the app into a staging directory, verify it with `file`, `plutil`, and `otool -L`, archive with `ditto -c -k --sequesterRsrc --keepParent`, and generate `shasum -a 256`. Output only under `dist/<version>/`.

- [ ] **Step 3: Write user-facing beta documentation**

Document Apple silicon/macOS 15+, unsigned Gatekeeper behavior using System Settings rather than bypass commands, local processing, first translation language download, known correction coverage, checksum verification, `Kotina 종료`, and uninstall by deleting the app.

- [ ] **Step 4: Run packaging and inspect the archive**

```bash
scripts/package-beta.sh 0.1.0-beta.1
unzip -l dist/0.1.0-beta.1/Kotina-0.1.0-beta.1-macOS-arm64.zip
shasum -a 256 -c dist/0.1.0-beta.1/Kotina-0.1.0-beta.1-macOS-arm64.zip.sha256
```

Expected: checksum OK; app, Kiwi dylib/model assets, and notices are present.

- [ ] **Step 5: Commit**

```bash
git add .gitignore project.yml scripts/package-beta.sh README.md THIRD_PARTY_NOTICES.md
git commit -m "build: package unsigned macOS beta"
```

### Task 9: Final verification, records, and publication readiness

**Files:**
- Modify: `docs/superpowers/plans/2026-07-02-kotina-local-processing-beta.md`
- Modify externally: AI OS Active Context, Runbook, Decision Log, Session Brief, Work Record
- Update through MCP: Manyfast progress for completed new requirements/features/specs

- [ ] **Step 1: Run fresh verification from generated sources**

Run fetch, XcodeGen, full XCTest, Debug build, Release build, package script, `otool -L`, archive checksum, and runtime smoke tests. Capture exact test count and commands.

- [ ] **Step 2: Verify app behavior manually**

Check real proofreading, real translation after preparation, both copy buttons, focus preservation, menu quit, Command-Q, relaunch, and offline reuse.

- [ ] **Step 3: Update durable records**

Record versions, checksums, commands, known correction coverage, release path, commits, and the Manyfast update-endpoint limitation in AI OS. Mark only actually verified Manyfast items done.

- [ ] **Step 4: Run code simplification and completion verification**

Apply `code-simplifier` only to touched files, rerun the full verification, confirm a clean worktree, and use `verification-before-completion` before reporting success.

- [ ] **Step 5: Commit documentation state**

```bash
git add docs/superpowers/plans/2026-07-02-kotina-local-processing-beta.md
git commit -m "docs: record local beta verification"
```

- [ ] **Step 6: Prepare GitHub publication**

Run `gh auth login -h github.com` interactively if the user has not restored authentication. Push `feature/floating-bar-mvp` only after authentication and explicit publication approval; do not create a Release until the unsigned archive has passed every check above.

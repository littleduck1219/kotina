# Kotina Local Processing Beta Design

## Objective

Replace Kotina's one-sample mocks with useful, zero-usage-cost local Korean
proofreading and Korean-to-English translation. Preserve the approved
always-on-top, nonactivating glass panel and prepare an unsigned GitHub beta
that other Apple silicon Mac users can try.

This design updates the Manyfast project “맥용 맞춤법·번역 플로팅 앱”
(project ID `c20b34fa-c733-41d6-a29f-bedcf0b6b146`).

## Product Constraints

- No paid API and no metered processing cost.
- No source text, result text, or usage history leaves the Mac.
- The beta supports Apple silicon Macs running macOS 15 or newer.
- The first beta is distributed as an unsigned ZIP through GitHub Releases.
- The GitHub repository is `https://github.com/littleduck1219/kotina.git`.
- Clipboard monitoring, global shortcuts, selected-text capture, Accessibility
  onboarding, and automatic launch remain later milestones.
- Proofreading is conservative: Kotina leaves uncertain text unchanged rather
  than rewriting it for fluency.

## Architecture

The existing `SpellingChecking` and `Translating` protocols remain the stable
application boundary. Mock implementations remain available to deterministic
unit tests, while production dependency composition selects local services.

### Local Korean proofreading

`LocalKoreanChecker` composes four focused components:

1. `KoreanTextNormalizer` normalizes Unicode and invisible whitespace without
   changing visible wording.
2. `KiwiAnalyzer` wraps the native Kiwi morphology engine and provides tokens,
   spacing evidence, and typo candidates. Kiwi is distributed as a replaceable
   dynamic library with its model assets and LGPL v3 notices.
3. `KoreanRuleEngine` applies only versioned, deterministic rules whose context
   preconditions match. The initial rules cover at least `몇일/며칠`,
   `되요/돼요`, `안되/안 돼`, `왠지 예외와 왠/웬 구분`, repeated whitespace, and common
   particle or dependent-noun spacing cases.
4. `CorrectionDiffBuilder` creates nonoverlapping `SpellingIssue` values and a
   corrected full string from accepted edits.

Rules own the final decision. Kiwi candidates may supply evidence, but no
candidate changes text unless a deterministic rule accepts it. Apple
Foundation Models are not part of the first beta because local experiments
changed meaning and produced an incorrect `몇 일` correction.

### On-device translation

`AppleTranslator` uses Apple's Translation framework for Korean-to-English
translation. Because macOS 15 provides a `TranslationSession` through SwiftUI's
translation task modifier, a `TranslationSessionBroker` owns the live session
and exposes it to the service boundary.

The app checks the Korean-English language-pair status before translation. If
the pair is not installed, the Translation tab shows a `번역 모델 준비`
action. Only that explicit user action may request Apple's language download.
After preparation, normal translation runs on-device. Results are retained in
view-model memory only and disappear when the input is cleared or the app
terminates.

## User Flow

1. The user types or pastes text into the existing floating bar.
2. After the 300 ms debounce, local proofreading starts immediately.
3. The spelling tab displays accepted issues, reasons, and corrected text.
4. If translation resources are ready, translation runs alongside
   proofreading and updates its tab independently.
5. If resources are not ready, the Translation tab explains the requirement
   and shows `번역 모델 준비`.
6. The user explicitly starts preparation and accepts Apple's system download
   flow. The app retries translation when preparation completes.
7. Corrected or translated text can be copied through the existing actions.
8. Clearing the input cancels active work and collapses the result panel.

Translation-resource preparation is the only expected network-dependent
operation. Routine proofreading and prepared translation work offline.

## Application Exit

Kotina is an accessory application without a Dock icon, so termination must be
discoverable inside the floating bar.

- Add a compact menu button at the input bar's trailing edge.
- The menu contains `Kotina 종료` with the `Command-Q` shortcut.
- Selecting it calls an injected `ApplicationTerminating` abstraction whose
  production adapter invokes `NSApp.terminate(nil)`.
- Pending debounce, proofreading, translation, and copied-feedback tasks are
  cancelled during termination.
- The existing circle-X remains `입력 지우기`; labels and help text must
  distinguish it from application exit.
- No confirmation dialog is required because Kotina stores no unsaved user
  document.

## State and Error Handling

Proofreading and translation retain independent phases. A failure in one tab
does not hide a successful result in the other.

- Empty input performs no processing.
- Input over 5,000 characters retains the existing local validation error.
- No accepted proofreading rule means `확신할 수 있는 오류를 찾지 못했어요`;
  the UI must not imply that the sentence is universally correct.
- Missing Kiwi assets report a local-engine initialization error and offer a
  retry after relaunch.
- Unsupported translation pairs and unavailable language resources show
  different messages.
- A cancelled Apple download leaves proofreading usable and keeps the prepare
  action available.
- Stale request identities cannot overwrite results for newer input.
- All errors remain inline and never activate the app or steal focus.

## Privacy and Data Lifetime

- Input and results are processed in memory.
- Kotina does not persist source text, corrected text, translations, or a
  clipboard history.
- Kotina does not include analytics or telemetry in the free beta.
- The release README states that Apple may download translation language
  resources, while normal text processing remains on-device.
- Third-party notices include Kiwi's license and the licenses for every bundled
  model or data asset.

## Testing and Evaluation

Automated verification adds:

- rule tests for each supported error and its context boundary;
- at least 25 expected-correction fixtures across the initial rule categories;
- at least 20 preservation fixtures that must remain byte-for-byte unchanged;
- multiple nonoverlapping corrections in one input;
- normalization and source-range correctness for Korean Unicode text;
- Kiwi adapter success, missing-assets, and no-candidate behavior;
- translation broker states: unavailable, needs preparation, ready, cancelled,
  and failed;
- fake translation-session output and stale-result cancellation;
- exit-menu invocation, termination-task cancellation, accessibility labels,
  and `Command-Q` routing;
- existing panel policy, debounce, copy, and geometry regression tests.

Runtime verification on a clean Apple silicon Mac checks:

1. first launch without a Dock icon;
2. local proofreading with network disabled;
3. explicit language-model preparation;
4. prepared Korean-to-English translation with network disabled;
5. corrected-text and translation clipboard output;
6. focus preservation while another app remains active;
7. complete termination from `Kotina 종료` and `Command-Q`.

## Free Beta Distribution

The release pipeline generates a Release configuration for `arm64`, packages
`Kotina.app` as `Kotina-<version>-macOS-arm64.zip`, and emits a matching SHA-256
checksum file. A release script verifies the archive contents before upload.

The GitHub Release notes and README include:

- macOS 15+ and Apple silicon requirements;
- unsigned-beta and Gatekeeper instructions;
- the on-device processing and Apple language-download disclosure;
- known proofreading coverage limits;
- third-party notices;
- checksum verification instructions;
- uninstall instructions.

No automated command disables Gatekeeper or removes quarantine attributes.
Users retain control of macOS security settings. Developer ID signing,
notarization, Sparkle updates, and Mac App Store delivery are later paid
distribution milestones.

## Manyfast Manifest Changes

Update the PRD to state that the first distributable beta uses local processing,
has no metered API cost, targets Apple silicon and macOS 15+, and is delivered
through an unsigned GitHub Release. Remove API-request-cost language from the
current beta risk and replace it with local engine coverage, translation model
availability, unsigned-install friction, and third-party license compliance.

Update the current proofreading and translation requirements so their first
acceptance criteria cover direct input, local processing, explicit Apple
language preparation, offline operation after preparation, and copy actions.
Automatic clipboard capture, shortcuts, selected-text capture, and
Accessibility onboarding stay in the manifest but are explicitly marked as
post-beta scope rather than current-beta acceptance criteria.

Add a high-priority application-lifecycle requirement covering discoverable
termination from the floating bar and `Command-Q`. Add a high-priority beta
distribution requirement covering the unsigned arm64 archive, checksum,
compatibility statement, security instructions, and license notices.

## Acceptance Criteria

- Arbitrary nonempty input no longer receives a mock-labelled result.
- The supported local rules produce structured issues and corrected text
  without a network connection.
- Uncertain sentences remain unchanged and receive qualified UI language.
- Korean-to-English translation uses Apple Translation and works offline after
  the language pair is prepared.
- No paid API key, account, or metered endpoint is required.
- The floating bar preserves its existing always-on-top and nonactivating
  behavior.
- `Kotina 종료` and `Command-Q` completely terminate the accessory app.
- The app builds for Apple silicon with a macOS 15 deployment target.
- Automated tests pass and the clean-Mac runtime checklist is recorded.
- The generated ZIP, checksum, README guidance, and third-party notices are
  sufficient for an informed unsigned GitHub beta install.

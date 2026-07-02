# Kotina Floating Bar MVP Design

## Objective

Build a native macOS 14+ MVP that stays above other applications as a compact glass bar. A user can click the bar, type or paste text, and immediately receive mocked Korean spelling and English translation results. Each result can be copied without the panel taking focus during passive updates.

This design implements the direct-input slice of the Manyfast project “맥용 맞춤법·번역 플로팅 앱” (project ID `c20b34fa-c733-41d6-a29f-bedcf0b6b146`).

## MVP Scope

Included:

- A top-centered, always-on-top glass panel.
- A collapsed input bar and an expanded A-style tabbed result panel.
- Direct text entry and paste.
- 300 ms debounced processing.
- Concurrent mocked spelling and translation services.
- Spelling issue details, corrected full text, and copy action.
- Translation text and copy action.
- Loading, empty, per-service failure, retry, and copied feedback states.
- No focus change when results update.

Excluded:

- Real spelling or translation APIs.
- Clipboard monitoring.
- Global shortcuts and selected-text capture from other apps.
- Accessibility permission onboarding.
- Preferences, launch-at-login, telemetry, and distribution signing.

## Technology and Project Structure

- Xcode 26.6 with a generated macOS application project.
- XcodeGen 2.45.4; `project.yml` is the source of truth and the `.xcodeproj` is ignored.
- SwiftUI for visual components and observable UI state.
- AppKit for the application lifecycle, custom `NSPanel`, window level, Space behavior, and focus policy.
- Swift Testing or XCTest targets for domain, view-model, clipboard, and panel-policy behavior.

The code is split into focused areas:

- `App`: app delegate, dependency composition, and panel presentation.
- `Panel`: `NSPanel` subclass/configuration and screen positioning.
- `Features/FloatingBar`: SwiftUI views and observable state.
- `Domain`: result models and service protocols.
- `Services`: deterministic mock spelling, mock translation, and pasteboard adapters.

## Window and Focus Behavior

The application creates a borderless `NSPanel` with a transparent background and a SwiftUI hosting view. The panel uses floating window level, joins all Spaces, and remains visible when the app is inactive. Its initial frame is centered near the visible screen’s top edge.

The panel does not become key from passive state changes. Typing requires an explicit click in the input field. Result delivery, tab changes triggered by processing, and copied-status updates must not activate the app or steal focus from another application. Buttons may receive focus only after the user directly clicks the panel.

## Visual Design and States

The approved A layout uses a single compact column:

1. Collapsed idle state: icon, placeholder, and input affordance in a thin rounded glass bar.
2. Editing/loading state: input remains visible; a compact progress treatment appears below it.
3. Result state: the panel expands downward and shows `맞춤법 · N` and `번역` tabs.
4. Spelling tab: issue list, original-to-suggestion treatment, and `교정문 복사`.
5. Translation tab: translated text and `번역문 복사`.

The surface uses system materials, a subtle white border, readable dynamic foreground colors, and shadow. The layout adapts to light/dark appearance. Empty input collapses the result area.

## Domain Contracts

`SpellingChecking` accepts a source string and asynchronously returns:

- the original text;
- zero or more issues with range, original fragment, suggestion, and reason;
- the corrected full text.

`Translating` accepts a source string and asynchronously returns source language, target language, and translated text.

Mock implementations are deterministic. Known Korean sample phrases produce meaningful fixed corrections/translations; all other non-empty input receives a clearly labeled mock result derived from the source. The services include a short artificial delay so loading and cancellation behavior can be exercised.

## Data Flow

1. The user clicks the input and types or pastes text.
2. The observable model receives the text and resets the 300 ms debounce task.
3. When the debounce expires, the model cancels the previous request and starts spelling and translation tasks concurrently.
4. Each service updates only its own result state when it completes.
5. The panel expands when either result is loading or available.
6. Copy actions call an injected pasteboard abstraction and show temporary success feedback.
7. Clearing the text cancels work, removes results, and collapses the panel.

Responses carry a request identity so a cancelled or stale task cannot overwrite newer input.

## Error Handling

- Empty/whitespace-only input performs no work.
- Input above 5,000 characters shows a local validation message and does not call services.
- Spelling and translation failures are isolated; one successful tab remains usable if the other fails.
- Each failed tab provides a retry action for the current text.
- Pasteboard failure shows an inline failure status instead of a success message.
- Errors do not dismiss the panel or change application focus.

## Testing Strategy

Automated tests cover:

- deterministic mock spelling and translation outputs;
- whitespace and length validation;
- debounce and cancellation;
- stale-response rejection;
- concurrent independent result states;
- retry behavior;
- pasteboard success and failure feedback;
- panel style mask, floating level, Space collection behavior, and key-window policy;
- view-model expansion and tab selection rules.

Build verification uses `xcodegen generate`, `xcodebuild build`, and `xcodebuild test`. Runtime verification launches the built app and checks top-center placement, glass appearance, typing/paste, both result tabs, copy behavior, always-on-top behavior, and focus preservation when another app is active.

## Acceptance Criteria

- Launching Kotina displays one compact glass bar at the top center of the active screen.
- The bar stays above normal application windows and appears across Spaces.
- It becomes editable only after a direct user click.
- Typing or pasting valid text produces mocked spelling and translation states after the debounce.
- A-style tabs expose both results without showing them side by side.
- Both corrected text and translation can be copied, with visible success or failure feedback.
- Result updates never activate Kotina or move focus away from the user’s current application.
- The generated project builds and all automated tests pass with the documented commands.

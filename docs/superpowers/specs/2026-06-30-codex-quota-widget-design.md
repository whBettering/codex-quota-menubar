# Codex Quota Widget Design

Date: 2026-06-30

## Goal

Build a local macOS floating utility that shows the user's real Codex quota near the top center of the desktop. The widget should feel like a small system companion: always visible, lightweight, and quick to inspect by hovering.

## Non-Goal

This will not embed content into the real macOS system menu bar. macOS does not expose a stable API for occupying arbitrary empty space in the menu bar. The tool will instead use a borderless always-on-top window positioned below the menu bar.

## User Experience

The default state is a compact top-center pill near the menu bar lower edge. It shows concise quota text such as:

```text
Codex 15% / 周 2%
```

When the pointer enters the pill, it expands into a small translucent card. The card shows:

- 5-hour quota usage percentage.
- Weekly quota usage percentage.
- Progress bars for both windows.
- Reset time for each window when available.
- Plan type and reset-credit count when available.
- Last refresh time.
- A refresh control and a quit control.

When the pointer leaves, the card collapses after a short delay. The widget should not steal focus during normal use.

## Data Source

The app will read real quota data from the local Codex app-server protocol:

```text
/Applications/Codex.app/Contents/Resources/codex app-server --stdio
```

The app sends JSON-RPC requests:

- `initialize`
- `initialized`
- `account/rateLimits/read`

The quota response contains the `codex` rate-limit bucket with:

- `primary.usedPercent`, `primary.windowDurationMins`, `primary.resetsAt`
- `secondary.usedPercent`, `secondary.windowDurationMins`, `secondary.resetsAt`
- `planType`
- `rateLimitResetCredits.availableCount`

The primary window maps to the 5-hour quota when `windowDurationMins` is `300`. The secondary window maps to the weekly quota when `windowDurationMins` is `10080`.

## Architecture

Use a native Swift package executable with AppKit and SwiftUI:

- `CodexQuotaApp`: app entry point and application lifecycle.
- `FloatingPanelController`: creates and positions the borderless always-on-top panel.
- `QuotaView`: SwiftUI compact and expanded UI.
- `QuotaStore`: observable state, refresh timer, loading and error state.
- `CodexAppServerClient`: launches the local Codex app-server, sends JSON-RPC requests, parses responses.
- `QuotaFormatting`: formats percentages, reset timestamps, and window labels.

The app will avoid reading Codex auth files directly. It relies on the app-server to use the already configured local account.

## Refresh Behavior

On launch, the app fetches quota immediately. It then refreshes every 2 minutes. The refresh button triggers an immediate fetch.

If fetching fails, the compact pill shows:

```text
Codex --
```

The expanded card shows the latest successful data if one exists, plus the current error message. If no data exists yet, it shows a short unavailable state.

## Window Behavior

The floating panel will:

- Be borderless and transparent.
- Stay above regular app windows.
- Appear on all spaces where practical.
- Position itself at the top center of the main screen, just below the menu bar safe area.
- Reposition when screen parameters change.

The panel will not claim to be part of the system menu bar.

## Testing

Core non-UI behavior will be covered with Swift tests:

- Parsing `account/rateLimits/read` responses.
- Mapping primary and secondary windows to display models.
- Formatting reset timestamps and percentages.
- Handling malformed responses and app-server errors.

Manual verification will cover:

- `swift test`
- `swift build`
- Running the widget locally.
- Confirming real quota data appears from the local Codex app-server.

## Deferred Enhancements

Use the default top-center position for the first version. Drag-to-reposition and launch-at-login can be added later if the first version feels useful.

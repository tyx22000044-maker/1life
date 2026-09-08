# 1Life Refactor Log

## Goal

Record low-risk refactor patterns that improve maintainability and likely reduce SwiftUI compile pressure, so the same strategy can be reused across the `1App Family`.

## Principles

- Prefer structure-only refactors before behavior changes.
- Split by responsibility, not by arbitrary line count.
- Keep one file responsible for page orchestration.
- Move large self-contained UI blocks into sibling files in the same feature folder.
- Move editors, sheets, and confirmation flows out of the main page file early.
- Avoid introducing a new architecture unless the existing boundaries are already failing.

## Phase 1 Candidates

High-priority large files in `1Life`:

1. `Views/AIChat/AIChatView.swift`
2. `Views/Settings/SettingsView.swift`
3. `Views/Food/MealCardView.swift`
4. `Views/Dashboard/DashboardView.swift`

These files are large, frequently touched, and combine SwiftUI view composition with state coordination and side effects.

## 2026-07-01: AI Chat Split

### Before

- `AIChatView.swift` contained:
  - page shell
  - header and empty state
  - chat bubble rendering
  - meal confirmation cards
  - manual meal editor sheets
  - parsed food item editor sheets

This made the file a catch-all for both page orchestration and multiple secondary workflows.

### Action

Split `Views/AIChat/AIChatView.swift` into:

- `Views/AIChat/AIChatView.swift`
  - page shell
  - state
  - event handlers
  - input flow coordination
- `Views/AIChat/AIChatComponents.swift`
  - configuration header
  - empty state
  - feature cards
  - chat bubble rendering
- `Views/AIChat/AIChatMealReviewComponents.swift`
  - meal confirmation
  - meal identification review
  - quantity slider
- `Views/AIChat/AIChatMealEditors.swift`
  - manual meal editor sheet
  - parsed food item editor sheet

### Why this split works

- The page shell stays readable.
- Secondary review and editing flows can evolve without bloating the entry view.
- Compile invalidation should become more localized when editing one workflow area.
- This pattern is reusable for other apps with one heavy root page and multiple attached sheets.

## Reusable Family Pattern

For any oversized feature file, prefer this order:

1. Keep the root file as orchestration only.
2. Move passive display components into `FeatureNameComponents.swift`.
3. Move review / confirmation flows into `FeatureNameReviewComponents.swift`.
4. Move editors / sheets / pickers into `FeatureNameEditors.swift` or `FeatureNameSheets.swift`.
5. Only after that, consider extracting service or coordinator logic.

## Next Suggested Targets

- `1Life/1Life/Views/Settings/SettingsView.swift`
- `1Life/1Life/Views/Food/MealCardView.swift`
- `1Life/1Life/Views/Dashboard/DashboardView.swift`

## Notes

- This log is intentionally practical, not architectural doctrine.
- Success should be measured by smaller files, clearer ownership, and better day-to-day edit/build feedback.

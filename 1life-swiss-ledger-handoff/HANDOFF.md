# 1Life — Swiss Ledger visual pass (handoff)

**Prepared:** 2026-09-09 · **For:** any coding agent (Claude Code or otherwise) picking this up as a fresh session · **Repo:** `/Volumes/ExtraStorage/XcodeProject/1Life` (git repo, 1 commit, clean tree — see "Git state" below)

This is the **2nd of 7** app-level handoffs for the same family-wide direction. 1Cash's equivalent pilot handoff already exists as a separate package — the two are independent; nothing here depends on the 1Cash work being done first or landing a particular way. If useful for cross-checking consistency later, the 1Cash package is `1cash-swiss-ledger-handoff.zip`, prepared the same day.

---

## 0. The one rule that matters most

> **This is a re-skin, not a redesign.** Change colors, type, corner radii, borders/shadows, spacing tokens, and the visual treatment of status tags/buttons/panels. Do **not** change:
> - which tab shows which content, or the tab order (今日 · 饮食 · AI · 我的 · 设置 stays exactly as-is)
> - navigation structure (NavigationStack usage, sheet vs. push, screen hierarchy)
> - what data appears where, what any button/row/gesture *does*
> - view models, services, SwiftData models, business logic of any kind — **especially** the nutrition calculation logic (TDEE, Mifflin-St Jeor, macro targets) and the AI meal-recognition pipeline
> - existing feature behavior, copy/wording of user-facing content (unless a string is purely a design artifact like a status-tag label)
>
> If implementing the new visual language seems to require touching interaction logic, **stop and flag it rather than deciding unilaterally** — that's a product decision, not a styling one.

---

## 1. Background (context only, nothing here needs to be redone)

1Life is part of a 7-app family ("1App Family": 1Cash, 1Day, 1Fit, 1Life, 1Parcel, 1Pet, 1Track) that mostly shares a design-token system. **1Life is in fact the reference/canonical implementation** that the other apps' `FamilyUI` tokens are diffed against (see `docs/1LIFE_UI_VISUAL_CONSISTENCY_REVIEW.md` copies inside the *other* apps' repos — 1Life's own repo doesn't need one, it *is* the baseline). The user chose a new direction called **"Swiss Ledger"** (cold, grid-first, grotesk type, single accent, hairline borders) to replace the current warm-parchment system across the whole family, out of 5 proposed directions. Nine mockup screens were built to pressure-test it (7 app flagship screens + 2 shared-pattern screens), then the user asked for this same direction to be handed off app-by-app to separate coding sessions, each pursuing pure visual re-skin only, one app at a time.

## 2. Scope for *this* handoff

**In scope:** `/Volumes/ExtraStorage/XcodeProject/1Life` only.

Priority order:
1. Shared design tokens — `1Life/1Life/Extensions.swift` (this is the file the whole family's `FamilyUI` originates from — see §4). Everything else depends on this being right first.
2. Today Dashboard — `1Life/1Life/Views/Dashboard/DashboardView.swift` — this app's flagship screen for the direction; see `mockups/1life-dashboard.html`.
3. Settings — `1Life/1Life/Views/Settings/*.swift` (`SettingsView`, `NutritionGoalSettingsView`, `SettingsDataSection`, `SettingsInfoSheets`, `AIConfigurationSettingsView`, `SettingsDataCoordinator`, `BodyParamsSettingsView`) — see `mockups/settings-shared.html`.
4. AI Chat's confirmation-card visual treatment — `1Life/1Life/Views/AIChat/*.swift` (`AIChatView`, `AIChatComponents`, `AIChatMealEditors`, `AIChatMealReviewComponents`) — see `mockups/aichat-shared.html`. Only the meal-confirmation card's *look*, not the recognition/parsing logic.
5. Food Timeline (`Views/Food/`) and My Life (`Views/MyLife/`) — lower priority, do these last if time allows; not individually mocked up, lean on the tokens + patterns from steps 1–4.

**Out of scope:** 1Cash, 1Day, 1Fit, 1Parcel, 1Pet, 1Track. Do not edit anything outside `/Volumes/ExtraStorage/XcodeProject/1Life`. Other apps' `Extensions.swift` files currently mirror this one closely — **don't try to keep them in sync during this pass**; each app is getting this direction on its own independent track, so temporary divergence between apps is expected and fine, not a bug.

## 3. Reference mockups (attached)

`mockups/` has 9 standalone, dependency-free HTML files — open directly in a browser, no server needed. Static visual references (plain HTML/CSS), not code to port literally.

| File | What it shows | Relevant to this task? |
|---|---|---|
| `mockups/1life-dashboard.html` | 1Life's Today Dashboard in Swiss Ledger | **Yes — primary reference** |
| `mockups/settings-shared.html` | Settings screen (shown as a 1Cash instance — same structure applies here, swap the content groups per §4/§5) | **Yes — primary reference for structure**, not literal content |
| `mockups/aichat-shared.html` | AI Chat: bubbles + one structured confirmation card (shown with a 1Cash transaction — 1Life's equivalent is a parsed meal, see §5) | **Yes — primary reference for structure**, not literal content |
| `mockups/1cash-ledger.html`, `1day-today.html`, `1fit-closet.html`, `1parcel-parcels.html`, `1pet-today.html`, `1track-subscriptions.html` | The other 6 apps' flagship screens | Context only — shows how the same tokens flex across apps. **Not part of this task.** |

The accent color in these exports is already resolved to a literal `#C4321F` — see §5, it's not finalized.

## 4. Current state — what's already real in the code

Read directly and in full from `1Life/1Life/Extensions.swift` (this is the actual source, not a secondhand summary):

```swift
enum FamilyTypography {
    static let hero = Font.system(size: 38, weight: .black, design: .rounded)
    static let pageTitle = Font.system(size: 32, weight: .black, design: .rounded)
    static let sectionLabel = Font.system(size: 11, weight: .semibold, design: .rounded)
    static let icon = Font.system(size: 14, weight: .semibold, design: .rounded)
    static let actionIcon = Font.system(.caption, design: .rounded, weight: .black)
    static let badge = Font.system(size: 11, weight: .semibold, design: .rounded)
    static let button = Font.system(.subheadline, design: .rounded, weight: .black)
}

enum FamilyUI {
    // pageBackground: light #F4F1EB (warm parchment) / dark #161410 (warm near-black)
    // panelBackground: light white / dark #1F1D1A
    // panelMutedBackground: light #F0EDE7 / dark #2A2724
    // panelBorder: black 14% (light) / white 12% (dark)
    // divider: black 10% (light) / white 8% (dark)
    static let accent = Color(hex: "1e4ed8")   // blue
    static let success = Color(hex: "2f7a63")  // teal-green
    static let warning = Color.orange
    static let danger = Color.red
    static let subtleText = Color(.systemGray)
    static let panelCornerRadius: CGFloat = 12
    static let controlCornerRadius: CGFloat = 10
    static let badgeCornerRadius: CGFloat = 6
    static let iconBoxSize: CGFloat = 34
}

// Plus a global `.appTypography()` view modifier (SF Rounded everywhere),
// a custom `AppSwitchStyle` toggle (50×30 rounded-rect track, not a native Capsule),
// and a `KeyboardDoneButton` badge component.
```

There's also an older, separate `AppCornerRadius`/`AppSpacing` enum pair still in use alongside `FamilyUI` (card: 14, cardLarge: 18, button: 14, icon: 10, photo: 12; pageHorizontal: 16, cardPadding: 16, sectionSpacing: 12, etc.) — both are live, don't assume one has replaced the other.

**1Life-specific: nutrient category colors** (`NutrientKey.spotlightColor` in `Extensions.swift`):

| Nutrient | Current color |
|---|---|
| Protein | `FamilyUI.accent` (blue) |
| Carbs | `.orange` |
| Fat | `#9a7b22` |
| Fiber | `FamilyUI.success` (teal-green) |
| Sodium | `#8b3a8b` |
| Sugar | `#c94c7a` |
| Cholesterol | `#c94c3a` |
| Caffeine | `#6f5a46` |
| Tea polyphenols | `#4a7c59` |

**Known components** (confirmed present in `1Life/1Life/Components/`): `SystemPanel.swift` (`SystemPanel`, `SystemPageHeader`, `SystemPanelDivider`, `SystemStatusBadge`), `PrimaryButton.swift`, `AppSettingsRow.swift`, `AppEmptyStateView.swift`, `AppErrorBanner.swift`, `SectionHeader.swift`, `UserAvatarView.swift`, `SystemTextField.swift`.

**1Life's existing status-tag vocabulary** (from `docs/UI_STYLE_GUIDE_V2.md` §7.5 — already real, keep it): `SYNCED`, `PENDING`, `OVER`, `UNSET`, `LOGGED`. The mockup uses `LOGGED` / `UNSET` / `PHOTO`(AI-sourced) — reconcile `SYNCED` and `OVER` in as needed (`SYNCED` for Apple Health sync state, `OVER` for a nutrient that's exceeded its target).

`docs/UI_STYLE_GUIDE_V2.md` and `docs/1Life 设计自述.md` describe *earlier* proposed directions — both are superseded by Swiss Ledger's specific color/shape choices below; their structural ideas (hero calorie number, macro progress rows, meal timeline, "克制/事实导向" copy tone) carry forward and match the mockup. Not a blocker to update those docs, just not required for this pass.

## 5. Target design tokens — Swiss Ledger

Same family-wide tokens as every other app's pass (this table is identical across all 7 handoffs on purpose — it's the one thing that must not drift between apps even though the apps are being done independently):

| Token | Light | Notes |
|---|---|---|
| Page / paper background | `#FAFAF7` | replaces `#F4F1EB` |
| Ink (primary text, borders, rules) | `#0B0B0A` | replaces near-black `.primary` |
| Ink, soft (secondary text) | `#6E6E68` | |
| Ink, faint (tertiary / inactive tab labels) | `#9C9B90` | |
| Hairline, regular | `rgba(11,11,10,0.14)` | panel/section borders |
| Hairline, subtle | `rgba(11,11,10,0.10)` | row dividers |
| Hairline, strong | `rgba(11,11,10,0.16)` | tab bar top border |
| **Accent (single signal color)** | `#C4321F` | **open decision, same as every other app — see below** |
| Corner radius, panels | `0–4pt` | down from 12pt |
| Corner radius, controls/tags | `0–2pt` | down from 10pt; tags are rectangles, not capsules |
| Borders vs. shadows | hairline `1px` borders, **no** drop shadows | |
| Numerals | tabular/monospaced digits everywhere (`.monospacedDigit()`) | especially calorie/macro numbers |
| Type | a grotesk, not `design: .rounded` | see open decision below |
| Status tags | outlined rectangle, uppercase, ~8.5–9pt, tracked | replaces filled/toned `SystemStatusBadge` |

**1Life-specific exception — nutrient colors stay multi-hue.** Unlike the family's general "one accent only" rule, the nutrient category colors in §4 are *informational* color-coding (which macro is which), the same category of exception as 1Fit's real garment-color swatches — don't collapse them to the single signal accent. Do desaturate/mute them to sit comfortably in the cooler paper/ink palette, and restrict them to small uses only (thin progress-bar fills, tiny inline labels) — never large fills, per the existing rule in `docs/UI_STYLE_GUIDE_V2.md` §4.4, which already applies here and doesn't need to change.

**Note on the Dashboard mockup specifically:** `mockups/1life-dashboard.html` drew all three macro bars in flat ink-black for prototype simplicity. That was a shortcut for the mockup, not a spec — implement the real per-nutrient colors from §4 (muted per above), don't port the mockup's monochrome bars literally.

**Dark mode — not yet designed**, same gap as every other app in this family (see 1Cash's handoff for the proposed starting values if you have it; otherwise: near-black paper, near-white ink, white-alpha hairlines, brightened accent — follow 1Life's existing `UIColor { traitCollection in ... }` dynamic-provider pattern already in `Extensions.swift` rather than inventing a new mechanism).

**Two open decisions, same as every app in this family — don't decide unilaterally, confirm or ask:**

1. **Accent color** — mockups default to `#C4321F` (print red); alternates considered were `#0B0B0A` (ink only), `#1E4ED8` (family's existing blue), `#8A6A1F` (muted gold). Not finalized.
2. **Typeface** — mockups use Archivo (web-only) for preview purposes. For SwiftUI: either drop `design: .rounded` and use plain system San Francisco (lower risk, recommended default), or bundle a real grotesk like Archivo (OFL, embeddable, more distinctive, adds app size + a loading step).

## 6. Suggested implementation order

1. Confirm the two open decisions in §5 (or ask before assuming).
2. Update the token layer only (`Extensions.swift`) — this alone shifts everything using `FamilyUI`/`FamilyTypography`, which is most of the app.
3. Update `SystemStatusBadge` to the outlined-rectangle style — reused everywhere status tags appear.
4. Implement Today Dashboard fully against `mockups/1life-dashboard.html`, including the real (muted, not monochrome) nutrient colors per §5.
5. Checkpoint / review before continuing.
6. Settings, then the AI Chat meal-confirmation card's visual treatment, then Food Timeline / My Life if there's runway.

## 7. Definition of done for this pass

- [ ] Project still builds and runs (iOS 17+ target as currently configured).
- [ ] No changes to `Models/`, `ViewModels/`, `Repository/`, `Services/` — especially nutrition/TDEE calculation logic and AI meal-recognition parsing — unless a file is *purely* a hardcoded color/style constant with no logic.
- [ ] Tab bar order, tab contents, and navigation flow are structurally identical to before — only visual treatment differs.
- [ ] Every existing user-facing string, gesture, and button action still does exactly what it did before.
- [ ] All calorie/macro/count numerals use tabular figures and align in columns where stacked.
- [ ] Status tags are outlined, not filled; no rounded pill shapes remain in the touched screens.
- [ ] Nutrient category colors are preserved (muted, small-scale) rather than collapsed into the single accent.
- [ ] Dark mode still works (draft values acceptable pending review) — don't regress to light-only.
- [ ] Existing tests still pass unchanged.
- [ ] A couple of real-app screenshots compared against the matching `mockups/*.html`, to sanity-check the web-mockup-to-native translation.

## 8. Git

`/Volumes/ExtraStorage/XcodeProject/1Life` already has git initialized with one commit (`d74bcd6`, "初始化1Life健康管理App基础框架与核心模块") and a clean working tree as of 2026-09-09 — no baseline-commit step needed, just branch or commit incrementally as normal. No remote configured; don't add one or push without asking.

## 9. If you're continuing in Claude Code specifically

No design-exploration skills needed (`taste`, `design`) — the direction is already specified above, this is implementation against a spec. Running `code-review` on the diff before calling this done is reasonable given the size of the change. On another platform: whatever this project's normal lint/build/test checks are, plus a manual diff read against the "definition of done" list.

## 10. Optional extra reference (only if this session can reach claude.ai)

- 5-direction comparison this was chosen from: `https://claude.ai/code/artifact/aa0d9c88-22c0-42d5-8d4e-937702b035a8`
- Full 9-screen canvas (live accent-color swatch per screen): `https://claude.ai/code/artifact/7d9055b8-7eff-45ad-b5bf-58e01e16ad60`

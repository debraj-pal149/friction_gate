# Friction — Full UI Redesign Brief for Claude

You are redesigning the **UI/UX polish** of Friction (iOS, SwiftUI).  
People who have used / seen the app say the **UI is not good enough** for the product’s ambition. The product logic (blocking, challenges, wake detection, delete friction) can stay — the **visual system, hierarchy, density, and consistency** need a serious upgrade.

The user will attach **screenshots**. Treat screenshots as ground truth for what it looks like today; this brief is the complete inventory of what exists in code so you don’t miss surfaces.

**Read this entire brief before proposing or coding.**  
First respond with a **redesign plan** (visual direction + per-screen changes). Wait for approval before a massive rewrite unless the user says “implement.”

---

## Product context (don’t redesign the idea — redesign the feel)

**Friction** makes phone use intentional: block apps under conditions, force a challenge to unlock, auto re-lock after a session.

Brand promise (already in app):
> Make phone use intentional, not automatic.

Tone today: dark, mint/green accents, “tech productivity.” Feedback says it still feels like a **generic Settings / CRUD list app**, not a sharp consumer product.

---

## Hard constraints

### Do NOT change (unless redesign requires tiny wiring)
- Screen Time / FamilyControls / ManagedSettings / DeviceActivity behavior
- Challenge logic, escalation math, session relock
- Wake detection architecture
- Delete cooldown + phrase confirmation **behavior** (you may restyle the UI heavily)
- App Group persistence, extensions’ functional behavior
- Multi-app rule fan-out on save

### DO change
- Visual design system (type, spacing, color usage, components)
- Home, builder, options, unlock, onboarding, settings, about presentation
- Empty states, toolbars, badges, status indicators
- Inconsistencies (CTA shapes, shield colors, duplicate About/Onboarding layouts)
- Hierarchy so the app feels intentional, calm, premium — not a form dump

### Platform
- SwiftUI, iOS 16+
- Existing theme tokens live in:
  - `FrictionGate/Theme/AppColors.swift`
  - `FrictionGate/Theme/ColorTemplates.swift`
  - `FrictionGate/Extensions/Color+Theme.swift`
- Prefer evolving `Color.app*` + shared components over one-off hex in views
- System `FamilyActivityPicker` cannot be fully restyled — design around it

### Design taste (match user frontend rules)
- Avoid generic AI-slop UI: purple gradients, cream+terracotta, newspaper layouts, glow spam, pill-cluster dashboards
- Prefer **one clear composition per screen**, strong hierarchy, restrained motion
- Cards only when they help interaction; don’t nest card-in-list-in-card
- Brand should be visible on home, not only in onboarding
- Keep dark-capable theme; mint/green identity can stay but must feel deliberate

---

## Current design system (what code does today)

### Tokens (`Color.app*`)
| Token | Use |
|---|---|
| `appAccent` | CTAs, active controls, links |
| `appOnAccent` | Text on accent (luminance-aware) |
| `appAccentFill` / `appAccentBright` | Icon wells, gradients |
| `appPrimary` / `appSecondary` / `appTertiary` | Text hierarchy |
| `appBackground` / `appSurface` / `appSurface2` / `appSurface3` | Surfaces |
| `appBorder` | Dividers / strokes |
| `appDestructive` / `appSuccess` / `appWarning` | Semantic |

Default palette (Template 6): near-black navy bg, mint green accent (`#B2FF9E`-ish), teal feature accent.

### Shared patterns already in code
- `inkBackground()`, `surfaceRow()`, `glassCard()`, `accentGlow`, `ThemeBadge`
- Difficulty badges: `LVL N EASY|MEDIUM|HARD|EXTREME`
- Almost everything is `.insetGrouped` List
- Primary CTA: full-width rounded rect ~14–16pt, accent fill
- Toolbar: circular 34pt icon buttons
- SF Symbols as product language (`lock.shield`, walk, timer, flame)

### Theme UX oddity
Home toolbar has a **paint palette** that cycles 6 color templates + light/dark override. Feels like a **dev toy in primary chrome**, not a consumer settings control.

---

## App structure (navigation)

```
ContentView
├── HomeView (NavigationStack) — main landing
│   ├── sheet: RuleBuilderView (5 steps)
│   ├── sheet: GlobalSettingsView
│   ├── sheet: RuleOptionsView
│   ├── sheet: AboutFrictionView
│   ├── sheet/fullScreen: UnlockView (also via AppState)
│   └── popover: theme cycle + color scheme toggle
└── fullScreenCover (first launch):
    OnboardingView → PermissionPrimerView
```

No tab bar. Single home list is the whole app.

---

## Screen-by-screen inventory

### 1. Onboarding — `Views/Onboarding/OnboardingView.swift`
**Purpose:** First-run brand + value props.

**Layout:** Full-bleed background, ScrollView, large shield icon in accent well, title “Friction”, tagline, glass card with 4 feature rows, privacy footer, bottom CTA **“Let's Go”**.

**Feature rows:**
1. You choose what's blocked  
2. Earn access, don't just tap past  
3. Sessions keep it honest  
4. Escalation raises the stakes  

**Problems:** CTA is inside the scroll (easy to miss). Content is duplicated almost 1:1 with About. Feels like a feature checklist, not a memorable first frame.

---

### 2. Permission primer — `Views/Onboarding/PermissionPrimerView.swift`
**Purpose:** Explain Family Controls before system dialog.

**Layout:** Similar scroll; gradient icon well (inconsistent with onboarding); headline “One permission required”; feature glass; warning callout if user taps Don’t Allow; disclosure; CTA **“Enable Friction”**.

**Problems:** Icon treatment differs from onboarding/about. Body may show raw `**markdown**` asterisks. System permission UI will appear after — primer must feel trustworthy, not scary-spammy.

---

### 3. Home — `Views/Home/HomeView.swift` + `RuleRowView.swift`
**Purpose:** List of rules; primary daily surface.

**Chrome:**
- **No navigation title** — blank nav with 4 toolbar icons only  
  - Leading: Settings (gear), About (info)  
  - Trailing: Theme (paint palette), Add (+)
- Empty state: large shield, “No Rules Yet”, capsule **“Add Rule”**
- List: insetGrouped of rule rows, sorted by difficulty

**Rule row (`RuleRowView`):**
```
[App icon]  App name
            condition · challenge (1-line caption)
            ● APP BLOCKED | APP UNBLOCKED          ›
```
- Row is a **rounded card inside a list cell** (nested surfaces)
- Status is **ALL CAPS** with colored dot (destructive vs success)
- App name uses FamilyControls `Label(token)` scaled down

**Problems (likely why people say UI isn’t good enough):**
1. Home has **no brand / title / greeting** — looks like an unfinished admin panel  
2. Four cryptic icon buttons; theme control shouldn’t dominate  
3. Nested card-in-list feels heavy and generic  
4. ALL-CAPS status is loud and gamey  
5. Caption truncates multi-condition rules into one weak line  
6. Empty-state CTA is a **capsule**; everywhere else uses rounded rect — inconsistent  
7. No sense of “your intentional day” — just a CRUD list  

**This is the highest-priority screen to redesign.**

---

### 4. About — `AboutFrictionView` (inside `HomeView.swift`)
Sheet titled “About Friction”, Done button, same 4 features as onboarding, privacy line.

**Problem:** Duplicate of onboarding; slight size differences (icon 80 vs 88, card radius 14 vs 16). Should share one component or be intentionally different.

---

### 5. Rule Options — `Views/Home/RuleOptionsView.swift`
Sheet: “Rule Options”.

**Sections (insetGrouped):**
1. App header (icon, name, “Active” badge, difficulty badge)  
2. **Unblock App** — accent button → closes sheet, starts unlock flow  
3. When It Blocks — condition list  
4. Unlock Challenges — with difficulty badges  
5. Session & Escalation  
6. History (unlock count, last unlocked, created)  
7. Delete Rule  

**Delete flow (intentional friction):**
1. Tap Delete → **60 second cooldown** with timer + progress (“reconsider”)  
2. Then multiline paste-blocked text field for a **very long emotional confirmation phrase**  
3. Character count + Confirm Delete when matched  

**Problems:**
- Feels like another Settings dump  
- “Active” badge is always Active (pausing removed) — meaningless  
- Delete UI is product-critical but visually ugly / essay-dense inside a list  
- Unblock + Delete buttons were size-matched recently; still list-row CTAs, not a clean action hierarchy  

---

### 6. Rule Builder — `Views/RuleBuilder/*`
Container: `RuleBuilderView` with **5-step indicator** (numbered circles + bars).

| Step | Screen | Content |
|---|---|---|
| 1 | `AppPickerView` | System FamilyActivityPicker; multi-app allowed |
| 2 | `ConditionPickerView` | Toggles: time window + day chips, after wake, before sleep, daily open limit |
| 3 | `ChallengePickerView` | Challenges ordered easy→hard with LVL badges; steppers |
| 4 | `EscalationPickerView` | Session duration + escalation toggle/window |
| 5 | `RuleReviewView` | Summary prose + Save Rule |

Toolbar: Cancel (destructive red) / Back / Next (disabled when invalid).

**Problems:**
- Feels like **five Settings forms**, not a guided creation experience  
- Step chrome is busy (glowing dots) without helping comprehension  
- FamilyActivityPicker is system-styled — surrounding chrome must absorb that jolt  
- Next disabled with no explanation why  
- Day chips / selected states may use wrong on-accent text color  
- Review is another list — not a satisfying “commit” moment  

---

### 7. Unlock flow — `Views/Unlock/*`
Presented fullScreenCover or sheet. Title “Unlock {app}”. Cancel. Optional escalation banner (flame, warning color). Multi-challenge progress (“Challenge i of n”).

| Challenge | View | UI gist |
|---|---|---|
| Steps | `StepChallengeView` | Large ring + live step count |
| Maths | `MathsChallengeView` | Big equation card + answer field |
| Type sentence | `TypeSentenceView` | Char-by-char match, paste blocked |
| Wait | `WaitChallengeView` | Countdown ring |
| Write reason | `WriteReasonView` | TextEditor, min chars |

Success: checkmark, “Unlocked”, auto-dismiss ~1.8s.

**Problems:** Challenge screens vary in polish; some feel like utility forms. Escalation banner is functional but crude. Success moment is brief and forgettable. These screens are the **emotional core** of the product — they should feel excellent.

---

### 8. Settings — `Views/Settings/GlobalSettingsView.swift`
Wake-up detection toggle, idle hours, wake window start/end, sleep time, status string.

**Problems:** Pure Settings list. Footer text is long/technical (HealthKit / DeviceActivity / fallback). Fine for power users; intimidating for everyone else. Theme controls are **not** here (they’re on home) — wrong place mentally.

---

### 9. System Shield overlay — `FrictionGateShieldConfig/ShieldConfigurationExtension.swift`
When a blocked app is opened: blur, lock icon, “Switch to Friction”.

**Critical problem:** Icon/button colors are **hardcoded electric blue**, not the app’s mint accent. Feels like a different product at the exact moment of highest emotion.

---

### 10. Orphan UI
`Views/Pause/PauseRuleView.swift` — pause flow still in codebase but **not wired** (pausing removed). Don’t revive unless product asks; can ignore or delete in cleanup.

---

## Cross-cutting issues (the “UI not good enough” diagnosis)

1. **No hero / brand on the main screen** — Friction’s identity dies after onboarding  
2. **Everything is insetGrouped Lists** — reads as Apple Settings clone  
3. **Nested surfaces** — cards inside list cells, glass cards inside scrolls  
4. **Inconsistent CTAs** — capsule vs rounded rect vs `.borderedProminent`  
5. **Gamey chrome** — `LVL N EXTREME`, ALL-CAPS `APP BLOCKED`, glowing step dots  
6. **Dev controls in primary UI** — template cycler on home toolbar  
7. **Shield color drift** — blue shield vs green app  
8. **Duplicate marketing screens** — Onboarding ≈ About  
9. **Weak empty state** — doesn’t sell the product  
10. **Builder & options feel bureaucratic** — high friction UX without high craft  
11. **Typography is all system default sizes** — no distinctive type hierarchy  
12. **Spacing/density** — rows feel cramped; captions truncated; little breathing room  

---

## Redesign goals (definition of done)

After redesign, a stranger should open the app and feel:

1. **This is a deliberate product**, not a student Settings demo  
2. Home communicates **brand + current state** in one glance  
3. Creating a rule feels **guided and calm**, not like filling tax forms  
4. Unlock challenges feel **focused and serious** (still hard, but beautiful)  
5. One visual language from onboarding → home → shield → unlock  
6. Screenshots look good enough for **India builds with Claude / App Store**

### Concrete success criteria
- [ ] Home has clear title/brand treatment and cleaner rule presentation (no nested card soup)  
- [ ] Status readable without shouting ALL CAPS  
- [ ] Single CTA language (shape, type, padding) app-wide  
- [ ] Shield overlay matches app accent  
- [ ] Builder steps feel lighter (progress + one job per step), better empty/disabled guidance  
- [ ] Options sheet has clear primary action (Unblock) vs dangerous action (Delete), delete flow restyled but equally hard  
- [ ] Theme cycling moved out of primary home chrome (e.g. Settings) or simplified to light/dark only  
- [ ] Onboarding/About share components or intentional differentiation  
- [ ] Unlock success moment has presence  
- [ ] Dark + light both work; accent contrast preserved (`appOnAccent`)  

---

## Suggested redesign direction (starting point — you may improve)

Propose something in this family (not mandatory):

**“Intentional instrument”** — calm dark surfaces, one accent, large type for app names, soft status chips (not sirens), home as a short stacked list of *commitments* rather than admin rows. Builder as a focused wizard with generous whitespace. Unlock as full-bleed ritual screens (meter, timer, prompt) with minimal chrome.

Avoid: dashboard widgets, stat strips, neon everything, extra illustration clutter, random gradients.

---

## File map (edit these)

```
FrictionGate/Views/Home/HomeView.swift
FrictionGate/Views/Home/RuleRowView.swift
FrictionGate/Views/Home/RuleOptionsView.swift
FrictionGate/Views/Onboarding/OnboardingView.swift
FrictionGate/Views/Onboarding/PermissionPrimerView.swift
FrictionGate/Views/RuleBuilder/*.swift
FrictionGate/Views/Unlock/*.swift
FrictionGate/Views/Settings/GlobalSettingsView.swift
FrictionGate/Theme/AppColors.swift
FrictionGate/Theme/ColorTemplates.swift
FrictionGate/Extensions/Color+Theme.swift
FrictionGateShieldConfig/ShieldConfigurationExtension.swift
FrictionGate/FrictionGateApp.swift          # global nav appearance if needed
```

---

## How to work with the screenshots

The user will attach screenshots of the current UI. For each screenshot:
1. Name the screen  
2. Call out what’s weak in that frame  
3. Sketch the replacement hierarchy (what stays, what goes, what grows)  

Then produce a **unified redesign plan** covering home first, then unlock, then builder, then options/onboarding/shield.

---

## What to output first (before coding)

1. **Visual direction** (1 short paragraph + color/type rules)  
2. **Component changes** (buttons, badges, list rows, step chrome)  
3. **Per-screen redesign notes** (Home → Unlock → Builder → Options → Onboarding → Shield)  
4. **Explicit non-goals**  
5. **Implementation order** (smallest high-impact diffs first)

After user approval, implement in that order.

---

## One-sentence brief

**Friction’s product is sharp; its UI still looks like a themed Settings CRUD app — redesign hierarchy, chrome, and craft so home, unlock, and builder feel like one intentional consumer product, without changing the underlying blocking/challenge behavior.**

# FrictionGate — Full Technical Architecture
*Master reference for Cursor, Xcode setup, and development order*

---

## 1. App Identity

**App Name (working):** FrictionGate  
**Bundle ID:** com.debrajpal.frictiongate  
**Minimum iOS:** 16.0  
**Language:** Swift 5.9  
**UI Framework:** SwiftUI  
**Architecture Pattern:** MVVM (Model–View–ViewModel)

---

## 2. Apple Frameworks & Entitlements Required

### Frameworks (import in code)
| Framework | Purpose |
|---|---|
| `FamilyControls` | Request permission to manage app usage |
| `ManagedSettings` | Actually apply the block to an app |
| `DeviceActivity` | Schedule when blocks start/stop, monitor app open counts |
| `HealthKit` | Read step count from Apple Health |
| `CoreMotion` | Pedometer as fallback if HealthKit is unavailable |
| `SwiftUI` | All UI |
| `Combine` | Reactive data flow between ViewModel and View |
| `UserNotifications` | Local notifications (block started, challenge complete, etc.) |
| `BackgroundTasks` | Background refresh for step counts and schedule checks |
| `CoreLocation` | (Optional V2) Geo-fence blocks |

### Entitlements Required (must be added in Xcode + Apple approval)
| Entitlement | How to get it |
|---|---|
| `com.apple.developer.family-controls` | Request at developer.apple.com — one-time approval |
| `com.apple.developer.healthkit` | Enable in Xcode → Signing & Capabilities → HealthKit |
| `com.apple.developer.healthkit.background-delivery` | Same as above, sub-option |
| Background Modes → Background fetch | Enable in Xcode → Signing & Capabilities |
| Background Modes → Background processing | Same |

### The Family Controls Entitlement — What To Do Right Now
1. Go to developer.apple.com → Account → Certificates, Identifiers & Profiles
2. Find your App ID (or create a new one for FrictionGate)
3. Under Capabilities, look for Family Controls — request it
4. Apple reviews this manually, usually within a few days
5. Once approved, enable it in Xcode under Signing & Capabilities

---

## 3. Project Structure (Folder & File Layout)

Tell Cursor to create exactly this structure:

```
FrictionGate/
├── FrictionGateApp.swift              # App entry point, initialise FamilyControls auth
├── ContentView.swift               # Root navigation container

├── Models/
│   ├── Rule.swift                  # Core data model — the Rule struct
│   ├── BlockCondition.swift        # Enum: timeWindow, afterWakeUp, beforeSleep, dailyOpenLimit
│   ├── UnlockChallenge.swift       # Enum: steps, maths, typeSentence, wait, writeReason
│   ├── UnlockAttempt.swift         # Tracks escalation state per rule
│   └── AppSettings.swift           # Global settings: wake-up window, sleep time

├── Persistence/
│   └── RuleStore.swift             # Save/load rules using UserDefaults + JSON encoding

├── ViewModels/
│   ├── HomeViewModel.swift         # List of rules, toggle pause, delete
│   ├── RuleBuilderViewModel.swift  # State for the Add/Edit rule flow
│   ├── UnlockViewModel.swift       # Manages unlock challenge state and step counting
│   └── WakeUpViewModel.swift       # Detects wake-up from phone inactivity

├── Views/
│   ├── Home/
│   │   ├── HomeView.swift          # List of rules
│   │   └── RuleRowView.swift       # Single row in the list
│   ├── RuleBuilder/
│   │   ├── RuleBuilderView.swift   # Parent container for the form flow
│   │   ├── AppPickerView.swift     # Wraps FamilyActivityPicker
│   │   ├── ConditionPickerView.swift # Step 2 — block conditions
│   │   ├── ChallengePickerView.swift # Step 3 — unlock challenges
│   │   └── RuleReviewView.swift    # Step 4 — confirmation summary
│   ├── Unlock/
│   │   ├── UnlockView.swift        # Main unlock screen (challenge dispatcher)
│   │   ├── StepChallengeView.swift # Walking progress
│   │   ├── MathsChallengeView.swift
│   │   ├── TypeSentenceView.swift
│   │   ├── WaitChallengeView.swift
│   │   └── WriteReasonView.swift
│   ├── Pause/
│   │   └── PauseRuleView.swift     # Type-to-pause sheet with generated text
│   └── Settings/
│       └── GlobalSettingsView.swift # Wake-up detection + sleep time

├── Services/
│   ├── BlockingService.swift       # Applies/removes ManagedSettings shields
│   ├── HealthKitService.swift      # Queries step count from HealthKit
│   ├── DeviceActivityService.swift # Registers DeviceActivity schedules
│   ├── StepMonitor.swift           # Watches steps in background for unlock
│   └── WakeUpDetector.swift        # Tracks last activity timestamp, detects wake-up

├── Extensions/
│   ├── Date+Helpers.swift          # Convenience date comparisons
│   └── Color+Theme.swift           # App colour tokens

└── Resources/
    └── Info.plist                  # Privacy usage descriptions (required for HealthKit etc.)
```

---

## 4. Core Data Model

### Rule.swift
```swift
struct Rule: Identifiable, Codable {
    var id: UUID = UUID()
    var appToken: ApplicationToken  // From FamilyActivityPicker — opaque Apple type
    var appDisplayName: String      // Stored separately for display
    var appBundleID: String?        // If extractable

    var conditions: [BlockCondition]
    var challenges: [UnlockChallenge]
    var escalationEnabled: Bool
    var escalationWindowMinutes: Int  // default 120 (2 hours)

    var isActive: Bool
    var isPaused: Bool
    var pauseUntil: Date?

    var createdAt: Date
    var lastUnlockedAt: Date?
    var unlockCount: Int              // for escalation tracking
}
```

### BlockCondition.swift
```swift
enum BlockCondition: Codable {
    case timeWindow(start: DateComponents, end: DateComponents, days: DaySet)
    case afterWakeUp(durationMinutes: Int)
    case beforeSleep(sleepTime: DateComponents, durationMinutes: Int)
    case dailyOpenLimit(maxOpens: Int)
}

struct DaySet: OptionSet, Codable {
    let rawValue: Int
    static let monday    = DaySet(rawValue: 1 << 0)
    static let tuesday   = DaySet(rawValue: 1 << 1)
    // ... etc
    static let weekdays: DaySet = [.monday, .tuesday, .wednesday, .thursday, .friday]
    static let everyday: DaySet = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
}
```

### UnlockChallenge.swift
```swift
enum UnlockChallenge: Codable {
    case steps(required: Int)          // default 1000
    case maths(count: Int)             // 3, 5, or 10 problems
    case typeSentence(sentence: String)
    case wait(minutes: Int)
    case writeReason
}
```

### AppSettings.swift
```swift
struct AppSettings: Codable {
    var wakeUpDetectionEnabled: Bool
    var wakeUpIdleHours: Int              // default 2
    var wakeUpWindowStart: DateComponents // default 5:00 AM
    var wakeUpWindowEnd: DateComponents   // default 11:00 AM
    var sleepTime: DateComponents?        // user's target sleep time
}
```

---

## 5. The Blocking Mechanism — How It Actually Works

This is the most important section. Understanding this determines everything.

### How Family Controls / ManagedSettings blocks an app

Apple does not let you "block" apps directly. Instead:
- `FamilyActivityPicker` gives the user a native Apple UI to select apps — returns an `ActivitySelection` object containing opaque `ApplicationToken`s
- You store those tokens
- When you want to block, you call `ManagedSettingsStore.shared.shield.applications = Set<ApplicationToken>`
- iOS then shows a full-screen "blocked" overlay when the user tries to open that app
- To unblock, you set `ManagedSettingsStore.shared.shield.applications = nil` (or remove the token)

### How DeviceActivity handles scheduling
- `DeviceActivityCenter` lets you register named schedules with start/end times
- When a schedule starts, iOS calls your `DeviceActivityMonitor` extension (a separate process)
- You apply the shield inside that extension
- Same for when it ends — you remove the shield

### Critical: The DeviceActivity Extension
This is a separate target in your Xcode project. Not a file inside FrictionGate — a separate extension target. It has its own bundle ID (e.g. `com.debrajpal.frictiongate.FrictionGateMonitor`) and its own entitlements. Cursor needs to know to create this as a separate target.

The extension has one file:
```swift
// FrictionGateMonitor/DeviceActivityMonitorExtension.swift
class FrictionGateMonitor: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        // Apply shields for this activity/rule
    }
    override func intervalDidEnd(for activity: DeviceActivityName) {
        // Remove shields for this activity/rule
    }
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        // Called when daily open limit is hit — apply shield here
    }
}
```

### How the daily open limit works
`DeviceActivityEvent` lets you register a threshold (e.g. 2 app opens). When that threshold is reached, `eventDidReachThreshold` fires in your monitor extension, and you apply the shield. This is exactly how you implement "max X opens per day."

---

## 6. HealthKit Step Counting — How It Works

### Permission request (once, on first launch)
```swift
let stepType = HKQuantityType(.stepCount)
healthStore.requestAuthorization(toShare: [], read: [stepType]) { success, error in ... }
```

### Querying steps since a timestamp
```swift
func stepsSince(_ date: Date) async -> Int {
    let predicate = HKQuery.predicateForSamples(withStart: date, end: Date())
    // Run HKStatisticsQuery for .stepCount, cumulative sum
    // Returns Int
}
```

### For the unlock challenge
- When a block is applied, store `blockAppliedAt = Date()` in the Rule's UnlockAttempt
- When user opens the unlock screen, query steps since `blockAppliedAt`
- Display live progress (refresh every 10 seconds via a Timer)
- When steps >= required threshold, enable the "I've done it — check now" button (or auto-detect)

### For the daily step goal condition
- Query steps since midnight today
- If steps < threshold, block remains active
- Check every time user opens the unlock screen; also via background fetch every 30 min

---

## 7. Wake-Up Detection — How It Works

There is no native "device wake" API available to third-party apps. The approach:

1. Every time the app enters foreground (`scenePhase == .active`), write `lastActiveTimestamp = Date()` to UserDefaults
2. `WakeUpDetector` checks: when foregrounded, has it been > `wakeUpIdleHours` hours since `lastActiveTimestamp`?
3. If yes, and current time is within the wake-up window (e.g. 5am–11am), set `wakeUpDetectedAt = Date()`
4. Any rule with `.afterWakeUp(durationMinutes:)` condition: block is active if `Date() < wakeUpDetectedAt + durationMinutes`
5. BlockingService checks this condition when evaluating whether to apply shields

Note: this requires the user to actually open FrictionGate at least once on a given day for wake-up detection to trigger. An alternative is to use `BGAppRefreshTask` to wake the app briefly in the background, but this is unreliable on iOS. The foreground approach is the pragmatic choice for V1.

---

## 8. Escalating Friction — How It Works

Per-rule state tracked in `UnlockAttempt`:
```swift
struct UnlockAttempt: Codable {
    var ruleID: UUID
    var lastUnlockedAt: Date?
    var unlockCountInWindow: Int   // resets after escalationWindowMinutes
    var currentMultiplier: Int     // 1x, 2x, 3x etc.
}
```

Logic in `UnlockViewModel`:
- When user completes a challenge: record `lastUnlockedAt`, increment `unlockCountInWindow`
- When user opens unlock screen again: check if `Date() - lastUnlockedAt < escalationWindowMinutes * 60`
- If yes: `currentChallenge = baseChallenge × currentMultiplier`
- Display escalation banner on unlock screen

---

## 9. Pause Rule — Type-to-Pause

The pause text is generated dynamically per rule. Formula:
- Line 1: "I am choosing to pause my [AppName] block right now."
- Line 2: "This rule exists because I decided I use [AppName] too much during [condition description]."
- Line 3: "Pausing it is a conscious choice, not a mindless one."
- Line 4: "I take full responsibility for how I use this time."
- Line 5: "I will re-enable this rule when I am done."

Implementation:
- Display the text in a styled label above a `TextField`
- Disable paste: subclass `UITextField` and override `canPerformAction`
- Compare `textField.text == generatedText` character by character
- Enable the Confirm button only when they match exactly

---

## 10. Unlock Screen Flow

When a user taps a blocked app, iOS shows Apple's built-in shield. You can customise this shield slightly:
- In your `DeviceActivityMonitor` extension, use `ShieldConfiguration` to show a custom title, subtitle, and a button labeled "Request Unlock"
- Tapping "Request Unlock" invokes `ShieldActionHandler` (another extension target — see below)
- `ShieldActionHandler` can open your main app via a deep link URL scheme (e.g. `frictiongate://unlock?ruleID=xyz`)
- Your main app receives this URL, finds the rule, and presents `UnlockView`

### ShieldActionHandler Extension
A third extension target: `com.debrajpal.frictiongate.FrictionGateShield`
```swift
class FrictionGateShieldAction: ShieldActionHandler {
    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        // Open main app via URL scheme
        completionHandler(.defer) // keep the block active until challenge is passed
    }
}
```

---

## 11. Extension Targets Summary

Your Xcode project needs **3 targets** total:

| Target | Bundle ID | Purpose |
|---|---|---|
| `FrictionGate` (main app) | `com.debrajpal.frictiongate` | All UI, rule management, HealthKit |
| `FrictionGateMonitor` | `com.debrajpal.frictiongate.FrictionGateMonitor` | DeviceActivityMonitor — applies/removes shields on schedule |
| `FrictionGateShield` | `com.debrajpal.frictiongate.FrictionGateShield` | ShieldActionHandler — handles "Request Unlock" tap on the shield |

All three targets need the `Family Controls` entitlement. They share data via an **App Group**:
- Create an App Group: `group.com.debrajpal.frictiongate`
- Use `UserDefaults(suiteName: "group.com.debrajpal.frictiongate")` everywhere instead of `UserDefaults.standard`
- This is how the extensions and main app share rule data

---

## 12. Data Persistence

Use `UserDefaults` with the App Group suite for simplicity in V1. No CoreData needed.

`RuleStore.swift`:
```swift
class RuleStore: ObservableObject {
    private let defaults = UserDefaults(suiteName: "group.com.debrajpal.frictiongate")!
    private let rulesKey = "stored_rules"

    @Published var rules: [Rule] = []

    func load() { /* decode JSON from defaults */ }
    func save() { /* encode rules to JSON, write to defaults */ }
    func add(_ rule: Rule) { rules.append(rule); save() }
    func delete(_ rule: Rule) { rules.removeAll { $0.id == rule.id }; save() }
    func update(_ rule: Rule) { /* find by id, replace, save */ }
}
```

Note: `ApplicationToken` is not directly `Codable` — Apple provides `FamilyActivitySelection` which you archive with `NSKeyedArchiver`. Store it separately keyed by rule ID.

---

## 13. Info.plist — Required Privacy Strings

Tell Cursor to add these keys to Info.plist:
```xml
<key>NSHealthShareUsageDescription</key>
<string>FrictionGate reads your step count to verify unlock challenges.</string>

<key>NSHealthUpdateUsageDescription</key>
<string>FrictionGate does not write health data.</string>

<key>NSMotionUsageDescription</key>
<string>FrictionGate uses motion data as a fallback step counter.</string>
```

---

## 14. UI Design Direction

Simple, dark-capable, native-feeling iOS design. No custom fonts. SF Rounded for a slightly softer feel. Colour palette:

| Element | Color |
|---|---|
| Primary accent | `Color.blue` (system) |
| Destructive / blocked | `Color.red` |
| Success / unlocked | `Color.green` |
| Warning / escalation | `Color.orange` |
| Background | `Color(.systemGroupedBackground)` |
| Cards | `Color(.secondarySystemGroupedBackground)` |

Use `List` with `.insetGrouped` style throughout. Avoid custom navigation — use `NavigationStack`. All modals as `.sheet`. Looks like a premium Settings app.

---

## 15. Build Order for Cursor

Tell Cursor to build in exactly this sequence to avoid dependency errors:

**Phase 1 — Models & Persistence**
1. `Rule.swift`, `BlockCondition.swift`, `UnlockChallenge.swift`, `UnlockAttempt.swift`, `AppSettings.swift`
2. `RuleStore.swift`

**Phase 2 — Services (no UI yet)**
3. `HealthKitService.swift`
4. `BlockingService.swift`
5. `DeviceActivityService.swift`
6. `WakeUpDetector.swift`
7. `StepMonitor.swift`

**Phase 3 — Extension Targets**
8. `FrictionGateMonitor/DeviceActivityMonitorExtension.swift`
9. `FrictionGateShield/ShieldActionHandler.swift`

**Phase 4 — ViewModels**
10. `HomeViewModel.swift`
11. `RuleBuilderViewModel.swift`
12. `UnlockViewModel.swift`
13. `WakeUpViewModel.swift`

**Phase 5 — Views**
14. `HomeView.swift`, `RuleRowView.swift`
15. `RuleBuilderView.swift` + sub-views (AppPicker, ConditionPicker, ChallengePicker, RuleReview)
16. `UnlockView.swift` + challenge sub-views (Step, Maths, TypeSentence, Wait, WriteReason)
17. `PauseRuleView.swift`
18. `GlobalSettingsView.swift`

**Phase 6 — Entry Point & Wiring**
19. `FrictionGateApp.swift` (request FamilyControls auth on launch)
20. `ContentView.swift` (root NavigationStack)
21. URL scheme handling for deep link from ShieldActionHandler

---

## 16. Xcode Project Setup — What You Do Manually

### Step 1: Create the project
- Open Xcode → Create a new project
- Choose: App (under iOS)
- Product Name: FrictionGate
- Team: your existing Apple Developer account
- Bundle Identifier: com.debrajpal.frictiongate
- Interface: SwiftUI
- Language: Swift
- Uncheck CoreData, uncheck Tests for now

### Step 2: Add Capabilities to main target
Select FrictionGate target → Signing & Capabilities → + Capability:
- Family Controls
- HealthKit (check "Background Delivery" sub-option)
- Background Modes (check "Background fetch" and "Background processing")
- App Groups → add `group.com.debrajpal.frictiongate`
- Push Notifications (needed for local notifications)

### Step 3: Add Extension Targets
File → New → Target → Search "Device Activity Monitor Extension" → Add
- Name: FrictionGateMonitor
- Bundle ID auto-fills as com.debrajpal.frictiongate.FrictionGateMonitor — leave as-is, this is correct and confirmed

File → New → Target → Search "Shield Action Handler Extension" → Add  
- Name: FrictionGateShield
- Bundle ID auto-fills as com.debrajpal.frictiongate.FrictionGateShield — leave as-is, this is correct and confirmed

### Step 4: Add App Group to all 3 targets
Each of the 3 targets needs the same App Group: `group.com.debrajpal.frictiongate`

### Step 5: Add URL Scheme
FrictionGate target → Info tab → URL Types → + → URL Schemes: `frictiongate`
This enables `frictiongate://unlock?ruleID=xyz` deep links.

### Step 6: Set minimum deployment target
All 3 targets → General → Minimum Deployments → iOS 16.0

---

## 17. TestFlight — How to Get It On Your Phone

1. In Xcode: Product → Archive (phone must NOT be connected, or select "Any iOS Device")
2. Xcode Organizer opens automatically
3. Click Distribute App → App Store Connect → Upload
4. Go to appstoreconnect.apple.com
5. Your build appears under TestFlight (takes 5–15 min to process)
6. Under TestFlight → Internal Testing → add yourself as tester
7. Open TestFlight app on your iPhone → install FrictionGate

---

## 18. Cursor Prompt — How to Use This Document

When you hand this to Cursor, structure your prompt like this:

> "I am building an iOS app called FrictionGate in Swift/SwiftUI. Here is the full architecture document. Please build Phase 1 first — all the model files and RuleStore. Do not build any UI yet. Here is the exact folder structure I want. Use the App Group suite name `group.com.debrajpal.frictiongate` everywhere instead of UserDefaults.standard. Here are the exact structs I want..."

Then paste the relevant section. Do one phase at a time. Do not give Cursor the entire document at once — it will try to write everything and make mistakes. Phase by phase is the right approach.

---

## 19. Known Hard Parts — What Will Need Your Attention

| Challenge | Notes |
|---|---|
| `ApplicationToken` is not Codable | Archive with NSKeyedArchiver, store in App Group UserDefaults as Data |
| Extensions can't access main app's memory | All shared state must go through App Group UserDefaults |
| HealthKit background delivery | Needs specific entitlement + configuration, test on real device only |
| ShieldActionHandler deep link | URL scheme must be registered; test on real device only |
| Wake-up detection edge cases | Middle-of-night phone use will reset timer — add time window guard |
| Escalation state persistence | Must survive app kills — store in UserDefaults, not in-memory |
| Simulator limitations | Family Controls, HealthKit, and ShieldActionHandler do NOT work on simulator. You need a real device for all meaningful testing. |

---

*Document version 1.0 — covers V1 feature set as agreed*
*Update this document before each major Cursor session*

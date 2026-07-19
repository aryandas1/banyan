# Claude Code prompt — step 2: app scaffold + onboarding

## Context

Banyan is a private family tree iOS app for older, non-technical users (60s–70s). Step 1 (data models, GraphService, tests) is complete and all tests pass. Do not touch any existing models, services, or tests.

This step builds:
1. The root navigation shell (3-tab structure)
2. The onboarding flow (first launch only)

Auth (Sign in with Apple, SMS OTP) is deferred — we have no Apple Developer account yet. Instead, on first launch we create a local owner Person and store their UUID in `@AppStorage`. The app becomes usable immediately.

---

## Files to create or modify

```
Banyan/
├── ContentView.swift              (replace placeholder)
├── Views/
│   ├── MainTabView.swift          (new)
│   ├── Onboarding/
│   │   ├── WelcomeView.swift      (new)
│   │   └── NameEntryView.swift    (new)
│   ├── Tree/
│   │   └── TreeTabView.swift      (new — placeholder)
│   ├── People/
│   │   └── PeopleListView.swift   (new — placeholder)
│   └── Settings/
│       └── SettingsView.swift     (new — placeholder)
├── ViewModels/
│   └── OnboardingViewModel.swift  (new)
```

---

## ContentView.swift

Checks whether an owner UUID exists in `@AppStorage("ownerPersonId")`. If not, shows `WelcomeView`. If yes, shows `MainTabView`.

```swift
struct ContentView: View {
    @AppStorage("ownerPersonId") private var ownerPersonIdString: String = ""

    var body: some View {
        if ownerPersonIdString.isEmpty {
            WelcomeView()
        } else {
            MainTabView()
        }
    }
}
```

---

## MainTabView.swift

Three tabs. All tab items have both an icon and a label (never icon-only — older users need labels).

```swift
TabView {
    TreeTabView()
        .tabItem { Label("Tree", systemImage: "person.3.fill") }
    PeopleListView()
        .tabItem { Label("People", systemImage: "list.bullet") }
    SettingsView()
        .tabItem { Label("Settings", systemImage: "gearshape.fill") }
}
```

Pass `ownerPersonId` (resolved from `@AppStorage`) down to `TreeTabView` via init.

---

## Onboarding flow

### WelcomeView.swift

Single screen. No navigation chrome. Large, calm, centred layout.

Elements (top to bottom, vertically centred):
- App icon placeholder (a simple leaf or tree SF Symbol, ~80pt, accent colour)
- Heading: "Your family, all in one place" — `.font(.largeTitle)`, `.fontWeight(.bold)`
- Body: "Build your family tree and share it with the people who matter." — `.font(.title3)`, `.foregroundStyle(.secondary)`, centred, max width 320
- Spacer
- Primary button: "Get started" — full width, large, filled, navigates to `NameEntryView`

Button spec:
- `.frame(maxWidth: .infinity)` with `.padding()`
- `.font(.title3).fontWeight(.semibold)`
- `.controlSize(.large)`
- Minimum height 56pt

No secondary links. No animations. No logo image (we have none yet).

Use `NavigationStack` wrapping the onboarding flow so `WelcomeView` can push `NameEntryView`.

### NameEntryView.swift

Heading: "Let's start with you" — `.font(.largeTitle).fontWeight(.bold)`
Subheading: "You'll be the centre of your tree." — `.font(.title3).foregroundStyle(.secondary)`

Two fields, each with a label above in `.font(.headline)`:
- First name (required — Continue button disabled if empty)
- Last name (optional)

Fields spec:
- `.font(.title3)` on the text field text
- `.textContentType(.givenName)` / `.familyName`
- Autofocus first name field on appear (`.focused`)

"Continue" button — same spec as WelcomeView button. Disabled and visually dimmed when first name is empty.

On Continue:
1. Create a `Person` with the entered name, a new `treeId` UUID, and `sex: .unknown`
2. Insert into `modelContext`
3. Save with `try modelContext.save()`
4. Write the person's `id.uuidString` to `@AppStorage("ownerPersonId")`
5. Write the `treeId.uuidString` to `@AppStorage("treeId")`
6. ContentView detects the AppStorage change and transitions to `MainTabView`

Handle save errors: show a `.alert` with "Something went wrong. Please try again." Do not crash.

### OnboardingViewModel.swift

`@MainActor @Observable final class`. Owns the form state for NameEntryView:
- `var firstName: String = ""`
- `var lastName: String = ""`
- `var isSaving: Bool = false`
- `var saveError: Error? = nil`
- `var canContinue: Bool { !firstName.trimmingCharacters(in: .whitespaces).isEmpty }`
- `func save(in context: ModelContext, ownerIdStorage: Binding<String>, treeIdStorage: Binding<String>) async throws`

---

## Placeholder tabs

### TreeTabView.swift
```swift
struct TreeTabView: View {
    let ownerPersonId: UUID
    var body: some View {
        Text("Tree — coming in step 3")
            .font(.title3)
            .foregroundStyle(.secondary)
    }
}
```

### PeopleListView.swift
```swift
struct PeopleListView: View {
    var body: some View {
        Text("People — coming in step 8")
            .font(.title3)
            .foregroundStyle(.secondary)
    }
}
```

### SettingsView.swift
```swift
struct SettingsView: View {
    var body: some View {
        Text("Settings — coming later")
            .font(.title3)
            .foregroundStyle(.secondary)
    }
}
```

---

## Tests to write (TDD — write before implementing)

Create `BanyanTests/OnboardingViewModelTests.swift`:

```swift
import Testing
@testable import Banyan

@MainActor
@Suite("OnboardingViewModel")
struct OnboardingViewModelTests {
    @Test func canContinueIsFalseWhenFirstNameIsEmpty() { ... }
    @Test func canContinueIsTrueWithFirstName() { ... }
    @Test func canContinueIsFalseForWhitespaceOnly() { ... }
}
```

---

## Constraints

- All existing files untouched — only add new files and replace ContentView.swift
- No auth, no phone number, no OTP in this step
- No hard-coded colours — use `.primary`, `.secondary`, `Color.accentColor`
- No hard-coded font sizes — all `.font(.largeTitle)`, `.font(.title3)` etc.
- Minimum tap target 56pt height on all buttons
- `NameEntryView` gets the `modelContext` via `@Environment(\.modelContext)`
- `OnboardingViewModel` is owned by `NameEntryView` as `@State var vm = OnboardingViewModel()`
- No `AnyView`, no `NavigationView`, no `@StateObject`
- Use `#Preview` blocks, one per meaningful state (welcome state, name-entered state)
- After implementation: confirm build zero errors, zero warnings, all tests pass

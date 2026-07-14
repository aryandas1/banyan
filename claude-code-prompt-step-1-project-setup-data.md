# Claude Code prompt — step 1: project setup + data models

Paste this into Claude Code after creating a new Xcode project named **Banyan** with:
- iOS 17.0 minimum deployment
- SwiftUI interface
- SwiftData storage

---

## Prompt

I'm building an iOS family tree app called Banyan. I've just created a new Xcode project with SwiftUI and SwiftData. Set up the foundational layer: data models, graph service, and app scaffold. Do not build any UI beyond a basic placeholder yet.

### File structure to create

```
Banyan/
├── BanyanApp.swift           (modify existing)
├── ContentView.swift         (modify existing — placeholder only)
├── Models/
│   ├── PartialDate.swift
│   ├── Person.swift
│   ├── Union.swift
│   ├── PersonUnionLink.swift
│   └── BanyanSchemaV1.swift
├── ViewModels/
│   └── TreeViewModel.swift
├── Services/
│   ├── GraphServiceProtocol.swift
│   └── GraphService.swift
└── Utilities/
    └── Extensions.swift

BanyanTests/
├── Helpers/
│   └── TestTreeBuilder.swift
├── GraphServiceTests.swift
├── TreeViewModelTests.swift
└── PartialDateTests.swift
```

### Models

**PartialDate.swift** — a Codable, Hashable struct (not a SwiftData model):
- `year: Int?`
- `month: Int?`
- `day: Int?`
- `isEstimated: Bool` (default false)
- `var displayString: String` — returns e.g. "1945", "Mar 1945", or "Unknown" if all nil

**Person.swift** — SwiftData `@Model`:
- `id: UUID` (default UUID())
- `treeId: UUID`
- `firstName: String`
- `lastName: String`
- `sex: Sex` (enum: male, female, unknown — String RawRepresentable, Codable)
- `birthDate: PartialDate?`
- `deathDate: PartialDate?`
- `birthPlace: String?`
- `deathPlace: String?`
- `isPlaceholder: Bool` (default false)
- `profilePhotoFilename: String?` (local filename, not UUID — we'll save photos to the app's documents directory)
- `bio: String?`
- `createdAt: Date` (default Date())
- `@Relationship(deleteRule: .cascade, inverse: \PersonUnionLink.person) var links: [PersonUnionLink]` (default [])
- Computed: `var fullName: String`, `var initials: String`, `var isDeceased: Bool`

**Union.swift** — SwiftData `@Model`:
- `id: UUID` (default UUID())
- `treeId: UUID`
- `type: UnionType` (enum: married, partnered, unknown — String RawRepresentable, Codable)
- `startDate: PartialDate?`
- `endDate: PartialDate?`
- `endReason: EndReason?` (enum: divorce, death, unknown — String RawRepresentable, Codable, optional)
- `@Relationship(deleteRule: .cascade, inverse: \PersonUnionLink.union) var links: [PersonUnionLink]` (default [])

**PersonUnionLink.swift** — SwiftData `@Model`:
- `id: UUID` (default UUID())
- `role: LinkRole` (enum: partner, child — String RawRepresentable, Codable)
- `childType: ChildType?` (enum: biological, adopted, foster, step, unknown — String RawRepresentable, Codable, optional — nil when role is partner)
- `var person: Person?`
- `var union: Union?`

### GraphServiceProtocol.swift (new file, add to Services/)

Define a protocol before the implementation:

```swift
/// Provides read-only graph queries over the person-union family graph.
/// All methods are pure — they take entities and return derived data.
/// No SwiftUI or SwiftData imports. No side effects.
protocol GraphServiceProtocol {
    /// All unions this person participates in (as partner or child).
    func unions(for person: Person) -> [Union]

    /// The other partner(s) in a given union.
    func partners(of person: Person, in union: Union) -> [Person]

    /// All partners across all of this person's unions.
    func allPartners(of person: Person) -> [Person]

    /// The parents of a person — the partner(s) of the union where this person is a child.
    func parents(of person: Person) -> [Person]

    /// All children across all unions where this person is a partner.
    func children(of person: Person) -> [Person]

    /// People who share at least one parent union with this person.
    func siblings(of person: Person) -> [Person]

    /// All people in a tree, sorted alphabetically by fullName.
    func allPeople(treeId: UUID, from people: [Person]) -> [Person]
}
```

### GraphService.swift

A `final class` conforming to `GraphServiceProtocol`. No `@Observable`. No SwiftUI import. Takes entities directly — callers pass in fetched objects.

Add `///` doc comments on every method matching the protocol. Use `private` for any helper methods.

### TreeViewModel.swift

An `@MainActor @Observable final class`. Depends on `GraphServiceProtocol` (injected via init), not the concrete type.

```swift
@MainActor
@Observable
final class TreeViewModel {
    private let graphService: GraphServiceProtocol

    private(set) var focusedPersonId: UUID?
    private(set) var navigationStack: [UUID] = []

    init(graphService: GraphServiceProtocol) {
        self.graphService = graphService
    }

    func focus(on personId: UUID) { ... }
    func goBack() { ... }
    func resetToRoot(ownerId: UUID) { ... }
}
```

### Testing (TDD — write tests before implementation)

Create a `BanyanTests` unit test target. Follow this order strictly:

**Step A — TestTreeBuilder**

Create `BanyanTests/Helpers/TestTreeBuilder.swift`. This is a struct — each test creates its own instance so there is no shared state between tests:

```swift
struct TestTreeBuilder {
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: BanyanSchemaV1.models, configurations: config)
        context = ModelContext(container)
        context.autosaveEnabled = false  // required — prevents background writes interfering with tests
    }

    @discardableResult
    func makePerson(firstName: String, lastName: String = "", treeId: UUID = UUID()) -> Person { ... }

    @discardableResult
    func makeUnion(type: UnionType = .married, treeId: UUID = UUID()) -> Union { ... }

    @discardableResult
    func link(person: Person, to union: Union, role: LinkRole, childType: ChildType? = nil) -> PersonUnionLink { ... }
}
```

Each test function creates its own `try TestTreeBuilder()` inline — never in a suite `init()`.

**Step B — Write GraphService tests first (they will fail)**

Use `import Testing` (Swift Testing), not XCTest. Use `#expect` for assertions, `try #require` to unwrap optionals.

Create `BanyanTests/GraphServiceTests.swift`:

```swift
import Testing
@testable import Banyan

@Suite("GraphService")
struct GraphServiceTests {
    // Each test creates its own in-memory container via TestTreeBuilder
    // Tests are independent — no shared state

    @Test func parentsReturnsBothParents() async throws { ... }
    @Test func parentsReturnsEmptyWhenNone() async throws { ... }
    @Test func childrenAcrossTwoUnions() async throws { ... }
    @Test func childrenEmptyWhenNone() async throws { ... }
    @Test func allPartnersWithRemarriage() async throws { ... }
    @Test func siblingsFromSameUnion() async throws { ... }
    @Test func halfSiblingsFromDifferentUnions() async throws { ... }
    @Test func onlyChildHasNoSiblings() async throws { ... }
    @Test func allPeopleFiltersTreeId() async throws { ... }
    @Test func allPeopleSortsAlphabetically() async throws { ... }
}
```

**Step C — Implement GraphService until all tests pass**

**Step D — Write TreeViewModel tests (they will fail)**

Mark the entire suite `@MainActor` — TreeViewModel is `@MainActor`-isolated and its properties can only be read on the main actor.

```swift
import Testing
@testable import Banyan

@MainActor
@Suite("TreeViewModel")
struct TreeViewModelTests {
    @Test func focusSetsId() { ... }
    @Test func focusPushesPreviousOntoStack() { ... }
    @Test func goBackRestoresPreviousFocus() { ... }
    @Test func goBackDoesNothingOnEmptyStack() { ... } // must not crash
    @Test func resetToRootClearsStack() { ... }
    @Test func resetToRootSetsFocusToOwner() { ... }
}
```

**Step E — Implement TreeViewModel until all tests pass**

**Step F — Write PartialDate tests**

```swift
import Testing
@testable import Banyan

@Suite("PartialDate")
struct PartialDateTests {
    @Test func yearOnly() { #expect(PartialDate(year: 1945).displayString == "1945") }
    @Test func yearAndMonth() { #expect(PartialDate(year: 1945, month: 3).displayString == "Mar 1945") }
    @Test func allNilIsUnknown() { #expect(PartialDate().displayString == "Unknown") }
    @Test func estimatedPrefixesTilde() { #expect(PartialDate(year: 1945, isEstimated: true).displayString == "~1945") }
}
```

**Step G — Implement PartialDate.displayString until tests pass**

### BanyanSchemaV1.swift

Define the versioned schema wrapping all three models. This costs nothing now and makes future migrations possible:

```swift
// BanyanSchemaV1.swift
// Versioned schema wrapper — required for SwiftData migrations.

import SwiftData

enum BanyanSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Person.self, Union.self, PersonUnionLink.self]
    }
}
```

### BanyanApp.swift

Use the versioned schema in the ModelContainer:

```swift
@main
struct BanyanApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: BanyanSchemaV1.models)
    }
}
```

### ContentView.swift

Placeholder only — just a `Text("Banyan")` centred on screen. We'll replace this in the next step.

### Extensions.swift

Add a `UUID` extension:
```swift
extension UUID {
    static var placeholder: UUID { UUID(uuidString: "00000000-0000-0000-0000-000000000000")! }
}
```

### Constraints

**Code quality:**
- **No force unwraps in production code** — use `guard`, `if let`, or `??`. Force unwraps are acceptable only in test code.
- **All enums:** String raw value, Codable, CaseIterable
- **No SwiftUI or SwiftData imports in GraphService or Models** — pure Swift only
- **PartialDate** must be Codable for SwiftData persistence
- **`@MainActor`** on TreeViewModel — mark the entire class, not individual methods
- **Access control:** default to `private`; `private(set)` for read-only exposed state; no `public` needed
- **Dependencies via init** — no singletons, no global state
- **`throws`** on any function that writes to ModelContext
- **`///` doc comments** on all protocol methods and ViewModel methods
- **Brief file-level comment** at the top of each file

**SwiftData relationship rules (do not deviate):**
- Only `Person.links` and `Union.links` declare `inverse:` — `PersonUnionLink.person` and `.union` are plain optional properties with no `@Relationship` macro
- `PersonUnionLink.person` and `.union` must remain optional — non-optional back-references crash on cascade delete
- Enum default values go in `init()`, not at the property declaration site
- All models are `final class`
- Wrap all three models in `BanyanSchemaV1: VersionedSchema`

**Testing:**
- Use Swift Testing (`import Testing`) not XCTest
- Build the ModelContainer inline inside each test function — not in suite `init()`
- Set `context.autosaveEnabled = false` in every test context
- `TreeViewModelTests` suite must be marked `@MainActor`
- TDD order must be followed: tests written and confirmed failing before implementation

**Deprecated SwiftUI APIs — never use these:**
| Do NOT write | Write this instead |
|---|---|
| `.foregroundColor()` | `.foregroundStyle()` |
| `.cornerRadius()` | `.clipShape(.rect(cornerRadius:))` |
| `NavigationView` | `NavigationStack` |
| `onChange { value in }` (1-param) | `onChange(of:) { old, new in }` |
| `Task {}` inside `onAppear` | `.task {}` modifier |
| `onTapGesture` on a control | `Button` with an accessible label |
| `AnyView` | `@ViewBuilder` or `Group` |
| `@StateObject` / `@ObservedObject` | `@State` / plain `let` with `@Observable` |

After all steps are complete, confirm: project builds with zero errors, zero warnings, and all tests pass.

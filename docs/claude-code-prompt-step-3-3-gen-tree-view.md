# Claude Code prompt — step 3: 3-gen focused tree view

## Context

Banyan is a private family tree iOS app for older, non-technical users (60s–70s). Steps 1 and 2 are complete. This step builds the core tree view — the primary screen users spend 90% of their time on.

Do not touch any existing models, services, or passing tests.

---

## What this step builds

The **3-generation focused view**: always shows exactly 3 rows centred on one person:
- Row 1 (top): focal person's parents
- Row 2 (middle): focal person + their partner(s) + their siblings
- Row 3 (bottom): focal person's children

Navigation works by tapping any node. The view re-renders around the new focal person. No gestures required — every action is a tap.

Empty slots show faint placeholder nodes (tappable, but wired to print for now — the add-person flow is step 5).

---

## Files to create or modify

```
Banyan/
├── ViewModels/
│   └── ThreeGenViewModel.swift        (new)
├── Views/
│   └── Tree/
│       ├── TreeTabView.swift          (replace placeholder)
│       ├── ThreeGenView.swift         (new)
│       ├── PersonNodeView.swift       (new)
│       ├── PlaceholderNodeView.swift  (new)
│       └── TreeConnectorsView.swift   (new)

BanyanTests/
└── ThreeGenViewModelTests.swift       (new)
```

---

## ThreeGenViewModel.swift

`@MainActor @Observable final class`. Owns the data snapshot for the current focal person. Injected with `GraphServiceProtocol`.

```swift
@MainActor
@Observable
final class ThreeGenViewModel {
    private let graphService: GraphServiceProtocol

    /// The person currently centred in the tree.
    private(set) var focalPerson: Person

    /// The focal person's parents (partners in the union where focal is a child).
    private(set) var parents: [Person] = []

    /// The focal person's own partner(s).
    private(set) var focalPartners: [Person] = []

    /// The focal person's children across all their unions.
    private(set) var children: [Person] = []

    /// Siblings: people who share at least one parent union with focal.
    /// Capped at 3 for display; excess shown as "+N more" label.
    private(set) var siblings: [Person] = []

    init(focalPerson: Person, graphService: GraphServiceProtocol) {
        self.graphService = graphService
        self.focalPerson = focalPerson
        refresh()
    }

    /// Call whenever the focal person changes.
    func update(focalPerson: Person) {
        self.focalPerson = focalPerson
        refresh()
    }

    private func refresh() {
        parents = graphService.parents(of: focalPerson)
        focalPartners = graphService.allPartners(of: focalPerson)
        children = graphService.children(of: focalPerson)
        siblings = graphService.siblings(of: focalPerson)
    }
}
```

---

## PersonNodeView.swift

A tappable card for a real person in the tree.

```swift
struct PersonNodeView: View {
    let person: Person
    let isFocal: Bool       // true only for the centred person
    let onTap: () -> Void
}
```

Appearance:
- Size: `width: 80, height: 88` — fixed, so connectors can be placed reliably
- Shape: `RoundedRectangle(cornerRadius: 12)` via `.clipShape`
- Background: `.fill(isFocal ? Color.primary : Color(.systemBackground))`
- Border: `.stroke(isFocal ? Color.clear : Color(.systemGray4), lineWidth: 1.5)` — use `.overlay(RoundedRectangle(cornerRadius:12).stroke(...))`
- Shadow: `.shadow(color: .black.opacity(0.06), radius: 4, y: 2)` on non-focal nodes

Content (VStack, centred):
- Initials circle: `Circle()` 36pt diameter, background `.fill(isFocal ? Color(.systemBackground).opacity(0.2) : Color(.systemGray6))`, text `.font(.callout).fontWeight(.semibold)`
- Name: `person.firstName` only (space is too tight for full name), `.font(.caption).fontWeight(.medium)`, one line, truncated
- Birth year (if known): `person.birthDate?.year.map { String($0) } ?? ""`, `.font(.caption2).foregroundStyle(.secondary)`

Accessibility: `.accessibilityLabel(person.fullName)`, `.accessibilityAddTraits(.isButton)`

The entire card is a `Button` with `.buttonStyle(.plain)` — never a bare `onTapGesture`.

---

## PlaceholderNodeView.swift

A faint tappable slot for a missing person.

```swift
struct PlaceholderNodeView: View {
    let label: String   // "Add parent", "Add partner", "Add child"
    let onTap: () -> Void
}
```

Same 80×88 fixed size. `RoundedRectangle` with dashed border:
```swift
RoundedRectangle(cornerRadius: 12)
    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5]))
    .foregroundStyle(Color(.systemGray4))
```
Background: `Color(.systemGray6).opacity(0.5)`

Content: `Image(systemName: "plus")` + `Text(label)` stacked, both `.foregroundStyle(Color(.systemGray2))`, font `.caption`.

Tap: `print("Placeholder tapped: \(label)")` — wired to real action in step 5.

---

## TreeConnectorsView.swift

Draws the lines connecting the 3 rows. Uses a `Canvas` overlay.

Lines to draw:
1. **Partner line (parent row):** if 2 parents exist, a horizontal line between the right edge of parent[0] and the left edge of parent[1]
2. **Drop line (parent to focal):** a vertical line from the midpoint of the parent partner line down to the top centre of the focal node
3. **Partner line (middle row):** if focal has a partner, a horizontal line from the right edge of focal to the left edge of partner node
4. **Drop line (focal to children):** if children exist, a vertical line from the bottom centre of the focal node down to a horizontal bar, then short vertical drops to each child

Use `anchorPreference` with a custom `NodeAnchorKey: PreferenceKey` to collect the `.center` anchor of each node (keyed by person ID). Then use `overlayPreferenceValue(NodeAnchorKey.self)` on the row container to draw a `Canvas` with the collected positions.

Line style: `Color(.systemGray3)`, lineWidth 1.5, rounded caps.

If not enough anchor data is available (e.g. only one parent), skip drawing that specific line rather than crashing.

---

## ThreeGenView.swift

The main tree canvas. Takes the `ThreeGenViewModel` and `TreeViewModel` as inputs. Uses `ScrollView(.horizontal, showsIndicators: false)` for each row so they scroll independently if there are many nodes.

### Layout

```swift
VStack(spacing: 0) {
    // Breadcrumb strip
    BreadcrumbView(stack: treeViewModel.navigationStack, allPeople: allPeople)

    ScrollView {
        VStack(spacing: 32) {
            // Row 1: parents
            parentRowView

            // Row 2: focal + siblings + partners
            middleRowView

            // Row 3: children
            childRowView
        }
        .padding()
        .overlayPreferenceValue(NodeAnchorKey.self) { anchors in
            // Draw connectors using Canvas
            TreeConnectorsView(anchors: anchors, ...)
        }
    }
}
.navigationBarTitleDisplayMode(.inline)
.toolbar {
    ToolbarItem(placement: .navigationBarLeading) {
        backButton
    }
    ToolbarItem(placement: .navigationBarTrailing) {
        backToMeButton
    }
}
```

### Parent row

If `parents` is empty: show one `PlaceholderNodeView(label: "Add parent")`.
If 1 parent: show one `PersonNodeView` centred.
If 2 parents: show both side by side with a gap for the connector line.

Each parent node: tapping calls `treeViewModel.focus(on: parent.id)`.

### Middle row

HStack: `[sibling nodes] [focal node] [partner node or placeholder]`

Siblings: show up to 3. If more, show the first 2 + a `Text("+\(siblings.count - 2) more").font(.caption).foregroundStyle(.secondary)` label in a small rounded pill. Tapping a sibling calls `treeViewModel.focus(on: sibling.id)`.

Focal node: `PersonNodeView(person: focalPerson, isFocal: true, onTap: {})` — tapping the focal node does nothing.

Partner slot: if `focalPartners` is empty, show `PlaceholderNodeView(label: "Add partner")`. If one partner, show `PersonNodeView`. If multiple, show a small stack indicator (for now: show first partner + a `Text("+N")` badge).

### Child row

If `children` is empty: show `PlaceholderNodeView(label: "Add child")`.
Otherwise: `ScrollView(.horizontal)` containing an HStack of `PersonNodeView` for each child. Each child tap calls `treeViewModel.focus(on: child.id)`.

### Back button

```swift
var backButton: some View {
    Button {
        treeViewModel.goBack()
    } label: {
        HStack(spacing: 4) {
            Image(systemName: "chevron.left")
            Text("Back")
        }
        .font(.body)
    }
    .disabled(treeViewModel.navigationStack.isEmpty)
}
```

### Back to me button

```swift
var backToMeButton: some View {
    Button("My tree") {
        treeViewModel.resetToRoot(ownerId: ownerPersonId)
    }
    .font(.body)
    .disabled(treeViewModel.focusedPersonId == ownerPersonId)
}
```

---

## BreadcrumbView.swift (new, small)

A horizontal scrolling strip showing the navigation path.

```swift
struct BreadcrumbView: View {
    let stack: [UUID]
    let allPeople: [Person]
}
```

Shows names from the navigation stack as `Text` separated by `Image(systemName: "chevron.right")`. Tapping a name in the breadcrumb jumps back to that person (calls `treeViewModel.focus(on:)` — or better: truncates the stack to that point). Scrollable horizontally. Hidden if stack is empty.

---

## TreeTabView.swift (replace placeholder)

```swift
struct TreeTabView: View {
    @AppStorage("ownerPersonId") private var ownerPersonIdString: String = ""
    @AppStorage("treeId") private var treeIdString: String = ""
    @Query private var allPeople: [Person]

    @State private var treeViewModel = TreeViewModel(graphService: GraphService())
    @State private var threeGenViewModel: ThreeGenViewModel?

    var ownerPersonId: UUID? { UUID(uuidString: ownerPersonIdString) }

    var treePeople: [Person] {
        guard let treeId = UUID(uuidString: treeIdString) else { return [] }
        return allPeople.filter { $0.treeId == treeId }
    }

    var body: some View {
        Group {
            if let focalId = treeViewModel.focusedPersonId ?? ownerPersonId,
               let focalPerson = treePeople.first(where: { $0.id == focalId }),
               let vm = threeGenViewModel {
                ThreeGenView(
                    threeGenVM: vm,
                    treeVM: treeViewModel,
                    allPeople: treePeople,
                    ownerPersonId: focalId
                )
            } else {
                // Tree is empty or owner not yet resolved
                ContentUnavailableView("No tree yet", systemImage: "tree")
            }
        }
        .onChange(of: treeViewModel.focusedPersonId) { _, newId in
            guard let id = newId ?? ownerPersonId,
                  let person = treePeople.first(where: { $0.id == id }) else { return }
            threeGenViewModel = ThreeGenViewModel(focalPerson: person, graphService: GraphService())
        }
        .onChange(of: ownerPersonIdString) { _, _ in
            if treeViewModel.focusedPersonId == nil, let id = ownerPersonId,
               let person = treePeople.first(where: { $0.id == id }) {
                treeViewModel.resetToRoot(ownerId: id)
                threeGenViewModel = ThreeGenViewModel(focalPerson: person, graphService: GraphService())
            }
        }
        .onAppear {
            if threeGenViewModel == nil, let id = ownerPersonId,
               let person = treePeople.first(where: { $0.id == id }) {
                treeViewModel.resetToRoot(ownerId: id)
                threeGenViewModel = ThreeGenViewModel(focalPerson: person, graphService: GraphService())
            }
        }
    }
}
```

---

## Tests (TDD — write before implementing)

Create `BanyanTests/ThreeGenViewModelTests.swift`:

```swift
import Testing
@testable import Banyan

@MainActor
@Suite("ThreeGenViewModel")
struct ThreeGenViewModelTests {

    @Test func parentsPopulatedOnInit() throws {
        // Build: person with two parents via TestTreeBuilder
        // Assert: vm.parents.count == 2
    }

    @Test func siblingsPopulatedOnInit() throws {
        // Build: focal + one sibling sharing the same parent union
        // Assert: vm.siblings.count == 1
    }

    @Test func partnersPopulatedOnInit() throws {
        // Build: focal + one partner in a union
        // Assert: vm.focalPartners.count == 1
    }

    @Test func childrenPopulatedOnInit() throws {
        // Build: focal + one child
        // Assert: vm.children.count == 1
    }

    @Test func updateRefreshesData() throws {
        // Build: focal A and focal B, each with one child
        // Init vm with A, assert children contains A's child
        // Call vm.update(focalPerson: B)
        // Assert: children now contains B's child
    }

    @Test func emptyTreeReturnsEmptyCollections() throws {
        // Build: focal with no relationships
        // Assert: parents, siblings, focalPartners, children all empty
    }
}
```

---

## Constraints

- All existing files untouched — only add new files and replace TreeTabView
- `PersonNodeView` and `PlaceholderNodeView` fixed at 80×88pt — do not use `.frame(maxWidth:)` that would cause sizing inconsistency with connectors
- Every node interaction goes through a `Button` — no bare `onTapGesture`
- No `AnyView`, no `NavigationView`, no hard-coded colours
- `ThreeGenViewModel` is created fresh when focal person changes — do not mutate the arrays directly
- Use `GraphService()` as the concrete service in `TreeTabView` (dependency injection is for testability; the tab view is the composition root)
- `TreeConnectorsView` must not crash when anchor data is missing — guard every lookup
- Siblings capped at display of 3 — never show more than 3 sibling nodes regardless of actual count
- After implementation: confirm build zero errors, zero warnings, all tests pass

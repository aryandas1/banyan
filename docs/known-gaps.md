# Banyan — known gaps & design decisions pending

Behaviours that are **intentional consequences of the current design**, not bugs. The
underlying data is always stored correctly — these are about what the focused tree view
chooses to *render*, and about UX affordances not yet built. Captured here so they aren't
rediscovered as "bugs" and so a future layout/polish step can pick them up deliberately.

Last updated: opening step 7 (people list). 69 tests green after step 6 + its review.

---

## 1. A parent's partner (step-parent / parent's new spouse) doesn't appear when centred on the child

**Observed:** Centre the tree on yourself, tap a parent, "Add [parent]'s partner". The new
partner saves but never shows on the tree.

**Why:** The 3-generation view centred on person X shows `parents(of: X)` in the top row,
defined narrowly as *"the partners of the union X is a child of."* `addPartner` always
creates a **new** union for the parent + their new partner, which is a *different* union from
the one that makes them your parent. So the new partner is (correctly) not one of your
parents, and the view centred on you has no slot for a parent's spouse — they're one
generation "sideways," outside the 3-gen frame.

**Workaround today:** Tap the parent → "See their family" to re-centre on them; the partner
then shows in the parent's middle row (subject to gap #2 below).

**Options for a future step:**
- Render the parent generation as a **couple** (both partners of the parent union), and/or
  surface step-parents in the parent row.
- Decide how step-relationships should read for non-technical older users
  ("Dad's wife" vs. "step-mother").

---

## 2. The partner slot renders only the first partner, with a non-interactive "+N" badge

**Where:** `ThreeGenView.partnerSlot`.

**Behaviour:** When the focal person has more than one partner, only `focalPartners.first`
is drawn, with a small "+N" badge for the rest. The badge is not tappable, so additional
partners aren't reachable from the focused view.

**Option for a future step:** make the badge open a picker / expand to show all partners, so
multi-partner people (remarriages, etc.) are fully navigable.

---

## 3. Half-siblings are excluded from the Siblings list

**Where:** `GraphService.siblings(of:)` (documented in-code).

**Behaviour:** Siblings are people who share a parent *union*. People who share only *one*
parent (a different second parent) are not counted. This is a deliberate MVP simplification.

**Option for a future step:** widen the definition to half-siblings if users expect them.

---

## 4. The People tab can't navigate the tree — tapping "See their family" / "Add …" only dismisses

**Where:** `PeopleListView` (step 7).

**Behaviour:** Opening a person from the People tab presents the same `PersonSheetView` used by
the Tree tab, but its `onSeeFamily` and `onAddPerson` callbacks just dismiss the sheet — they
don't re-centre the tree, because tree navigation lives in a different tab (`TreeTabView` owns
the focal state). So from the People tab those buttons are effectively no-ops beyond closing.

**Why:** MVP scoping. Cross-tab navigation (tap a person in People → jump to them focused in the
Tree tab) needs shared focal state across tabs, which isn't built. The user can switch to the
Tree tab and navigate there.

**Option for a future step:** hoist the focal-person state above the `TabView` (or route through a
shared coordinator) so People-tab taps can drive the Tree tab.

---

## Heads-up for step 6 (relationship linking)

Step 6's `unlink` and its `unlinkCleansUpOrphanedUnion` test repeat the SwiftData in-memory
cascade-staleness trap that bit step 5's `deletePerson`: after `context.delete(link)`, a
union's in-memory `links` array (and a person's `links`) is **not** eagerly pruned until save/
refetch. So "delete the link, then check whether the union still has partner links" will see
the just-removed link and fail to prune. Compute the prune decision *before* deleting, and
assert pruning in tests via a persisted `FetchDescriptor` fetch, not the in-memory arrays.
See `TreeMutationService.deletePerson` for the pattern.

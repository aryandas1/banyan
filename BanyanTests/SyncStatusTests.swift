// SyncStatusTests.swift
// The pure derivation behind the owner-only sync indicator: precedence between the
// three SyncService observables, the friendly copy, and the relative-time buckets.
// No UI — this is the logic the thin SyncStatusView switches over.

import Foundation
import Testing
@testable import Banyan

@Suite("SyncStatus")
struct SyncStatusTests {

    private struct SomeError: Error {}

    // MARK: - Precedence

    @Test func syncingWinsOverEverything() {
        let status = SyncStatus.from(isSyncing: true, lastSyncError: SomeError(), lastSyncDate: .now)
        #expect(status == .syncing)
    }

    @Test func errorWinsOverLastSyncDate() {
        let status = SyncStatus.from(isSyncing: false, lastSyncError: SomeError(), lastSyncDate: .now)
        #expect(status == .failed)
    }

    @Test func syncedWhenOnlyADateIsPresent() {
        let date = Date(timeIntervalSince1970: 1_000)
        let status = SyncStatus.from(isSyncing: false, lastSyncError: nil, lastSyncDate: date)
        #expect(status == .synced(date))
    }

    @Test func idleWhenNothingHasHappenedYet() {
        let status = SyncStatus.from(isSyncing: false, lastSyncError: nil, lastSyncDate: nil)
        #expect(status == .idle)
    }

    // MARK: - Display text

    @Test func syncingShowsSavingCopy() {
        #expect(SyncStatus.syncing.displayText() == "Saving…")
    }

    @Test func failedShowsCalmRetryCopy() {
        // Never a raw error / code — friendly and reassuring.
        #expect(SyncStatus.failed.displayText() == "Couldn't save — will retry")
    }

    @Test func idleShowsNothing() {
        #expect(SyncStatus.idle.displayText() == nil)
    }

    // MARK: - Relative time buckets

    @Test func justSyncedReadsJustNow() {
        let now = Date(timeIntervalSince1970: 10_000)
        let status = SyncStatus.synced(now.addingTimeInterval(-5))
        #expect(status.displayText(now: now) == "Saved · just now")
    }

    @Test func minutesAgoBucket() {
        let now = Date(timeIntervalSince1970: 10_000)
        let status = SyncStatus.synced(now.addingTimeInterval(-5 * 60))
        #expect(status.displayText(now: now) == "Saved · 5m ago")
    }

    @Test func hoursAgoBucket() {
        let now = Date(timeIntervalSince1970: 100_000)
        let status = SyncStatus.synced(now.addingTimeInterval(-2 * 3_600))
        #expect(status.displayText(now: now) == "Saved · 2h ago")
    }

    @Test func daysAgoBucket() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let status = SyncStatus.synced(now.addingTimeInterval(-3 * 86_400))
        #expect(status.displayText(now: now) == "Saved · 3d ago")
    }

    @Test func futureDateClampsToJustNow() {
        // Clock skew shouldn't produce "-1m ago".
        let now = Date(timeIntervalSince1970: 10_000)
        let status = SyncStatus.synced(now.addingTimeInterval(120))
        #expect(status.displayText(now: now) == "Saved · just now")
    }

    @Test func boundaryAtSixtySecondsRollsToOneMinute() {
        let now = Date(timeIntervalSince1970: 10_000)
        #expect(SyncStatus.synced(now.addingTimeInterval(-59)).displayText(now: now) == "Saved · just now")
        #expect(SyncStatus.synced(now.addingTimeInterval(-60)).displayText(now: now) == "Saved · 1m ago")
    }

    // MARK: - Tone / icon (the view's mapping inputs)

    @Test func tonesMatchTheirState() {
        #expect(SyncStatus.syncing.tone == .working)
        #expect(SyncStatus.failed.tone == .warning)
        #expect(SyncStatus.synced(.now).tone == .positive)
        #expect(SyncStatus.idle.tone == .neutral)
    }

    @Test func idleHasNoIconEverythingElseDoes() {
        #expect(SyncStatus.idle.systemImage == nil)
        #expect(SyncStatus.syncing.systemImage != nil)
        #expect(SyncStatus.failed.systemImage != nil)
        #expect(SyncStatus.synced(.now).systemImage != nil)
    }
}

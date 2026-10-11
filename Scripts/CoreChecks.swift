// Run the same core test cases without XCTest when only Command Line Tools exist.
// The iOS/SwiftData/HealthKit checks still require Xcode and a device.
import Foundation

class XCTestCase {}
func XCTAssertEqual<T: Equatable>(_ lhs: T, _ rhs: T, file: StaticString = #file, line: UInt = #line) {
    precondition(lhs == rhs, "Expected equal values: \(lhs) and \(rhs)", file: file, line: line)
}
func XCTAssertEqual(_ lhs: Double, _ rhs: Double, accuracy: Double, file: StaticString = #file, line: UInt = #line) {
    precondition(abs(lhs - rhs) <= accuracy, "Expected \(lhs) ≈ \(rhs)", file: file, line: line)
}
func XCTAssertNotEqual<T: Equatable>(_ lhs: T, _ rhs: T, file: StaticString = #file, line: UInt = #line) {
    precondition(lhs != rhs, "Expected different values", file: file, line: line)
}
func XCTAssertTrue(_ value: Bool, file: StaticString = #file, line: UInt = #line) { precondition(value, file: file, line: line) }
func XCTAssertFalse(_ value: Bool, file: StaticString = #file, line: UInt = #line) { precondition(!value, file: file, line: line) }
func XCTAssertNil<T>(_ value: T?, file: StaticString = #file, line: UInt = #line) { precondition(value == nil, file: file, line: line) }
func XCTAssertNoThrow<T>(_ expression: @autoclosure () throws -> T, file: StaticString = #file, line: UInt = #line) {
    do { _ = try expression() } catch { preconditionFailure("Unexpected error: \(error)", file: file, line: line) }
}
func XCTAssertThrowsError<T>(_ expression: @autoclosure () throws -> T, file: StaticString = #file, line: UInt = #line) {
    do { _ = try expression() } catch { return }
    preconditionFailure("Expected an error", file: file, line: line)
}

@main struct CoreChecks {
    static func main() throws {
        let tests = WorkoutLogicTests()
        let cases: [(String, () throws -> Void)] = [
            ("Seed plan and shared exercise identity", tests.testSeedPlanAndSharedHistoryIdentity),
            ("Backup round trip, health and draft", tests.testRoundTripIncludesPlanSettingsHealthAndDraft),
            ("Quick-fill across workout days", tests.testQuickFillUsesLastCompletedSessionAcrossDays),
            ("Units, Epley and volume", tests.testUnitConversionAndEpleyVolume),
            ("Bodyweight and personal records", tests.testBodyweightUsesRepsAndPRRequiresPreviousBaseline),
            ("Eight-week volume buckets", tests.testWeeklyVolumeIncludesOnlyFinishedAndEightBuckets),
            ("Rest days and overlap boundaries", tests.testRestDaysAndOverlapBoundaries),
            ("Reject malformed backups", tests.testRejectUnsupportedAndMalformedBackups),
            ("Empty history and plan", tests.testEmptyHistoryAndEmptyPlanDayAreValid),
            ("Empty routines and API-only library", tests.testFreshInstallHasNoStaticExercisesOrRoutines),
            ("Search aliases and combined filters", tests.testSearchAliasesAndCombinedFilters),
            ("Preserve IDs during library upgrade", tests.testLibraryUpgradePreservesIdentityAndCustomEdits),
            ("Custom schedules and ordered selection", tests.testCustomScheduleAndOrderedSelection),
            ("Legacy backup and custom routine round trip", tests.testLegacyBackupAndCustomRoutineRoundTrip),
            ("Rest timer elapsed time and pause", tests.testRestTimerSurvivesElapsedTimePauseAndRoundTrip),
            ("Duplicate and workout-only swaps", tests.testDuplicateAndSwapPreserveRoutineAndCompletedWork),
            ("Weekly goals and week boundaries", tests.testWeeklyGoalBoundariesAndUnfinishedWeek),
            ("Performance excludes unchecked and draft sets", tests.testPerformanceMetricsExcludeDraftsAndUncheckedSets),
            ("Retain Health summary after no match or failure", tests.testEmptyAndFailedHealthRefreshKeepSavedSummary),
            ("Enhanced backups and persistent routine order", tests.testEnhancedBackupCompatibilityAndRoutineOrder),
            ("Guides match only specific catalog entries", tests.testSampleGuidesOnlyAttachToMatchingCatalogExercises),
            ("Superset sequence and rest", tests.testSupersetAlternatesAndRestsOnlyAfterPair),
            ("Uneven supersets and swaps", tests.testSupersetUnevenSetsAndSwapMembership),
            ("Set undo protects newer edits", tests.testUndoSetKeepsUnrelatedNotesAndNewerTimer),
            ("Swap undo preserves other logs", tests.testUndoSwapPreservesOtherExerciseAndRestoresPair),
            ("Workout deletion undo", tests.testUndoDeletionRestoresHealthAndRejectsTwoDrafts),
            ("Combined history filters and boundaries", tests.testCombinedHistoryFiltersUseInclusiveStartExclusiveEnd),
            ("Plate inventory and exact or lower loads", tests.testPlateCalculatorHonorsInventoryAndNeverRoundsUp),
            ("Training metadata and legacy backups", tests.testTrainingMetadataRoundTripAndValidation)
        ]
        for (name, test) in cases { try test(); print("PASS: \(name)") }
        print("\(cases.count) core checks passed.")
    }
}

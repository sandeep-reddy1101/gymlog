# Studio implementation — October 11, 2026

Status: implementation approved by the user and delivered on `feature/studio-design`. Automated validation is recorded in [VALIDATION.md](VALIDATION.md). Native simulator smoke testing passed after the user unlocked the Mac, including real catalog search, set logging, draft retention, drag/accessibility reorder, session/routine isolation, theme switching, large text, cold launch and finish/summary/progress. Physical Health/Watch acceptance remains pending.

## What changed

Studio uses warm stone surfaces, olive actions and citron selection in dark mode, with compact serif headings. Velocity supplies a second palette on the same screens. Settings persists design and appearance independently. `AppTheme` provides semantic colors, heading style and shared geometry through SwiftUI environment; shared panels and buttons resolve these values without replacing view identity. Other system typography scales with Dynamic Type. Native List/Form sections adopt themed surfaces. There are no colored callout stripes or card-top outlines.

Train now shows a compact routine summary and exercise rows. Starting/resuming opens all session exercises, including their completion counts and pairing labels. Choosing a row opens the existing logger for that exercise, preserving numeric controls, guide, optional effort, notes, targets, previous sets, calculator and swap. Quick-complete only acts on that exercise and never navigates automatically. Return controls appear above and below the logger.

Live order changes reorder whole `ExerciseLog` values by stable ID. Drag handles, arrow menus and VoiceOver move actions are available. They do not change the saved routine. The explicit Save lineup to routine action copies membership, order and session pairings; retains the routine's latest name, days, color and targets for retained exercises; and registers any missing exercise snapshots in the library. It leaves the session untouched. A deleted routine cannot be recreated silently. Pair members need not be adjacent to remain paired.

The existing API browser accepts either a routine or an active-session destination. Adds are atomic, deduplicated and limited to 100 exercises. Custom exercise creation uses the same destination. Search/filter/review state remains in the sheet after an add. Existing catalog cache, matching and playback code is unchanged.

Valid entries still persist immediately. Incomplete text is retained in memory by set ID and baseline data, and restored on returning to an exercise. Invalid text cannot be submitted by the bottom quick-complete button. A changed unit, undo or changed underlying set invalidates the stale draft. Import/reset clears the draft map. Cold launch restores saved values, not invalid text.

## Feature preservation map

| Existing capability | Location / behavior after redesign | Evidence and remaining check |
| --- | --- | --- |
| Multiple routines, names, schedule, colors, duplication, deletion, routine/exercise order | Routines; Plan from an active workout | Create/select routine and explicit lineup save checked natively; full management regression remains a device checklist |
| API library, exact-word search, filters, pagination, cache, saved/custom exercises, guide playback | Add exercises and exercise options | Existing provider/search/cache/playback tests pass; live search and repeated routine/session additions checked natively |
| Quick-fill, stable IDs, weight units, completed sets, optional effort, notes, targets | Focused logger; History → Edit sets | Tests pass; native set completion, invalid draft retention, historical editor and saved values checked |
| Supersets, session swap, undo, add/remove sets | Pair labels, exercise options, set menu, Undo banner | Existing pairing, swap, rest and undo tests pass; manual choice replaces automatic next-exercise suggestion |
| Rest countdown, pause, extend, skip, background alerts | Bottom rest controls and Settings | Timer logic unchanged and tested; real notification delivery pending |
| History editing, deletion/undo, filters and Health matching | History | Existing filter/undo/Health logic tests pass; saved summary and historical editor checked natively; remaining filter/delete flows use existing tests |
| Trends, records, weekly goal, heatmap, Health trends | Progress | Tests pass; native total, weekly count, volume and chart data reflect the completed test session |
| Plate calculator | Settings and barbell exercise options | Existing calculator tests pass |
| Backups, old payloads, reset, isolated sample mode | Settings | Existing validation tests plus theme/backup compatibility tests pass |
| Watch recording, live metrics, finish/recovery and Health | Existing Watch card and Settings controls | Watch code unchanged; protocol tests and embedded Watch compilation pass; physical acceptance pending |
| Navigation retention | Same tab/navigation trees; stable record IDs | No theme-keyed root replacement; native theme/tab switches preserve focused exercise and invalid draft; cold launch loads persisted workout |
| Signing and identity | Existing schemes, team, bundles and icon | All 12 project/phone/Watch configuration dictionaries verified unchanged |

## Broader device acceptance checklist

The focused simulator smoke test above covers the main redesign paths; this broader checklist is not a claim that every combination has been executed. Use an isolated sample or test routine. Do not delete the user's app/data to test this design.

- Open Studio light/dark and Velocity light/dark; check readable action labels, selected rows, forms, charts, long names and large Dynamic Type. Confirm 44 pt tap targets and keyboard reachability on a small iPhone. No colored side stripes or card-top borders.
- Create a routine with several exercises, targets and a pair. Start it; select the last exercise first. Edit weight/reps, complete/undo, add/remove a set with confirmation, enter effort and notes. Returning to the lineup preserves counts and values.
- Leave a partially typed/empty field, return to lineup, select another exercise and return. Draft text should remain; quick-complete must not record the invalid entry. Switch tabs and theme, then repeat. Cold launch should retain only valid saved values.
- Reorder by drag and by arrow menu/VoiceOver. Verify log identities, values, notes, targets, pair labels and rest state. Check the routine remains unchanged until explicit save. Edit the routine while a workout is active and verify the active snapshot is independent.
- Add from live workout; stay in the same search after Add. Confirm membership only in session. Add from routine and confirm the active session is unchanged. Save session lineup to routine; confirm additions/order, latest routine name/days and retained targets.
- Swap an uncompleted exercise, use the return control, and verify the replacement in the lineup. Completed-exercise swap stays blocked. Undo remains available. Deleting the original routine disables Save lineup to routine without deleting the session.
- Pause/extend/skip rest, background the app, return and inspect the elapsed countdown. Finish with partial sets and confirm; inspect History and edit a set. Check Progress and filters.
- Export/import a test backup; verify theme, records, routine order and unfinished session. Test a legacy backup and invalid theme fallback without altering original user data.
- Separately on paired physical devices: verify Health permissions, opt-in Watch recording, metrics/summary delivery, finish, offline recovery and notification delivery. A simulator build cannot establish this behavior.

# Studio refinement — approved direction and requested behavior

October 10, 2026: the user selected **Studio** as the design direction. October 11: the user approved native implementation, now recorded in [Studio implementation](STUDIO_IMPLEMENTATION.md). The original preview contract follows. This supersedes the earlier recommendation of Velocity and the oversized editorial headings.

## User feedback captured

1. Use Studio, but make themes easy to switch during development and in the app.
2. Large introductory text consumes useful space and forces scrolling. Use short, compact headings.
3. Show every exercise in the day's workout and let the user choose and change the order.
4. Buttons and status bubbles should be compact and attractive without wasting space or becoming hard to tap.

## Refined flow

Train → Start / Resume → **full workout lineup** → tap any exercise → log sets.

The lineup displays all exercises, in the user's saved order, with completed-set counts. It is not restricted to the first three exercises. The user can begin with any exercise, switch midway and return to unfinished work. Completing a set never automatically selects another exercise. The focused logger has an **All N exercises** control and position indicator at the top, plus Choose another exercise below. These open the same lineup; switching does not finish a workout.

Reorder opens an explicit list of the entire lineup. The web preview uses accessible Move up / Move down buttons. The native implementation should add drag handles and VoiceOver move actions; drag gestures must not be the only way to reorder. Keep identity, draft values, completed sets, notes, targets and supersets attached to exercise IDs, not their row positions.

### Routine versus session

- Starting a new workout copies the user's routine order into the session.
- Reordering from the live workout changes **this session only** by default.
- **Save lineup to routine** explicitly copies the session lineup into the saved routine for future sessions. This includes added exercises, as the label describes the whole lineup.
- Reordering in the routine editor changes the saved routine. It does not rearrange an already-started session.
- Adding from a live workout targets that session; adding from the routine editor targets the routine. Neither operation closes search after the add.
- Preserve exercise drafts, completed data and active selection across reordering, theme changes, ordinary backgrounding and navigation.
- An empty session, removals with completed data and superset ordering need their own production decisions. Do not silently delete logged sets or break a superset. These are not demonstrated by this first refinement.

## Compact visual rules

- Keep Studio's stone / olive palette and restrained serif headings. Replace oversized multi-line slogans with functional titles such as Your routine, Add exercises and Session saved.
- Preview headings are 27–29 px instead of the earlier 51 px display style. Long names wrap naturally; production must scale with Dynamic Type rather than enforce a fixed height.
- Primary actions are 48 px tall in the preview. Secondary actions and reorder targets are at least 44 × 44 px. Native targets should meet the equivalent 44 pt minimum.
- Reduce background padding, corner radii and gaps before reducing touch area or type size. Prefer plain text for secondary statuses instead of enclosing each in a pill.
- Use one compact routine summary, normal-density exercise rows and a focused weight/reps entry area. Keep the main action available near the fields.
- Longer workout lists can scroll naturally. Do not shrink every row to fit an arbitrary number of exercises onto a single screen.
- The rejected coral side stripes and colored curved card-top strokes remain excluded.

## Theme architecture for development

Use a shared semantic theme definition, applied at the app root, containing:

| Category | Shared roles |
| --- | --- |
| Colors | Canvas, secondary surface, primary/secondary text, divider, primary action, action foreground, selection, error, success |
| Typography | Page title, exercise title, body, secondary label, numeric input |
| Geometry | Spacing scale, compact/default corner radii, row insets, minimum hit target and primary-action height |
| Appearance | System / Light / Dark, resolved independently of palette selection |

Studio is the default theme. Keep layout and workout behavior independent of the theme; no screen-specific hard-coded palette or duplicate screen trees for different themes. Persist the theme identifier and appearance choice as preferences, without altering workout records or resetting navigation. Treat invalid/removed theme IDs as Studio. Supply tokens through a shared SwiftUI environment/theme provider and shared button, row and input components.

The preview demonstrates the separation: Settings → Theme changes Studio / Velocity on the **same compact layout**, and Appearance selects System / Light / Dark. Existing drafts, ordering and completed sets remain intact. Velocity is included to prove the switchable theme mechanism, not as a renewed recommendation over the selected Studio direction. The exact set of production themes can be finalized later.

## Prototype and checks

[Standalone refined Studio preview](designs/studio-refined.html) · [Editable source](designs/studio-refined.fragment.html).

This preview uses five sample planned exercises, a small sample search catalog, a static labeled rest timer and no live API or Health connection. The production library and cache rules remain unchanged. Full progress charts, multiple routines, historical editing and other existing features remain requirements even where omitted in this focused preview.

Verification covers choosing an exercise out of order; separate drafts per exercise; completing/undoing; reordering while preserving recorded data; session order versus routine order; explicitly saving the session lineup; adding only to the intended target while remaining in search; and preserving the session through palette/appearance changes. Native drag, keyboard, VoiceOver, haptics and physical-device testing remain pending.

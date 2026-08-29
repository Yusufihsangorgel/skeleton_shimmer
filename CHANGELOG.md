## 1.2.2

- The package description in pubspec.yaml is now 166 characters. It was 192.
  pub.dev wants it between 60 and 180 — search results truncate a longer one —
  and was withholding 10 of the package's 160 pub points for it. It still
  names the three things that distinguish the package: one sweep shared
  across every placeholder, drop-in compatibility with the shimmer package,
  and reduced-motion awareness.

## 1.2.1

- The README sample now says which class in it is yours to write. It read like
  the package supplied one, so copying it left a reader guessing at what was
  missing.

## 1.2.0

- The README now answers, in its first screen, why to reach for this rather
  than the zero-dependency route or the package that already owns the
  category. Both answers carry the file and line, or the issue number, that
  a reader can check. A "reach for it when" list and a sentence on when to
  skip it follow, because a page that only argues for itself is not useful
  for deciding.

## 1.1.1

- The README leads with the recording of the package working. The file was
  already in the repository and the page never showed it, so a reader had to
  scroll past the prose to find out what the package does, or never found out.

## 1.1.0

- Add `ShimmerScope`, which puts every `Shimmer` below it on one clock and one
  band. On their own, five cards are five animations: each widget starts its
  own controller when it mounts and sweeps a full highlight across its own
  box, and all five peak at the same moment. Under a scope, each widget paints
  the slice of one shared sweep that lands where the widget is. One band
  crosses the screen.
- The scope owns `period` and `loop`, because those describe the clock.
  Colors, `direction`, `enabled` and `semanticsLabel` stay on each widget. A
  widget with `enabled: false` holds still on the part of the band it was
  showing while its neighbours keep going, and reduced motion freezes the
  shared clock the way it froze a lone widget's.
- The band is anchored to the scope's box, and a widget's offset inside it is
  resolved during paint rather than at build time. A row scrolling through a
  scoped list therefore moves through the band instead of carrying a copy
  along.
- A `Shimmer` with no scope above it renders the pixels it rendered in 1.0.1.
  `test/shimmer_scope_test.dart` keeps a transcription of that implementation
  and renders the two side by side on one clock, comparing every pixel at
  eight points of a sweep in each of the four directions.
- The example is now a small dashboard with two switches: one wraps the feed
  in a `ShimmerScope`, the other stands in for the platform's reduced-motion
  setting. The README's figures are captured from widget-test runs that
  assert the difference they illustrate before writing the file.

## 1.0.1

- Add `example/README.md` for pub.dev's Example tab. It describes the demo's
  loading pattern — skeleton rows under a `Shimmer` swapped for real content —
  with the demo gif and the key snippet. Docs only.

## 1.0.0

First stable release. From here the public API follows semantic versioning: a
breaking change will not land without a major-version bump.

- Mark `Shimmer`, `SkeletonBox`, `SkeletonCircle` and `SkeletonLine` as
  `final`. All four are leaves: they are meant to be used and composed, not
  extended or implemented, and nothing in the package, its tests or its example
  subtypes them. Sealing them is what keeps the rest of 1.x additive, because
  adding an optional parameter to a class someone has implemented is a breaking
  change for that implementer. This is the one breaking change in the release,
  and it is deliberately made at the boundary where breaking changes are
  allowed: `final` cannot be added later without a 2.0.0, while removing it
  later would break nobody. `ShimmerDirection` needs nothing, since an enum
  cannot be extended or implemented from outside.
- No behaviour change. The animation, the widgets, their parameters and their
  defaults are exactly what 0.2.2 shipped.

## 0.2.2

- Fix a frozen sweep when `loop` is increased at runtime after a finite loop
  has already finished. Finishing a finite loop parks the controller at the
  upper bound of its range; raising `loop` reset the completed-loop count and
  called `forward()` to resume, but `forward()` from the upper bound does
  nothing, so the sweep stayed frozen instead of running the added loops. It
  now restarts from the start of the range when the controller is parked at
  completion, and still resumes in place when `enabled` is toggled back on
  mid-sweep.

## 0.2.1

- Fix `Shimmer.fromColors` so `ShimmerDirection.ttb`/`.btt` actually sweep
  vertically. The gradient's color axis was hardcoded to top-left ->
  center-right regardless of `direction`, so on a wide/short child (most
  skeleton shapes: list rows, cards, text lines) the highlight barely moved
  for `ttb`/`btt` even though the paint window was sliding correctly. The
  axis now follows `direction`: horizontal for `ltr`/`rtl`, vertical for
  `ttb`/`btt`.

## 0.2.0

- Skeleton placeholders no longer reach the semantics tree. A skeleton screen
  stands in for content that has not arrived; as plain containers the shapes
  were a run of empty nodes for a screen reader user to walk past, saying
  nothing about why they were there.
- Add `Shimmer.semanticsLabel`, which announces the loading state as a live
  region, so the skeleton is read when it appears rather than passed over in
  silence. It mirrors `CircularProgressIndicator.semanticsLabel`, default
  included: there is none, because the package cannot invent a localized
  string and should not announce English into every app.

## 0.1.2

- Docs: tightened the README wording and visuals.

## 0.1.1

- Expand the package description to name what the package does in the
  words people search for. No code changes.

## 0.1.0

Initial release.

- `Shimmer` and `Shimmer.fromColors`, API-compatible with the `shimmer`
  package: `ShimmerDirection` (ltr/rtl/ttb/btt), `period`, `loop`,
  `enabled`.
- Reduced-motion support: the sweep freezes when
  `MediaQuery.disableAnimations` is set.
- Skeleton placeholder primitives: `SkeletonBox`, `SkeletonCircle`,
  `SkeletonLine`.

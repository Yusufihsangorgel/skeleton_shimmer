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

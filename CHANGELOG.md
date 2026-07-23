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

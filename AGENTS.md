# AGENTS.md

For coding agents working on this package, or adding it to an app.

## What this is

`skeleton_shimmer` paints a moving highlight over placeholder widgets so a
loading screen previews the layout that is coming. Several `Shimmer`s under a
`ShimmerScope` share one clock and one band; with no scope, `Shimmer` is
API-compatible with `shimmer`.

Do not add this dependency unless the call site needs that shared sweep or a
reduced-motion freeze that keeps the placeholders. The category is crowded.

- **`shimmer`** is the widely used package this one is API-compatible with.
  Each widget owns its own `AnimationController` (one clock per widget) and
  `shimmer` never reads reduced motion, so a row of cards all peak at once
  and the sweep keeps running after the platform asked it to stop. Use it
  for a single placeholder: there is nothing to synchronize.
- **`skeletonizer`** paints bones over the real widget tree. Use it when the
  loaded layout already exists and you do not want a parallel skeleton of
  `SkeletonBox` / `SkeletonCircle` / `SkeletonLine`.

## Usage

`ShimmerScope` wraps the list. Each row still has its own `Shimmer.fromColors`.
In `example/lib/main.dart` that is `ShimmerScope(child: feed)`, not a scope
inside `_SkeletonCard` or `_SkeletonRow`.

```dart
import 'package:flutter/material.dart';
import 'package:skeleton_shimmer/skeleton_shimmer.dart';

Widget feed() => ShimmerScope(
  child: ListView(
    children: [
      Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: const Row(
          children: [
            SkeletonCircle(size: 40),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLine(width: 180),
                  SizedBox(height: 8),
                  SkeletonLine(width: 120, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  ),
);
```

## Contracts

- **Clock.** `ShimmerScope` owns `period` and `loop`. Those fields on a child
  `Shimmer` are ignored. Colors, `Shimmer.direction`, `Shimmer.enabled`, and
  `Shimmer.semanticsLabel` stay on the child. The scope's own `enabled` pauses
  every child; `Shimmer.enabled` pauses only that child and holds the band it
  was showing.
- **No scope.** The `Shimmer` owns the controller and sweeps its own box.
  Pixels match the pre-scope implementation (`test/shimmer_scope_test.dart`).
- **Reduced motion.** `MediaQuery.disableAnimationsOf` freezes the sweep. It
  does not hide the placeholders. The `ShaderMask` and the bones stay; the
  highlight stops moving. Do not swap in a `CircularProgressIndicator`.
- **Gradient vs shape.** `Shimmer.fromColors` builds a `LinearGradient` whose
  axis follows `ShimmerDirection`: `Alignment.centerLeft` →
  `Alignment.centerRight` for `ltr`/`rtl`, `Alignment.topCenter` →
  `Alignment.bottomCenter` for `ttb`/`btt`. The paint window slides on that
  same axis. A custom `Gradient` on `Shimmer(...)` is used as given. On a wide,
  short child, `ttb`/`btt` with a horizontal color axis barely moves.

Nearest `ShimmerScope` wins. `loop: 0` (default) repeats until dispose or
`enabled: false`. Under a scope, offset is resolved during paint, so a
scrolling row moves through the band.

## Mistakes

These fail visually. Nothing throws.

1. **`ShimmerScope` inside the item builder.** Every card still peaks at the
   same instant: each scope is one card's box, so the shared-band path is a
   no-op. Wrap the list once.
2. **No scope, one `Shimmer` per card.** Same picture. Add `ShimmerScope`
   around the list.
3. **`period` / `loop` on the child under a scope.** Changing them does
   nothing. Set them on `ShimmerScope`.
4. **`loop: 0` expecting no animation.** It repeats forever (same as `shimmer`).
   Use a positive `loop` or `enabled: false`.
5. **`ShimmerDirection.ttb` / `btt` with a hand-built horizontal `Gradient` on
   a row.** The sweep looks frozen. Use `Shimmer.fromColors`, or give the
   custom gradient a vertical axis.
6. **`MediaQuery(data: MediaQueryData(...), ...)`.** A fresh `MediaQueryData`
   drops text scale and padding. A bare `MediaQueryData()` sets
   `disableAnimations` to false and the sweep runs for someone who asked it
   not to. Use `MediaQuery.of(context).copyWith`.
7. **Child with no opaque pixels.** Blank: `ShaderMask` uses `BlendMode.srcIn`.
   Put `SkeletonBox`, `SkeletonCircle`, or `SkeletonLine` under the `Shimmer`.
8. **No `semanticsLabel`.** Screen-reader silence; the shapes are
   `ExcludeSemantics`. Pass a localized `Shimmer.semanticsLabel`.
9. **Nested scopes.** The inner clock wins; the outer `period`/`loop` are
   ignored.
10. **`enabled: !MediaQuery.disableAnimationsOf(context)`.** Fights the
    built-in freeze. `enabled` is the app's own pause (e.g. offscreen).

While the band is frozen (`enabled: false` or reduced motion), scrolling does
not recompute the slice; the band travels with the row until something else
repaints.

## Layout

- `lib/skeleton_shimmer.dart` — public API: `Shimmer`, `Shimmer.fromColors`,
  `ShimmerDirection`, `ShimmerScope`, `SkeletonBox`, `SkeletonCircle`,
  `SkeletonLine`
- `lib/src/shimmer.dart`, `lib/src/skeletons.dart` — implementations
- `example/lib/main.dart` — dashboard; shared-sweep switch and reduced-motion
  switch
- `test/` — widget tests. Capture tests are tagged `demo`; CI runs
  `flutter test --exclude-tags demo`.

```
flutter test --exclude-tags demo
cd example && flutter run
```

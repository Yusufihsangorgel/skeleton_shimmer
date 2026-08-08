# skeleton_shimmer example

The example app in `lib/main.dart` shows the usual loading pattern: a list of
skeleton placeholders under a `Shimmer` while data loads, swapped for the real
list once it arrives. The skeletons are built from `SkeletonCircle` and
`SkeletonLine` laid out to match the real rows, so the shimmer traces the shape
of what is coming.

![The example app: shimmering skeleton rows resolving into loaded content](https://raw.githubusercontent.com/Yusufihsangorgel/skeleton_shimmer/main/doc/demo.gif)

```dart
// While loading, mirror the real layout with skeleton shapes under a Shimmer.
Shimmer.fromColors(
  baseColor: Colors.grey.shade300,
  highlightColor: Colors.grey.shade100,
  child: const ListTile(
    leading: SkeletonCircle(size: 40),
    title: SkeletonLine(width: 180),
    subtitle: SkeletonLine(width: 120, height: 12),
  ),
);

// When the data is in, show the real widgets instead.
```

## Reduce motion

The switch above the feed stands in for the platform's own setting (iOS Reduce
Motion, Android Remove animations). Turn it on and the sweep freezes on the
base color while the rows keep showing the shape of what is loading. Nothing in
the app talks to `Shimmer` about motion; it reports what the platform asked for
and `Shimmer` decides.

```dart
final platform = MediaQuery.of(context);

// copyWith, and the ||, so a demo switch can only add the request. Writing
// `disableAnimations: simulateReduceMotion` would overwrite a real Reduce
// Motion setting with false the moment the switch was off.
MediaQuery(
  data: platform.copyWith(
    disableAnimations: platform.disableAnimations || simulateReduceMotion,
  ),
  child: feed,
);
```

On a device that already asks for reduced motion the switch is disabled: there
is nothing left to turn on, and the only thing it could do is write over the
answer the user already gave.

Run it:

```
cd example
flutter run
```

`Shimmer` animates any child, and `SkeletonBox`, `SkeletonCircle` and
`SkeletonLine` are the placeholder shapes; `ShimmerDirection` controls the sweep.
See the package README for the full surface.

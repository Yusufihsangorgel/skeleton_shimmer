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

Run it:

```
cd example
flutter run
```

`Shimmer` animates any child, and `SkeletonBox`, `SkeletonCircle` and
`SkeletonLine` are the placeholder shapes; `ShimmerDirection` controls the sweep.
See the package README for the full surface.

# skeleton_shimmer example

The example app in `lib/main.dart` shows the usual loading pattern: a skeleton
dashboard while data loads, swapped for the real one once it arrives. The
placeholders are built from `SkeletonCircle` and `SkeletonLine`, laid out to
match the real rows. The shimmer then traces the shape of what is coming.

![The example app: shimmering skeleton rows resolving into loaded content](https://raw.githubusercontent.com/Yusufihsangorgel/skeleton_shimmer/main/doc/demo.webp)

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

## Share one sweep

The screen has seven `Shimmer`s: three stat tiles and four rows, the way any
builder that returns a card leaves you. The first switch wraps the feed in a
`ShimmerScope`, which is the only line that changes:

```dart
shareOneSweep ? const ShimmerScope(child: feed) : feed
```

Turn it off and each card runs a full highlight across its own width: the
three tiles peak together. Turn it on and one band crosses the whole feed. The
tiles are where it shows most, since each one is a third of the row.

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

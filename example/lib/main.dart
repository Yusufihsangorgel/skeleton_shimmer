// skeleton_shimmer example: a skeleton dashboard while the data loads, with
// the two switches that decide how it moves.
//
// The loading pattern is the easy half. Mirror the layout that is coming with
// SkeletonCircle/SkeletonLine, put a Shimmer over it, swap in the real rows
// once the data arrives. The FAB stands in for the request completing.
//
// The first switch is the one to try first. This screen has seven separate
// Shimmers, which is what you get from any builder that returns a card: each
// one owns a clock and sweeps the highlight across its own box, and the three
// stat tiles peak together because each is running its own full sweep across
// 100-odd pixels. ShimmerScope hands all seven one clock and one band, and
// each widget paints the slice of it that lands where the widget is.
//
// The second switch is the accessibility half. A skeleton with `loop: 0`
// sweeps for as long as the request takes, which is motion the user never
// started and cannot predict the end of. Reduce Motion (iOS) and Remove
// animations (Android) exist to stop exactly that, and for someone with a
// vestibular disorder it is a symptom trigger rather than a preference.
//
// Honouring it costs nothing here: `Shimmer` reads
// `MediaQuery.disableAnimationsOf(context)` and stops the sweep, keeping the
// gradient mask so the placeholders still preview the layout. The platform
// fills that flag in for you, since `MediaQueryData.fromView` copies it from
// `AccessibilityFeatures.disableAnimations`. The switch below stands in for
// the OS setting so the difference is visible on a machine that is not set
// up for it.
//
// Ignoring the flag does not just leave the sweep running at its usual speed.
// The same platform flag makes a default `AnimationController` run its
// duration at 5% (`AnimationBehavior.normal`), so a 1500 ms sweep would
// restart every 75 ms; measured on Flutter 3.41. The framework says as much
// where it documents `AnimationBehavior.preserve`, which exists to stop
// repeating animations "from flashing rapidly on the screen if the widget
// does not take the disableAnimations flag into account".

import 'package:flutter/material.dart';
import 'package:skeleton_shimmer/skeleton_shimmer.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'skeleton_shimmer example',
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      home: const DemoScreen(),
    );
  }
}

class DemoScreen extends StatefulWidget {
  const DemoScreen({super.key});

  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> {
  bool _loading = true;
  bool _shareOneSweep = true;
  bool _simulateReduceMotion = false;

  @override
  Widget build(BuildContext context) {
    // What the platform itself is asking for, before the switch has a say.
    final platformAsks = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      appBar: AppBar(title: const Text('skeleton_shimmer example')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => _loading = !_loading),
        tooltip: _loading ? 'Finish loading' : 'Load again',
        child: Icon(_loading ? Icons.check : Icons.refresh),
      ),
      body: Column(
        children: [
          SwitchListTile(
            value: _shareOneSweep,
            onChanged: (value) => setState(() => _shareOneSweep = value),
            title: const Text('Share one sweep'),
            subtitle: Text(
              _shareOneSweep
                  ? 'One ShimmerScope over the feed: one band crosses it.'
                  : 'A Shimmer per card: every card peaks at once.',
            ),
            secondary: const Icon(Icons.view_week_outlined),
          ),
          SwitchListTile(
            value: _simulateReduceMotion || platformAsks,
            // Nothing to toggle when the device already asked: the sweep is
            // frozen either way, and pretending otherwise would mean writing
            // the platform's answer back to false.
            onChanged: platformAsks
                ? null
                : (value) => setState(() => _simulateReduceMotion = value),
            title: const Text('Reduce motion'),
            subtitle: Text(_subtitle(platformAsks)),
            secondary: const Icon(Icons.accessibility_new),
          ),
          const Divider(height: 1),
          // Only the feed is wrapped, so these switches keep their own
          // animation and stay readable while the shimmer under them is
          // frozen. On a device the flag arrives at the root and covers the
          // whole tree.
          Expanded(child: _feed(context)),
        ],
      ),
    );
  }

  String _subtitle(bool platformAsks) {
    if (platformAsks) {
      return 'This device asks for reduced motion, so the sweep is already '
          'frozen.';
    }
    if (_simulateReduceMotion) {
      return 'Sweep frozen on the base color; the rows still show what is '
          'coming.';
    }
    return 'Simulates iOS Reduce Motion / Android Remove animations.';
  }

  /// The loading area, told what the platform wants.
  ///
  /// Note what is *not* here. No `enabled: !reduceMotion`: `enabled` is the
  /// app's own switch, for pausing a shimmer that scrolled offscreen, and
  /// hand-wiring the accessibility flag into it only duplicates what
  /// [Shimmer] already does. No swapping in a `CircularProgressIndicator`
  /// either, tempting as it looks: a spinner is motion too, it does not
  /// consult this flag at all, and it throws away the layout preview that
  /// was the reason to draw a skeleton.
  Widget _feed(BuildContext context) {
    final platform = MediaQuery.of(context);

    return MediaQuery(
      // `copyWith`, never a fresh `MediaQueryData(disableAnimations: true)`:
      // a new one drops every other platform value for this subtree, text
      // scale and view padding included. The same slip in the other direction
      // is the one that reaches users, since a bare `MediaQueryData()`
      // anywhere above a `Shimmer` resets the flag to false and the sweep
      // then runs for someone who asked it not to.
      //
      // The `||` is there for that second reason: a demo switch may add the
      // request and must never withdraw the platform's. Writing
      // `disableAnimations: _simulateReduceMotion` would overwrite a real
      // Reduce Motion setting the moment the switch was off.
      data: platform.copyWith(
        disableAnimations: platform.disableAnimations || _simulateReduceMotion,
      ),
      child: _loading
          ? _SkeletonDashboard(shareOneSweep: _shareOneSweep)
          : const _LoadedDashboard(),
    );
  }
}

class _SkeletonDashboard extends StatelessWidget {
  const _SkeletonDashboard({required this.shareOneSweep});

  final bool shareOneSweep;

  @override
  Widget build(BuildContext context) {
    const feed = _SkeletonFeed();
    // The only difference between the two states of the first switch. Nothing
    // below this line knows which one it is in.
    return shareOneSweep ? const ShimmerScope(child: feed) : feed;
  }
}

class _SkeletonFeed extends StatelessWidget {
  const _SkeletonFeed();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Three tiles side by side are where the two states look least alike:
        // each one is only a third of the width, so a sweep of its own is a
        // full highlight crossing 100 px while the shared one is a slice.
        const Row(
          children: [
            Expanded(child: _SkeletonCard(lines: 2, height: 76)),
            SizedBox(width: 12),
            Expanded(child: _SkeletonCard(lines: 2, height: 76)),
            SizedBox(width: 12),
            Expanded(child: _SkeletonCard(lines: 2, height: 76)),
          ],
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < 4; i++) ...[
          const _SkeletonRow(),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// One card, with its own `Shimmer`. A builder that returns a card is how most
/// screens end up with a Shimmer each.
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.lines, required this.height});

  final int lines;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < lines; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              SkeletonLine(height: i == 0 ? 14 : 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
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
    );
  }
}

class _LoadedDashboard extends StatelessWidget {
  const _LoadedDashboard();

  static const _stats = [
    ('Revenue', '\$12.4k'),
    ('Orders', '318'),
    ('Refunds', '4')
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            for (final (index, stat) in _stats.indexed) ...[
              if (index > 0) const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 76,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(stat.$2, style: theme.textTheme.titleMedium),
                      Text(stat.$1, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < 4; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(child: Text('$i')),
            title: Text('Item $i'),
            subtitle: const Text('Loaded content'),
          ),
      ],
    );
  }
}

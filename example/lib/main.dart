// skeleton_shimmer example: a skeleton feed while the data loads, and the
// accessibility switch that decides whether it moves.
//
// The loading pattern is the easy half. Mirror the layout that is coming with
// SkeletonCircle/SkeletonLine, put a Shimmer over it, swap in the real rows
// once the data arrives. The FAB stands in for the request completing.
//
// The switch is the half worth reading. A skeleton with `loop: 0` sweeps for
// as long as the request takes, which is motion the user never started and
// cannot predict the end of. Reduce Motion (iOS) and Remove animations
// (Android) exist to stop exactly that, and for someone with a vestibular
// disorder it is a symptom trigger rather than a preference.
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
          // Only the feed is wrapped, so this switch keeps its own animation
          // and stays readable while the shimmer under it is frozen. On a
          // device the flag arrives at the root and covers the whole tree.
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
      child: _loading ? const _SkeletonList() : const _LoadedList(),
    );
  }
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView.builder(
        itemCount: 8,
        // A skeleton is only useful if it resembles the row it stands in for,
        // and `ListTile` gets in the way here: it lays its title and subtitle
        // out with a tightened width, so a bare `SkeletonLine(width: 180)`
        // comes out stretched across the whole row and every placeholder ends
        // up the same length. `Align` hands the line its own width back.
        itemBuilder: (context, index) => const ListTile(
          leading: SkeletonCircle(size: 40),
          title: Align(
            alignment: Alignment.centerLeft,
            child: SkeletonLine(width: 180),
          ),
          subtitle: Align(
            alignment: Alignment.centerLeft,
            child: SkeletonLine(width: 120, height: 12),
          ),
        ),
      ),
    );
  }
}

class _LoadedList extends StatelessWidget {
  const _LoadedList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 8,
      itemBuilder: (context, index) => ListTile(
        leading: CircleAvatar(child: Text('$index')),
        title: Text('Item $index'),
        subtitle: const Text('Loaded content'),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:skeleton_shimmer/skeleton_shimmer.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  bool _loading = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'skeleton_shimmer example',
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      home: Scaffold(
        appBar: AppBar(title: const Text('skeleton_shimmer example')),
        floatingActionButton: FloatingActionButton(
          onPressed: () => setState(() => _loading = !_loading),
          child: Icon(_loading ? Icons.check : Icons.refresh),
        ),
        body: _loading ? const _SkeletonList() : const _LoadedList(),
      ),
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
        itemBuilder: (context, index) => const ListTile(
          leading: SkeletonCircle(size: 40),
          title: SkeletonLine(width: 180),
          subtitle: SkeletonLine(width: 120, height: 12),
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

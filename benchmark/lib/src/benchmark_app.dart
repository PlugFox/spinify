import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:spinifybenchmark/src/benchmark_controller.dart';
import 'package:spinifybenchmark/src/benchmark_tab.dart';

class BenchmarkApp extends StatefulWidget {
  const BenchmarkApp({super.key});

  @override
  State<BenchmarkApp> createState() => _BenchmarkAppState();
}

class _BenchmarkAppState extends State<BenchmarkApp> {
  final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(
      PlatformDispatcher.instance.platformBrightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light);

  @override
  void initState() {
    super.initState();
    themeMode.addListener(_onChanged);
  }

  @override
  void dispose() {
    themeMode.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  void toggleTheme() => themeMode.value = switch (themeMode.value) {
        ThemeMode.dark => ThemeMode.light,
        ThemeMode.light || _ => ThemeMode.dark,
      };

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Benchmark',
        themeMode: themeMode.value,
        theme: switch (themeMode.value) {
          ThemeMode.dark => ThemeData.dark(),
          ThemeMode.light || _ => ThemeData.light(),
        },
        home: _BenchmarkScaffold(
          themeMode: themeMode,
        ),
      );
}

class _BenchmarkScaffold extends StatefulWidget {
  const _BenchmarkScaffold({
    required this.themeMode,
    super.key, // ignore: unused_element
  });

  final ValueListenable<ThemeMode> themeMode;

  @override
  State<_BenchmarkScaffold> createState() => _BenchmarkScaffoldState();
}

class _BenchmarkScaffoldState extends State<_BenchmarkScaffold>
    with SingleTickerProviderStateMixin {
  final IBenchmarkController controller = BenchmarkControllerImpl();
  late final TabController tabBarController;

  @override
  void initState() {
    tabBarController = TabController(length: 2, vsync: this);
    super.initState();
  }

  @override
  void dispose() {
    controller.dispose();
    tabBarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Benchmark'),
          actions: <Widget>[
            ValueListenableBuilder(
              valueListenable: widget.themeMode,
              builder: (context, mode, _) => IconButton(
                icon: switch (mode) {
                  ThemeMode.dark => const Icon(Icons.light_mode),
                  ThemeMode.light => const Icon(Icons.dark_mode),
                  ThemeMode.system => const Icon(Icons.auto_awesome),
                },
                onPressed: () => context
                    .findAncestorStateOfType<_BenchmarkAppState>()
                    ?.toggleTheme(),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        bottomNavigationBar: ListenableBuilder(
          listenable: tabBarController,
          builder: (context, _) => BottomNavigationBar(
            currentIndex: tabBarController.index,
            onTap: (index) => tabBarController.animateTo(index),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.speed),
                label: 'Benchmark',
              ),
              /* BottomNavigationBarItem(
                icon: Icon(Icons.device_unknown),
                label: 'Unknown',
              ), */
              BottomNavigationBarItem(
                icon: Icon(Icons.help),
                label: 'Help',
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            controller: tabBarController,
            children: <Widget>[
              Align(
                alignment: Alignment.topCenter,
                child: BenchmarkTab(
                  controller: controller,
                ),
              ),
              /* Center(
                child: Text('Unknown'),
              ), */
              const Center(
                child: Text('Help'),
              ),
            ],
          ),
        ),
      );
}

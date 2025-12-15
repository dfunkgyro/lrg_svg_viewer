import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/svg_models.dart';
import 'services/theme_manager.dart';
import 'widgets/svg_viewport.dart';
import 'widgets/element_sidebar.dart';
import 'widgets/selection_tools_sidebar.dart';
import 'services/isolate_manager.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SvgModel()),
        ChangeNotifierProvider(create: (_) => ThemeManager()),
      ],
      child: const SvgApp(),
    ),
  );
}

class SvgApp extends StatelessWidget {
  const SvgApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeManager>(
      builder: (context, themeManager, child) {
        return MaterialApp(
          title: 'Advanced SVG Viewer Pro',
          debugShowCheckedModeBanner: false,
          theme: themeManager.getThemeData(),
          home: const SvgViewerPage(),
        );
      },
    );
  }
}

class SvgViewerPage extends StatefulWidget {
  const SvgViewerPage({super.key});

  @override
  State<SvgViewerPage> createState() => _SvgViewerPageState();
}

class _SvgViewerPageState extends State<SvgViewerPage> {
  final IsolateManager _isolateManager = IsolateManager();
  final ReceivePort _receivePort = ReceivePort();
  bool _showLeftSidebar = true;
  bool _showRightSidebar = true;

  @override
  void initState() {
    super.initState();
    _initializeIsolate();
  }

  void _initializeIsolate() {
    _isolateManager.initialize(_receivePort.sendPort);
    _receivePort.listen(_handleIsolateMessage);
  }

  void _handleIsolateMessage(dynamic message) {
    _isolateManager.processMessage(context, message);
  }

  Future<void> _uploadSvg() async {
    await _isolateManager.uploadSvg(context);
  }

  @override
  void dispose() {
    _receivePort.close();
    _isolateManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.layers,
              color: Theme.of(context).appBarTheme.foregroundColor,
            ),
            const SizedBox(width: 8),
            const Text('SVG Viewer Pro'),
          ],
        ),
        actions: [
          // Toggle left sidebar
          IconButton(
            icon: Icon(
              _showLeftSidebar ? Icons.chevron_left : Icons.chevron_right,
            ),
            onPressed: () {
              setState(() {
                _showLeftSidebar = !_showLeftSidebar;
              });
            },
            tooltip: _showLeftSidebar
                ? 'Hide Element List'
                : 'Show Element List',
          ),

          // Toggle right sidebar
          IconButton(
            icon: Icon(
              _showRightSidebar ? Icons.chevron_right : Icons.chevron_left,
            ),
            onPressed: () {
              setState(() {
                _showRightSidebar = !_showRightSidebar;
              });
            },
            tooltip: _showRightSidebar ? 'Hide Tools' : 'Show Tools',
          ),

          const SizedBox(width: 8),

          // Upload button
          Consumer<SvgModel>(
            builder: (context, model, _) {
              return IconButton(
                icon: const Icon(Icons.upload_file),
                onPressed: model.isParsing ? null : _uploadSvg,
                tooltip: model.isParsing ? 'Parsing...' : 'Upload SVG',
              );
            },
          ),

          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          // Left Sidebar - Element List
          if (_showLeftSidebar) SizedBox(width: 300, child: ElementSidebar()),

          // Main Viewport
          Expanded(child: SvgViewport()),

          // Right Sidebar - Selection Tools
          if (_showRightSidebar) SelectionToolsSidebar(),
        ],
      ),
    );
  }
}

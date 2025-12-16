import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../models/svg_models.dart';
import '../services/theme_manager.dart';

class SelectionToolsSidebar extends StatelessWidget {
  const SelectionToolsSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SvgModel>(
      builder: (context, model, child) {
        final themeManager = Provider.of<ThemeManager>(context);
        model.ensureLearningLoaded();
        
        return Container(
          width: 300,
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              _buildHeader(context, model),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(8.0),
                  children: [
                  _buildSelectionStats(context, model),
                  const SizedBox(height: 16),
                  _buildGridLabelStatus(context, model),
                  const SizedBox(height: 16),
                  _buildSequenceStatus(context, model),
                  const SizedBox(height: 16),
                  _buildCompositeStatus(context, model),
                  const SizedBox(height: 16),
                  _buildLearningControls(context, model),
                  const SizedBox(height: 16),
                  _buildSelectionTools(context, model),
                    const SizedBox(height: 16),
                    _buildThemeSelector(context, themeManager),
                    const SizedBox(height: 16),
                    _buildGridQuickJump(context, model),
                    const SizedBox(height: 16),
                    _buildSelectedElementsList(context, model),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, SvgModel model) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.tune,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
              const SizedBox(width: 8),
              Text(
                'Selection Tools',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionStats(BuildContext context, SvgModel model) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selection Statistics',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            _buildStatRow(
              context,
              'Total Elements',
              '${model.elements.length}',
              Icons.layers,
            ),
            _buildStatRow(
              context,
              'Selected',
              '${model.selectedElements.length}',
              Icons.check_circle,
              color: Colors.blue,
            ),
            _buildStatRow(
              context,
              'Unique Types',
              '${model.getUniqueTagTypes().length}',
              Icons.category,
            ),
            _buildStatRow(
              context,
              'Grid Cells',
              '${model.totalGridCells}',
              Icons.grid_on,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridLabelStatus(BuildContext context, SvgModel model) {
    final selectedGrid = model.selectedGridId;
    if (selectedGrid == null) {
      return const SizedBox.shrink();
    }

    final labels = model.getGridUserLabelCounts(selectedGrid);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.label, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Grid $selectedGrid Labels',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (labels.isEmpty)
              Text(
                'No user labels in this grid yet.',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: labels.entries
                    .map(
                      (entry) => Chip(
                        label: Text('${entry.key} (${entry.value})'),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSequenceStatus(BuildContext context, SvgModel model) {
    final selectedGrid = model.selectedGridId;
    if (selectedGrid == null) return const SizedBox.shrink();
    final sequences = model.sequencesForGrid(selectedGrid);
    if (sequences.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              const Icon(Icons.text_fields, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'No grouped tags detected in grid $selectedGrid yet.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.text_snippet, size: 16, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Grouped Tags (Grid $selectedGrid)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...sequences.map(
              (seq) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Chip(
                      label: Text(seq.sequence),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    const SizedBox(width: 8),
                    if (seq.grids.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Text(
                          'Grids: ${seq.grids.join(',')}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey[700]),
                        ),
                      ),
                    Expanded(
                      child: TextField(
                        controller: TextEditingController(
                          text: seq.description ?? '',
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Add description',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (value) {
                          model.setSequenceDescription(
                              seq.sequence, value.trim());
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompositeStatus(BuildContext context, SvgModel model) {
    final selectedGrid = model.selectedGridId;
    if (selectedGrid == null) return const SizedBox.shrink();
    final composites = model.compositesForGrid(selectedGrid);
    final suggestions = model.compositeSuggestionsForGrid(selectedGrid);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.layers, size: 16, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Text(
                  'Composites (Grid $selectedGrid)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (composites.isEmpty)
              Text(
                'No composites detected yet.',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              Column(
                children: composites
                    .map(
                      (c) => ListTile(
                        dense: true,
                        leading: Chip(
                          label: Text('${c.partCount} parts'),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        title: Text(c.label),
                        subtitle: c.grids.length > 1
                            ? Text('Spans grids: ${c.grids.join(',')}')
                            : null,
                      ),
                    )
                    .toList(),
              ),
            if (suggestions.isNotEmpty) ...[
              const Divider(),
              Text(
                'Suggestions',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              ...suggestions.map(
                (s) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.lightbulb_outline, size: 16),
                  title: Text('${s.partCount} parts - ${s.reason}'),
                  trailing: TextButton(
                    child: const Text('Label'),
                    onPressed: () async {
                      final controller = TextEditingController();
                      final label = await showDialog<String>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Label composite'),
                          content: TextField(
                            controller: controller,
                            autofocus: true,
                            decoration: const InputDecoration(
                              hintText: 'Enter label',
                            ),
                            onSubmitted: (value) =>
                                Navigator.of(context).pop(value.trim()),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () =>
                                  Navigator.of(context).pop(controller.text.trim()),
                              child: const Text('Save'),
                            ),
                          ],
                        ),
                      );
                      if (label != null && label.isNotEmpty) {
                        final elements = model.elements
                            .where((e) => s.elementIds.contains(e.id))
                            .toList();
                        model.assignCompositeLabel(elements, label);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Composite labeled "$label"'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLearningControls(BuildContext context, SvgModel model) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, size: 16, color: Colors.purple),
                const SizedBox(width: 8),
                Text(
                  'Smart Labeling',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            SwitchListTile.adaptive(
              dense: true,
              title: const Text('Auto-apply learned tags'),
              subtitle: const Text('Disable to require confirmation before applying'),
              value: model.autoApplyLearned,
              onChanged: model.setAutoApplyLearned,
            ),
            SwitchListTile.adaptive(
              dense: true,
              title: const Text('Always confirm sequences'),
              value: model.confirmSequences,
              onChanged: model.setConfirmSequences,
            ),
            const SizedBox(height: 8),
            if (model.selectedElements.length > 1)
              ElevatedButton.icon(
                icon: const Icon(Icons.merge_type),
                label: Text('Merge & label ${model.selectedElements.length} selected'),
                onPressed: () async {
                  final controller = TextEditingController();
                  final label = await showDialog<String>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Label composite'),
                      content: TextField(
                        controller: controller,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'Enter label (e.g., 8 or R)',
                        ),
                        onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  );
                  if (label != null && label.isNotEmpty) {
                    model.assignCompositeLabelFromSelection(label);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Composite labeled "$label"'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  }
                },
              ),
            const Divider(),
            Row(
              children: [
                Icon(
                  model.supabaseConnected
                      ? Icons.cloud_done
                      : Icons.cloud_off,
                  color: model.supabaseConnected ? Colors.green : Colors.grey,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    model.supabaseConfigured
                        ? (model.supabaseConnected
                            ? 'Supabase connected'
                            : 'Supabase configured, offline')
                        : 'Supabase not configured',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.save_alt),
                  label: const Text('Export learning'),
                  onPressed: () async {
                    final result =
                        await FilePicker.platform.saveFile(dialogTitle: 'Export learning data');
                    if (result != null) {
                      await model.exportLearning(result);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Learning data exported'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    }
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Import learning'),
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['json'],
                    );
                    if (result != null && result.files.isNotEmpty) {
                      final path = result.files.first.path;
                      if (path != null) {
                        await model.importLearning(path);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Learning data imported'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      }
                    }
                  },
                ),
                TextButton.icon(
                  icon: const Icon(Icons.delete),
                  label: const Text('Clear learning'),
                  onPressed: () async {
                    await model.clearLearning();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Learning data cleared'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color ?? Theme.of(context).iconTheme.color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionTools(BuildContext context, SvgModel model) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selection Actions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _buildToolButton(
              context,
              'Select by Type',
              Icons.category,
              () => _showTypeSelectionDialog(context, model),
              enabled: model.elements.isNotEmpty,
            ),
            const SizedBox(height: 8),
            _buildToolButton(
              context,
              'Select in Viewport',
              Icons.crop_free,
              () {
                final size = MediaQuery.of(context).size;
                model.selectInViewport(size.width - 600, size.height);
                _showSnackBar(
                    context, 'Selected ${model.selectedElements.length} elements in viewport');
              },
              enabled: model.elements.isNotEmpty,
            ),
            const SizedBox(height: 8),
            _buildToolButton(
              context,
              'Select by Color',
              Icons.palette,
              () => _showColorSelectionDialog(context, model),
              enabled: model.getUniqueColors().isNotEmpty,
            ),
            const SizedBox(height: 8),
            _buildToolButton(
              context,
              'Select Overlapping',
              Icons.layers,
              () {
                model.selectOverlappingElements();
                _showSnackBar(
                    context, 'Selected ${model.selectedElements.length} overlapping elements');
              },
              enabled: model.elements.isNotEmpty,
            ),
            const SizedBox(height: 16),
            _buildToolButton(
              context,
              'Clear Selection',
              Icons.clear_all,
              () {
                model.clearSelection();
                _showSnackBar(context, 'Selection cleared');
              },
              enabled: model.selectedElements.isNotEmpty,
              color: Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onPressed, {
    bool enabled = true,
    Color? color,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: color != null ? Colors.white : null,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          alignment: Alignment.centerLeft,
        ),
      ),
    );
  }

  Widget _buildThemeSelector(BuildContext context, ThemeManager themeManager) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Theme',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildThemeChip(
                  context,
                  themeManager,
                  'Light',
                  AppThemeMode.light,
                  Icons.light_mode,
                ),
                _buildThemeChip(
                  context,
                  themeManager,
                  'Dark',
                  AppThemeMode.dark,
                  Icons.dark_mode,
                ),
                _buildThemeChip(
                  context,
                  themeManager,
                  'Inverse',
                  AppThemeMode.inverse,
                  Icons.invert_colors,
                ),
                _buildThemeChip(
                  context,
                  themeManager,
                  'Blueprint',
                  AppThemeMode.blueprint,
                  Icons.architecture,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeChip(
    BuildContext context,
    ThemeManager themeManager,
    String label,
    AppThemeMode mode,
    IconData icon,
  ) {
    final isSelected = themeManager.currentTheme == mode;
    
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          themeManager.setTheme(mode);
        }
      },
      selectedColor: Theme.of(context).colorScheme.primary,
      checkmarkColor: Theme.of(context).colorScheme.onPrimary,
      labelStyle: TextStyle(
        color: isSelected ? Theme.of(context).colorScheme.onPrimary : null,
      ),
    );
  }

  Widget _buildGridQuickJump(BuildContext context, SvgModel model) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.grid_on, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Grid Navigation',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Jump to specific grid location',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Grid ID (1-${model.totalGridCells})',
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onSubmitted: (value) {
                      final gridId = int.tryParse(value);
                      if (gridId != null &&
                          gridId > 0 &&
                          gridId <= model.totalGridCells) {
                        final size = MediaQuery.of(context).size;
                        model.navigateToGrid(gridId, size.width - 600, size.height);
                        _showSnackBar(context, 'Navigated to Grid $gridId');
                      } else {
                        _showSnackBar(context, 'Invalid grid ID', isError: true);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _showGridSearchDialog(context, model),
                ),
              ],
            ),
            if (model.selectedGridId != null) ...[
              const SizedBox(height: 8),
              Text(
                'Selected: Grid ${model.selectedGridId}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedElementsList(BuildContext context, SvgModel model) {
    if (model.selectedElements.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selected Elements (${model.selectedElements.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            ...model.selectedElements.take(10).map((element) {
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Text(
                      element.tagName.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                title: Text(
                  '<${element.tagName}>',
                  style: const TextStyle(fontSize: 12),
                ),
                subtitle: Text(
                  element.id,
                  style: const TextStyle(fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () => model.toggleElementSelection(element),
                ),
              );
            }).toList(),
            if (model.selectedElements.length > 10)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  '... and ${model.selectedElements.length - 10} more',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showTypeSelectionDialog(BuildContext context, SvgModel model) {
    final types = model.getUniqueTagTypes().toList()..sort();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Element Type'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: types.length,
            itemBuilder: (context, index) {
              final type = types[index];
              final count =
                  model.elements.where((e) => e.tagName == type).length;
              return ListTile(
                title: Text('<$type>'),
                subtitle: Text('$count element(s)'),
                onTap: () {
                  model.selectAllOfType(type);
                  Navigator.of(context).pop();
                  _showSnackBar(
                      context, 'Selected $count <$type> element(s)');
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showColorSelectionDialog(BuildContext context, SvgModel model) {
    final colors = model.getUniqueColors().toList()..sort();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select by Color'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: colors.length,
            itemBuilder: (context, index) {
              final color = colors[index];
              final count = model.elements
                  .where((e) => e.fillColor == color || e.strokeColor == color)
                  .length;
              return ListTile(
                leading: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _parseColor(color),
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                title: Text(color),
                subtitle: Text('$count element(s)'),
                onTap: () {
                  model.selectByColor(color);
                  Navigator.of(context).pop();
                  _showSnackBar(context, 'Selected $count element(s) with color $color');
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showGridSearchDialog(BuildContext context, SvgModel model) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Jump to Grid'),
        content: TextField(
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter grid number (1-${model.totalGridCells})...',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          onSubmitted: (value) {
            final gridId = int.tryParse(value);
            if (gridId != null && gridId > 0 && gridId <= model.totalGridCells) {
              final size = MediaQuery.of(context).size;
              model.navigateToGrid(gridId, size.width - 600, size.height);
              Navigator.of(context).pop();
              _showSnackBar(context, 'Navigated to Grid $gridId');
            } else {
              _showSnackBar(context, 'Invalid grid ID', isError: true);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message, {bool isError = false}) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : null,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Color _parseColor(String colorString) {
    try {
      if (colorString.startsWith('#')) {
        final hex = colorString.substring(1);
        if (hex.length == 6) {
          return Color(int.parse('FF$hex', radix: 16));
        } else if (hex.length == 8) {
          return Color(int.parse(hex, radix: 16));
        }
      }
      // Handle named colors
      switch (colorString.toLowerCase()) {
        case 'red':
          return Colors.red;
        case 'blue':
          return Colors.blue;
        case 'green':
          return Colors.green;
        case 'yellow':
          return Colors.yellow;
        case 'black':
          return Colors.black;
        case 'white':
          return Colors.white;
        default:
          return Colors.grey;
      }
    } catch (e) {
      return Colors.grey;
    }
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/svg_models.dart';
import 'virtualized_element_list.dart';

class ElementSidebar extends StatelessWidget {
  const ElementSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SvgModel>(
      builder: (context, model, child) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(2, 0),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildHeader(context, model),
              _buildRecognitionToggle(context, model),
              if (model.isParsing) const LinearProgressIndicator(),
              Expanded(
                child: VirtualizedElementList(
                  elements: model.elements,
                  totalElements: model.totalElements,
                  isParsing: model.isParsing,
                  onGridNavigate: (gridId) {
                    model.requestNavigateToGrid(gridId);
                  },
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
                Icons.layers,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'SVG Elements',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            context,
            Icons.check_circle,
            'Loaded',
            '${model.elements.length}',
            Theme.of(context).colorScheme.onPrimary,
          ),
          if (model.totalElements > model.elements.length)
            _buildInfoRow(
              context,
              Icons.all_inclusive,
              'Total',
              '${model.totalElements}',
              Theme.of(context).colorScheme.onPrimary,
            ),
          if (model.filePath != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.insert_drive_file,
                  size: 14,
                  color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    model.filePath!.split('/').last,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecognitionToggle(BuildContext context, SvgModel model) {
    return SwitchListTile.adaptive(
      dense: true,
      title: const Text('Recognize text in grids'),
      subtitle: const Text(
          'Hybrid: native <text>, heuristics for polylines, optional OCR per opened grid'),
      value: model.recognizeTextEnabled,
      onChanged: (value) {
        model.setRecognizeTextEnabled(value);
      },
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color.withOpacity(0.8)),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color.withOpacity(0.8),
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}

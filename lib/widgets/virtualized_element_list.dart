import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/svg_models.dart';

class VirtualizedElementList extends StatefulWidget {
  final List<SvgElementData> elements;
  final int totalElements;
  final bool isParsing;
  final Function(int)? onGridNavigate;

  const VirtualizedElementList({
    super.key,
    required this.elements,
    required this.totalElements,
    required this.isParsing,
    this.onGridNavigate,
  });

  @override
  State<VirtualizedElementList> createState() => _VirtualizedElementListState();
}

class _VirtualizedElementListState extends State<VirtualizedElementList> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, List<SvgElementData>> _groupedElements = {};
  final List<int> _gridKeys = [];

  @override
  void initState() {
    super.initState();
    _updateGroupedElements();
  }

  @override
  void didUpdateWidget(covariant VirtualizedElementList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.elements != widget.elements) {
      _updateGroupedElements();
    }
  }

  void _updateGroupedElements() {
    _groupedElements.clear();

    for (final element in widget.elements) {
      _groupedElements.putIfAbsent(element.gridId, () => []).add(element);
    }

    _gridKeys
      ..clear()
      ..addAll(_groupedElements.keys)
      ..sort();

    if (mounted) setState(() {});
  }

  void _navigateToGrid(int gridId) {
    final model = Provider.of<SvgModel>(context, listen: false);
    model.selectGridById(gridId);

    // Call the navigation callback if provided
    if (widget.onGridNavigate != null) {
      widget.onGridNavigate!(gridId);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.elements.isEmpty && !widget.isParsing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No elements found',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildNavigationHeader(context),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            itemCount: _gridKeys.length,
            itemBuilder: (context, index) {
              final gridId = _gridKeys[index];
              final elements = _groupedElements[gridId]!;

              return _GridGroupTile(
                gridId: gridId,
                elements: elements,
                elementCount: elements.length,
                onGridTap: () => _navigateToGrid(gridId),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationHeader(BuildContext context) {
    return Consumer<SvgModel>(
      builder: (context, model, _) {
        return Card(
          margin: const EdgeInsets.all(8.0),
          color: Colors.blue.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.grid_on, size: 18, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Grid-Based Navigation',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.blue[800],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Click any grid number below to navigate to that area',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[700],
                  ),
                ),
                if (model.selectedGridId != null) ...[
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Viewing: Grid ${model.selectedGridId}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GridGroupTile extends StatelessWidget {
  final int gridId;
  final List<SvgElementData> elements;
  final int elementCount;
  final VoidCallback onGridTap;

  const _GridGroupTile({
    required this.gridId,
    required this.elements,
    required this.elementCount,
    required this.onGridTap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<SvgModel>(
      builder: (context, model, _) {
        final isSelected = model.selectedGridId == gridId;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: isSelected ? Colors.blue.withOpacity(0.1) : null,
          elevation: isSelected ? 4 : 1,
          child: InkWell(
            onTap: onGridTap,
            child: ExpansionTile(
              leading: GestureDetector(
                onTap: onGridTap,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color:
                        isSelected ? Colors.blue : Colors.blue.withOpacity(0.2),
                    shape: BoxShape.circle,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.5),
                              blurRadius: 8,
                              spreadRadius: 2,
                            )
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '$gridId',
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.blue[800],
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              title: Row(
                children: [
                  Text(
                    'Grid Region $gridId',
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.blue[800] : null,
                    ),
                  ),
                  if (isSelected) ...[
                    SizedBox(width: 8),
                    Icon(Icons.my_location, size: 16, color: Colors.blue),
                  ],
                ],
              ),
              subtitle: Row(
                children: [
                  Icon(Icons.layers, size: 12, color: Colors.grey),
                  SizedBox(width: 4),
                  Text('$elementCount element(s)'),
                ],
              ),
              trailing: isSelected
                  ? Tooltip(
                      message: 'Currently viewing',
                      child: Icon(Icons.navigation, color: Colors.blue),
                    )
                  : Tooltip(
                      message: 'Click to navigate',
                      child: Icon(Icons.arrow_forward_ios, size: 16),
                    ),
              children: elements
                  .map((element) => _ElementListTile(element: element))
                  .toList(),
            ),
          ),
        );
      },
    );
  }
}

class _ElementListTile extends StatelessWidget {
  final SvgElementData element;

  const _ElementListTile({required this.element});

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<SvgModel>(context);
    final isSelected = model.selectedElement == element;
    final isInMultiSelection = model.selectedElements.contains(element);

    return ListTile(
      dense: true,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.blue.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
              border: isInMultiSelection
                  ? Border.all(color: Colors.orange, width: 2)
                  : null,
            ),
            child: Center(
              child: Text(
                element.tagName.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.blue[800] : Colors.grey[700],
                ),
              ),
            ),
          ),
          if (element.fillColor != null) ...[
            SizedBox(width: 4),
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _parseColor(element.fillColor!),
                border: Border.all(color: Colors.grey, width: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ],
      ),
      title: Text(
        '<${element.tagName}>',
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.blue[800] : null,
        ),
      ),
      subtitle: Text(
        'ID: ${element.id}',
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11),
      ),
      trailing: Text(
        '${element.boundingBox.width.toStringAsFixed(0)}×${element.boundingBox.height.toStringAsFixed(0)}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      selected: isSelected,
      selectedTileColor: Colors.blue.withOpacity(0.15),
      onTap: () {
        model.selectElement(element);

        // Zoom to selected element
        final media = MediaQuery.of(context);
        final appBarHeight =
            Scaffold.of(context).appBarMaxHeight ?? kToolbarHeight;
        final viewportHeight =
            media.size.height - appBarHeight - media.padding.top;
        final viewportWidth = media.size.width - 600;

        model.zoomToSelected(
            element.boundingBox, viewportWidth, viewportHeight);
      },
      onLongPress: () {
        model.toggleElementSelection(element);
      },
    );
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

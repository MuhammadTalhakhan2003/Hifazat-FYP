import 'package:flutter/material.dart';
import 'package:hifazat_app/providers/category_provider.dart';
import 'package:hifazat_app/providers/incident_provider.dart';
import 'package:provider/provider.dart';

class FilterDialog extends StatefulWidget {
  const FilterDialog({super.key});

  @override
  State<FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<FilterDialog> {
  // Local state for the dialog's selections
  List<int> _selectedCategoryIds = [];
  String _city = '';
  String _searchTerm = '';
  String _ordering = '-incident_date'; // Default sort
  
  @override
  void initState() {
    super.initState();
    // Load categories if not already loaded
    Provider.of<CategoryProvider>(context, listen: false).fetchCategories();
  }

  void _applyFilters() {
    final filters = <String, dynamic>{};
    if (_selectedCategoryIds.isNotEmpty) {
      filters['category__in'] = _selectedCategoryIds.join(',');
    }
    if (_city.isNotEmpty) {
      filters['city_name__icontains'] = _city;
    }
    if (_searchTerm.isNotEmpty) {
      filters['search'] = _searchTerm;
    }
    filters['ordering'] = _ordering;

    Navigator.of(context).pop();
    Provider.of<IncidentProvider>(context, listen: false)
      .fetchIncidentList(isRefresh: true, newFilters: filters);
  }

  void _resetFilters() {
    Navigator.of(context).pop();
    Provider.of<IncidentProvider>(context, listen: false)
      .fetchIncidentList(isRefresh: true, newFilters: {});
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filter Incidents'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Categories', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Consumer<CategoryProvider>(
              builder: (context, categoryProvider, child) {
                if (categoryProvider.isLoading) return const Center(child: LinearProgressIndicator());
                return Wrap(
                  spacing: 6.0,
                  runSpacing: 6.0,
                  children: categoryProvider.categories.map((category) {
                    final isSelected = _selectedCategoryIds.contains(category.id);
                    return FilterChip(
                      label: Text(category.name),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedCategoryIds.add(category.id);
                          } else {
                            _selectedCategoryIds.remove(category.id);
                          }
                        });
                      },
                      checkmarkColor: Theme.of(context).primaryColor,
                      selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(labelText: 'City Name', border: OutlineInputBorder()),
              onChanged: (value) => _city = value.trim(),
            ),
             const SizedBox(height: 16),
             TextFormField(
              decoration: const InputDecoration(labelText: 'Keyword Search', border: OutlineInputBorder()),
              onChanged: (value) => _searchTerm = value.trim(),
            ),
             const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _ordering,
              decoration: const InputDecoration(labelText: 'Sort By', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: '-incident_date', child: Text('Newest First')),
                DropdownMenuItem(value: 'incident_date', child: Text('Oldest First')),
                DropdownMenuItem(value: '-upvotes', child: Text('Most Upvoted')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _ordering = value);
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _resetFilters,
          child: const Text('Reset'),
        ),
        ElevatedButton(
          onPressed: _applyFilters,
          child: const Text('Apply Filters'),
        ),
      ],
    );
  }
}
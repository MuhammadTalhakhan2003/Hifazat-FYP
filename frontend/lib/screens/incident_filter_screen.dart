// Screen to filter incidents by category, date, etc.
import 'package:flutter/material.dart';
// Placeholder screen for filtering functionality.
// This screen would collect filter data and pass it back to the home screen.

class IncidentFilterScreen extends StatefulWidget {
  const IncidentFilterScreen({super.key});

  @override
  State<IncidentFilterScreen> createState() => _IncidentFilterScreenState();
}

class _IncidentFilterScreenState extends State<IncidentFilterScreen> {
  // Add state for filters: categories, date range, etc.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Filter Incidents'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Example: Category filter
            // You would fetch categories and display them in a multi-select list
            const Text('Filter by Category', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            // Placeholder for category selection
            const ListTile(
              title: Text('Theft'),
              leading: Checkbox(value: false, onChanged: null),
            ),
             const ListTile(
              title: Text('Vandalism'),
              leading: Checkbox(value: true, onChanged: null),
            ),

            const SizedBox(height: 24),

            // Example: Date range filter
            const Text('Filter by Date', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {},
                    child: const Text('Start Date'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {},
                    child: const Text('End Date'),
                  ),
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Apply filters logic:
                  // 1. Collect filter values.
                  // 2. Pop the screen and pass the filter map as a result.
                  // 3. The HomeScreen will receive this result and re-fetch data.
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Apply Filters'),
              ),
            ),
             const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  // Reset filters logic
                },
                child: const Text('Reset Filters'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
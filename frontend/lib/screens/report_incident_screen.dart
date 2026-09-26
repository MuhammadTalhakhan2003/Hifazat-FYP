import 'package:flutter/material.dart';
import 'package:hifazat_app/api/models/category.dart';
import 'package:hifazat_app/api/models/incident.dart';
import 'package:hifazat_app/providers/category_provider.dart';
import 'package:hifazat_app/providers/incident_provider.dart';
import 'package:hifazat_app/widgets/form_fields.dart';
import 'package:hifazat_app/widgets/loading_indicator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

class ReportIncidentScreen extends StatefulWidget {
  const ReportIncidentScreen({super.key});

  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _cityController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();

  Category? _selectedCategory;
  DateTime _selectedDateTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    Provider.of<CategoryProvider>(context, listen: false).fetchCategories();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final LatLng? location = ModalRoute.of(context)?.settings.arguments as LatLng?;
    if (location != null) {
      _latController.text = location.latitude.toStringAsFixed(6);
      _lngController.text = location.longitude.toStringAsFixed(6);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _cityController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDateTime = DateTime(
          picked.year, picked.month, picked.day,
          _selectedDateTime.hour, _selectedDateTime.minute,
        );
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );
    if (picked != null) {
      setState(() {
        _selectedDateTime = DateTime(
          _selectedDateTime.year, _selectedDateTime.month, _selectedDateTime.day,
          picked.hour, picked.minute,
        );
      });
    }
  }

  Future<void> _submitReport() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedCategory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a category')),
        );
        return;
      }

      final request = IncidentCreateRequest(
        title: _titleController.text,
        description: _descriptionController.text,
        category: _selectedCategory!.id,
        latitude: double.parse(_latController.text),
        longitude: double.parse(_lngController.text),
        incidentDate: _selectedDateTime.toUtc().toIso8601String(),
        cityName: _cityController.text,
      );

      final incidentProvider = Provider.of<IncidentProvider>(context, listen: false);
      final success = await incidentProvider.createIncident(request);
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incident reported successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(incidentProvider.errorMessage ?? 'Failed to report incident.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report an Incident')),
      body: Consumer<IncidentProvider>(
        builder: (context, incidentProvider, child) {
          if (incidentProvider.isLoading && _titleController.text.isNotEmpty) {
            return const LoadingIndicator();
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomTextFormField(controller: _titleController, labelText: 'Title', validator: (v) => v!.isEmpty ? 'Required' : null),
                  const SizedBox(height: 16),
                  CustomTextFormField(controller: _descriptionController, labelText: 'Description', maxLines: 4, validator: (v) => v!.isEmpty ? 'Required' : null),
                  const SizedBox(height: 16),
                  Consumer<CategoryProvider>(
                    builder: (context, categoryProvider, child) {
                      if (categoryProvider.isLoading) return const Center(child: Text('Loading categories...'));
                      return DropdownButtonFormField<Category>(
                        value: _selectedCategory,
                        hint: const Text('Select Category'),
                        items: categoryProvider.categories.map((Category category) {
                          return DropdownMenuItem<Category>(value: category, child: Text(category.name));
                        }).toList(),
                        onChanged: (Category? newValue) => setState(() => _selectedCategory = newValue),
                        validator: (v) => v == null ? 'Required' : null,
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: CustomTextFormField(controller: _latController, labelText: 'Latitude', keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Required' : null)),
                      const SizedBox(width: 16),
                      Expanded(child: CustomTextFormField(controller: _lngController, labelText: 'Longitude', keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Required' : null)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  CustomTextFormField(controller: _cityController, labelText: 'City Name', validator: (v) => v!.isEmpty ? 'Required' : null),
                  const SizedBox(height: 24),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.calendar_today),
                          title: const Text('Incident Date'),
                          subtitle: Text(DateFormat.yMMMd().format(_selectedDateTime)),
                          onTap: () => _selectDate(context),
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        ListTile(
                          leading: const Icon(Icons.access_time),
                          title: const Text('Incident Time'),
                          subtitle: Text(DateFormat.jm().format(_selectedDateTime)),
                          onTap: () => _selectTime(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitReport,
                      child: const Text('Submit Report'),
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
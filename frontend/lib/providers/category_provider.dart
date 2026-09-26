// Provider for category-related state and data
import 'package:flutter/material.dart';
import 'package:hifazat_app/api/models/category.dart';
import 'package:hifazat_app/api/services/category_service.dart';

class CategoryProvider with ChangeNotifier {
  final CategoryService _categoryService = CategoryService();

  List<Category> _categories = [];
  List<Category> get categories => _categories;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> fetchCategories() async {
    if (_categories.isNotEmpty) return; // Avoid re-fetching if already loaded

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _categories = await _categoryService.getCategories();
    } catch (e) {
      _errorMessage = "Failed to load categories.";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
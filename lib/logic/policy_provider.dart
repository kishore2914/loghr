import 'package:flutter/material.dart';
import 'package:loghr_mobile/data/models/policy.dart';
import 'package:loghr_mobile/data/services/policy_service.dart';

class PolicyProvider extends ChangeNotifier {
  final PolicyService _service;
  
  List<Policy> _policies = [];
  bool _isLoading = false;
  String _searchQuery = '';
  
  PolicyProvider() : _service = PolicyService();
  
  List<Policy> get policies => _searchQuery.isEmpty 
      ? _policies 
      : _policies.where((p) => 
          p.title.toLowerCase().contains(_searchQuery.toLowerCase()) || 
          p.content.toLowerCase().contains(_searchQuery.toLowerCase())
        ).toList();
        
  bool get isLoading => _isLoading;
  int get totalPolicies => _policies.length;

  Future<void> fetchPolicies(String organizationId) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      _policies = await _service.getPolicies(organizationId);
    } catch (e) {
      print('Provider error fetching policies: $e');
      _policies = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void searchPolicies(String query) {
    _searchQuery = query;
    notifyListeners();
  }
  
  void clearSearch() {
    _searchQuery = '';
    notifyListeners();
  }
}

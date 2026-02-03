import 'package:flutter/material.dart';
import 'package:loghr_mobile/data/models/loyalty_card.dart';
import 'package:loghr_mobile/data/services/loyalty_service.dart';

class LoyaltyProvider extends ChangeNotifier {
  final LoyaltyService _loyaltyService = LoyaltyService();
  LoyaltyCard? _loyaltyCard;
  List<LoyaltyTransaction> _transactions = [];
  bool _isLoading = false;

  LoyaltyCard? get loyaltyCard => _loyaltyCard;
  List<LoyaltyTransaction> get transactions => _transactions;
  bool get isLoading => _isLoading;

  Future<void> loadLoyaltyCard(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _loyaltyCard = await _loyaltyService.getLoyaltyCard(userId);
      if (_loyaltyCard != null) {
        _transactions = await _loyaltyService.getTransactions(_loyaltyCard!.employeeId);
      }
    } catch (e) {
      print('Error loading loyalty card in provider: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshLoyaltyCard(String userId) async {
    try {
      _loyaltyCard = await _loyaltyService.getLoyaltyCard(userId);
      if (_loyaltyCard != null) {
        _transactions = await _loyaltyService.getTransactions(_loyaltyCard!.employeeId);
      }
      notifyListeners();
    } catch (e) {
      print('Error refreshing loyalty card: $e');
    }
  }
}

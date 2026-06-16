import 'package:loghr_mobile/config/api_client.dart';
import 'package:loghr_mobile/data/models/loyalty_card.dart';

class LoyaltyService {
  Future<LoyaltyCard?> getLoyaltyCard(String userId) async {
    try {
      final response = await api.get('/misc/loyalty/card');
      if (response == null) return null;

      final data = response as Map<String, dynamic>;
      final cardData = data['card'] as Map<String, dynamic>? ?? {};
      final employeeInfo = data['employee'] as Map<String, dynamic>? ?? {};
      final orgData = data['org'] as Map<String, dynamic>? ?? {};

      return LoyaltyCard.fromJson(cardData, employeeInfo, orgData);
    } catch (e) {
      print('Error fetching loyalty card: $e');
      return null;
    }
  }

  Future<void> awardPoints({
    required String employeeId,
    required int points,
    required String type,
    String? description,
    String? referenceId,
  }) async {
    try {
      await api.post('/misc/loyalty/award', {
        'employeeId': employeeId,
        'points': points,
        'type': type,
        'description': description,
        'referenceId': referenceId,
      });
    } catch (e) {
      print('Error awarding points: $e');
    }
  }

  Future<List<LoyaltyTransaction>> getTransactions(String employeeId) async {
    try {
      final response = await api.get('/misc/loyalty/transactions');
      if (response == null) return [];

      final list = response as List;
      return list.map((json) => LoyaltyTransaction.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching transactions: $e');
      return [];
    }
  }
}

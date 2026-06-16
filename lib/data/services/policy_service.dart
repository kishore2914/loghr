import 'package:loghr_mobile/config/api_client.dart';
import 'package:loghr_mobile/data/models/policy.dart';

class PolicyService {
  Future<List<Policy>> getPolicies(String organizationId) async {
    try {
      final response = await api.get('/misc/policies');
      if (response == null) return [];
      
      final list = response as List;
      return list.map((e) => Policy.fromJson(e)).toList();
    } catch (e) {
      print('PolicyService: Error fetching policies: $e');
      return [];
    }
  }

  Future<List<Policy>> searchPolicies(String organizationId, String query) async {
    try {
      final all = await getPolicies(organizationId);
      if (query.isEmpty) return all;
      
      final q = query.toLowerCase();
      return all.where((p) => 
        p.title.toLowerCase().contains(q) || 
        p.content.toLowerCase().contains(q)
      ).toList();
    } catch (e) {
      print('Error searching policies: $e');
      return [];
    }
  }
}

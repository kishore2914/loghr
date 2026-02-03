import 'package:loghr_mobile/config/supabase_config.dart';
import 'package:loghr_mobile/data/models/policy.dart';

class PolicyService {
  Future<List<Policy>> getPolicies(String organizationId) async {
    print('PolicyService: Fetching policies for org: $organizationId');
    try {
      // 1. Try fetching from specific policies table
      print('PolicyService: Attempting "policies" table');
      final response = await supabase
          .from('policies')
          .select()
          .eq('organization_id', organizationId)
          // Schema provided doesn't show is_active, so removing that filter to be safe
          .order('updated_at', ascending: false);
      
      final policies = (response as List).map((e) => Policy.fromJson(e)).toList();
      print('PolicyService: Found ${policies.length} in policies table');
      if (policies.isNotEmpty) return policies;

      // 2. Fallback: Try fetching from 'announcements' or 'posts' with category 'policy'
      print('PolicyService: Fallback - checking "announcements" for policies');
      final fallbackResponse = await supabase
          .from('announcements')
          .select()
          .eq('organization_id', organizationId)
          .ilike('category', '%policy%') // Case insensitive check
          .order('created_at', ascending: false);

      final fallbackPolicies = (fallbackResponse as List).map((e) {
          // Map announcement to Policy
          return Policy(
            id: e['id'],
            organizationId: e['organization_id'],
            title: e['title'],
            content: e['content'],
            lastUpdated: e['updated_at'] != null ? DateTime.parse(e['updated_at']) : DateTime.parse(e['created_at']),
            category: e['category'] ?? 'Policy',
            isActive: true,
          );
      }).toList();
      
      print('PolicyService: Found ${fallbackPolicies.length} in announcements');
      return fallbackPolicies;

    } catch (e) {
      print('PolicyService: Error fetching policies: $e');
      
      // 3. Last resort: Try very loose search if above failed due to column missing
      try {
         final everything = await supabase
          .from('announcements')
          .select()
          .eq('organization_id', organizationId)
          .order('created_at', ascending: false);

         final filtered = (everything as List).where((e) {
           final cat = (e['category'] as String? ?? '').toLowerCase();
           final title = (e['title'] as String? ?? '').toLowerCase();
           return cat.contains('policy') || title.contains('policy');
         }).map((e) => Policy(
            id: e['id'],
            organizationId: e['organization_id'],
            title: e['title'],
            content: e['content'],
            lastUpdated: e['updated_at'] != null ? DateTime.parse(e['updated_at']) : DateTime.parse(e['created_at']),
            category: e['category'] ?? 'Policy',
            isActive: true,
         )).toList();
         
         print('PolicyService: Found ${filtered.length} via loose filtering');
         return filtered;
      } catch (e2) {
        print('PolicyService: Fatal error: $e2');
        return [];
      }
    }
  }

  Future<List<Policy>> searchPolicies(String organizationId, String query) async {
    try {
      // 1. Try policies table
      final response = await supabase
          .from('policies')
          .select()
          .eq('organization_id', organizationId)
          .or('heading.ilike.%$query%,description.ilike.%$query%')
          .order('updated_at', ascending: false);

      final policies = (response as List).map((e) => Policy.fromJson(e)).toList();
      if (policies.isNotEmpty) return policies;

      // 2. Fallback to announcements
      final fallbackResponse = await supabase
          .from('announcements')
          .select()
          .eq('organization_id', organizationId)
          .ilike('category', '%policy%')
          .or('title.ilike.%$query%,content.ilike.%$query%')
          .order('created_at', ascending: false);

      return (fallbackResponse as List).map((e) => Policy(
            id: e['id'],
            organizationId: e['organization_id'],
            title: e['title'],
            content: e['content'],
            lastUpdated: e['updated_at'] != null ? DateTime.parse(e['updated_at']) : DateTime.parse(e['created_at']),
            category: e['category'] ?? 'Policy',
            isActive: true,
      )).toList();

    } catch (e) {
      print('Error searching policies: $e');
      return [];
    }
  }
}

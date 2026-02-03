import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:loghr_mobile/data/models/announcement.dart';

class AnnouncementService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Announcement>> getAnnouncements({String? organizationId}) async {
    try {
      print('AnnouncementService: Fetching announcements for organization: $organizationId');
      
      var query = _supabase.from('announcements').select();
      
      if (organizationId != null && organizationId.isNotEmpty) {
        // Try to filter by organization_id if it exists
        try {
          query = query.eq('organization_id', organizationId);
        } catch (e) {
          print('AnnouncementService: Warning - organization_id column might not exist: $e');
        }
      }

      // Filter for active announcements if column exists
      try {
        query = query.eq('is_active', true);
      } catch (e) {
        // Ignore if column doesn't exist
      }
      
      final response = await query.order('created_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      print('AnnouncementService: Fetched ${data.length} announcements');
      return data.map((json) => Announcement.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching announcements: $e');
      
      // Fallback: try fetching all if filtering failed
      try {
        print('AnnouncementService: Trying fallback - fetching all announcements');
        final response = await _supabase
            .from('announcements')
            .select()
            .order('created_at', ascending: false);
        final List<dynamic> data = response as List<dynamic>;
        return data.map((json) => Announcement.fromJson(json)).toList();
      } catch (e2) {
        print('Error in fallback fetching: $e2');
        return [];
      }
    }
  }
}

import 'package:loghr_mobile/data/models/announcement.dart';
import 'package:loghr_mobile/config/api_client.dart';

class AnnouncementService {
  Future<List<Announcement>> getAnnouncements({String? organizationId}) async {
    try {
      print('AnnouncementService: Fetching announcements via custom API');
      final response = await api.get('/announcements');
      if (response == null) return [];
      
      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => Announcement.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching announcements: $e');
      return [];
    }
  }
}

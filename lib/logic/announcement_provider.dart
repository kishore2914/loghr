import 'package:flutter/foundation.dart';
import 'package:loghr_mobile/data/models/announcement.dart';
import 'package:loghr_mobile/data/services/announcement_service.dart';

class AnnouncementProvider with ChangeNotifier {
  final AnnouncementService _announcementService;
  
  List<Announcement> _announcements = [];
  bool _isLoading = false;
  String? _error;

  AnnouncementProvider(this._announcementService);

  List<Announcement> get announcements => _announcements;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadAnnouncements({String? organizationId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners(); // Notify start of loading

    try {
      _announcements = await _announcementService.getAnnouncements(organizationId: organizationId);
    } catch (e) {
      _error = e.toString();
      _announcements = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Helper getters for UI
  int get unreadCount => _announcements.where((a) => !a.isRead).length; // Logic to be refined if isRead is tracked
  
  // Local filtering helper
  List<Announcement> filterAnnouncements({
    String query = '',
    String category = 'All Categories',
    String priority = 'All Priorities',
  }) {
    var filtered = _announcements;

    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      filtered = filtered.where((a) => 
        a.title.toLowerCase().contains(q) || 
        a.content.toLowerCase().contains(q)
      ).toList();
    }

    if (category != 'All Categories') {
      filtered = filtered.where((a) => a.category == category).toList();
    }

    if (priority != 'All Priorities') {
      filtered = filtered.where((a) => a.priority == priority).toList();
    }

    return filtered;
  }
}

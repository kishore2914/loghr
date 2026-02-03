import 'package:intl/intl.dart';

class Helpers {
  static String formatTime(DateTime dateTime) {
    // Convert to local time if it's in UTC
    final localTime = dateTime.isUtc ? dateTime.toLocal() : dateTime;
    return DateFormat('HH:mm:ss').format(localTime);
  }
  
  static String formatTimeShort(DateTime dateTime) {
    // Convert to local time if it's in UTC
    final localTime = dateTime.isUtc ? dateTime.toLocal() : dateTime;
    return DateFormat('HH:mm').format(localTime);
  }

  static String formatDate(DateTime dateTime) {
    return DateFormat('MMM dd, yyyy').format(dateTime);
  }

  static String formatDateTime(DateTime dateTime) {
    return DateFormat('MMM dd, yyyy HH:mm').format(dateTime);
  }

  static String generateEmployeeCode(String name) {
    if (name.isEmpty) return 'EMP-${DateFormat('yyyyMMdd').format(DateTime.now())}-000';
    
    final today = DateFormat('yyyyMMdd').format(DateTime.now());
    // Generate a simple 3-digit hash based on the name
    int hash = 0;
    for (int i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }
    final code = (hash.abs() % 1000).toString().padLeft(3, '0');
    
    return 'EMP-$today-$code';
  }
}



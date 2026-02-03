import 'package:flutter/material.dart';
import 'package:loghr_mobile/config/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialize Supabase
    await SupabaseConfig.initialize();
    
    print('=== Checking user_profiles table structure ===');
    
    // Try to fetch all records to see the structure
    final data = await supabase
        .from('user_profiles')
        .select()
        .limit(5);
    
    print('Sample data from user_profiles:');
    print(data);
    
    if (data.isNotEmpty) {
      print('\nColumns in user_profiles table:');
      print(data[0].keys.toList());
    } else {
      print('No data in user_profiles table');
    }
    
  } catch (e) {
    print('Error: $e');
  }
}

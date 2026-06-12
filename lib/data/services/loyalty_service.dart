import 'package:loghr_mobile/config/supabase_config.dart';
import 'package:loghr_mobile/data/models/loyalty_card.dart';

class LoyaltyService {
  Future<LoyaltyCard?> getLoyaltyCard(String userId) async {
    try {
      // 1. Get profile data robustly
      final profile = await supabase
          .from('user_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      String? employeeId = profile?['employee_id'] as String?;
      String? organizationId = profile?['organization_id'] as String?;

      if (employeeId == null) {
        final empRecord = await supabase
            .from('employees')
            .select('id, organization_id')
            .eq('user_id', userId)
            .maybeSingle();
        employeeId = empRecord?['id'] as String?;
        organizationId ??= empRecord?['organization_id'] as String?;
      }

      if (employeeId == null) {
        print('LoyaltyService: No employee ID found for user $userId');
        return null;
      }

      // 2. Get Loyalty Card Data (Auto-create if missing)
      var cardData = await supabase
          .from('loyalty_cards')
          .select('*')
          .eq('employee_id', employeeId)
          .maybeSingle();

      if (cardData == null && organizationId != null) {
        print('LoyaltyService: Card not found, creating for employee $employeeId');
        final newCard = {
          'organization_id': organizationId,
          'employee_id': employeeId,
          'card_number': _generate16DigitCard(),
          'points_earned': 0,
        };
        
        try {
          await supabase.from('loyalty_cards').insert(newCard);
          cardData = await supabase
              .from('loyalty_cards')
              .select('*')
              .eq('employee_id', employeeId)
              .maybeSingle();
        } catch (e) {
          print('LoyaltyService: Error auto-creating card: $e');
        }
      }

      if (cardData == null) {
        print('LoyaltyService: Card still null after auto-creation attempt');
        return null;
      }

      // 3. Get Employee details for display
      final empData = await supabase
          .from('employees')
          .select()
          .eq('id', employeeId)
          .maybeSingle();

      if (empData == null) {
        print('LoyaltyService: Employee record not found in employees table for $employeeId');
        return null;
      }

      // 4. Get Organization Data
      Map<String, dynamic>? orgData;
      if (organizationId != null) {
        orgData = await supabase
            .from('organizations')
            .select('name, logo_url')
            .eq('id', organizationId)
            .maybeSingle();
      }

      // 5. Robustly resolve name, designation, and role
      final String employeeName = empData['full_name'] as String? ?? 
                                 empData['name'] as String? ??
                                 _constructName(empData) ??
                                 profile?['full_name'] as String? ??
                                 'Employee';

      // Robust Designation Resolution
      String? resolvedDesignation = profile?['designation'] as String? ?? 
                                   profile?['job_title'] as String? ??
                                   empData['designation'] as String? ?? 
                                   empData['position'] as String? ??
                                   empData['job_title'] as String?;

      if (resolvedDesignation == null || resolvedDesignation.isEmpty || resolvedDesignation.trim().isEmpty) {
        final designationId = (empData['designation_id'] ?? profile?['designation_id']) as String?;
        if (designationId != null && designationId.isNotEmpty) {
          try {
            final designationRow = await supabase
                .from('designations')
                .select()
                .eq('id', designationId)
                .maybeSingle();
            
            if (designationRow != null) {
              resolvedDesignation = designationRow['name'] as String? ??
                                   designationRow['title'] as String? ??
                                   designationRow['designation'] as String? ??
                                   designationRow['designation_name'] as String? ??
                                   designationRow['position'] as String? ??
                                   designationRow['job_title'] as String?;
            }
          } catch (e) {
             print('LoyaltyService: Error fetching from designations table: $e');
          }
        }
      }

      final String designation = resolvedDesignation ?? 'Team Member';

      final String role = profile?['role'] as String? ?? 
                          empData['role'] as String? ?? 
                          designation;

      final employeeInfo = {
        'id': employeeId,
        'full_name': employeeName,
        'designation': designation,
        'role': role,
      };

      return LoyaltyCard.fromJson(cardData, employeeInfo, orgData);
    } catch (e) {
      print('Error fetching loyalty card: $e');
      return null;
    }
  }

  String? _constructName(Map<String, dynamic> data) {
    final firstName = data['first_name'] as String?;
    final lastName = data['last_name'] as String?;
    if (firstName != null && firstName.trim().isNotEmpty) {
      String name = firstName.trim();
      if (lastName != null && lastName.trim().isNotEmpty) {
        name = '$name ${lastName.trim()}';
      }
      return name;
    }
    return null;
  }

  Future<void> awardPoints({
    required String employeeId,
    required int points,
    required String type,
    String? description,
    String? referenceId,
  }) async {
    try {
      final empData = await supabase
          .from('employees')
          .select('organization_id')
          .eq('id', employeeId)
          .maybeSingle();
      
      final organizationId = empData?['organization_id'] as String?;
      if (organizationId == null) return;

      // 1. Log transaction
      await supabase.from('loyalty_point_transactions').insert({
        'organization_id': organizationId,
        'employee_id': employeeId,
        'points': points,
        'transaction_type': type,
        'reference_id': referenceId,
        'description': description,
      });

      // 2. Update card points
      final currentCard = await supabase
          .from('loyalty_cards')
          .select('points_earned')
          .eq('employee_id', employeeId)
          .maybeSingle();
      
      if (currentCard != null) {
        final newTotal = (currentCard['points_earned'] as int? ?? 0) + points;
        await supabase
            .from('loyalty_cards')
            .update({'points_earned': newTotal})
            .eq('employee_id', employeeId);
      } else {
        // If card doesn't exist, create it
        await supabase.from('loyalty_cards').insert({
            'organization_id': organizationId,
            'employee_id': employeeId,
            'card_number': _generate16DigitCard(),
            'points_earned': points,
        });
      }
    } catch (e) {
      print('Error awarding points: $e');
    }
  }

  String _generate16DigitCard() {
    // Generate a random 16 digit number string
    final rand = DateTime.now().microsecondsSinceEpoch.toString();
    if (rand.length >= 16) return rand.substring(rand.length - 16);
    return rand.padRight(16, '0');
  }

  Future<List<LoyaltyTransaction>> getTransactions(String employeeId) async {
    try {
      final data = await supabase
          .from('loyalty_point_transactions')
          .select('*')
          .eq('employee_id', employeeId)
          .order('created_at', ascending: false);
      
      return (data as List).map((json) => LoyaltyTransaction.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching transactions: $e');
      return [];
    }
  }
}

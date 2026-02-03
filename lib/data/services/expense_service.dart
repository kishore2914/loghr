import 'package:loghr_mobile/config/supabase_config.dart';
import 'package:loghr_mobile/data/models/expense.dart';
import 'package:loghr_mobile/data/services/profile_service.dart';

/// ExpenseService - Fetches expense data from Supabase
/// 
/// IMPORTANT: Since the website works and shows correct amounts, the website
/// must be using a database view or RPC function that decrypts amount_encrypted.
/// This service tries to find and use the same approach.
/// 
/// To find what the website uses:
/// 1. Open website → F12 → Network tab → Look for Supabase API calls
/// 2. Check Supabase Dashboard → Database → Views (look for expense-related views)
/// 3. Check Supabase Dashboard → Database → Functions (look for expense-related functions)
class ExpenseService {
  final ProfileService _profileService = ProfileService();
  
  /// Tries to find and use the same database view/function that the website uses
  /// Returns the data if found, null otherwise
  Future<List<dynamic>?> _tryWebsiteApproach(String employeeId) async {
    print('ExpenseService: 🔍 Searching for database views/functions...');
    
    // Try to discover available views using information_schema (if accessible)
    // Note: This might not work with anon key, but worth trying
    try {
      print('ExpenseService: Attempting to discover expense-related views...');
      // Try querying information_schema through RPC if a function exists
      final viewList = await supabase.rpc('list_expense_views').maybeSingle();
      if (viewList != null) {
        print('ExpenseService: Discovered views: $viewList');
      }
    } catch (e) {
      // Not available, that's okay - we'll try common names
    }
    
    // Common patterns websites use for decrypted expense views
    final websitePatterns = [
      // Direct views (most common)
      'expenses_with_amounts',
      'expenses_decrypted', 
      'v_expenses',
      'expenses_view',
      'user_expenses',
      'employee_expenses',
      'expenses_with_decrypted_amounts',
      'expenses_public',
      'public_expenses',
      
      // RPC functions
      'get_user_expenses',
      'get_employee_expenses',
      'fetch_expenses_with_amounts',
      'get_expenses_decrypted',
      'get_expenses_with_amounts',
    ];
    
    for (final pattern in websitePatterns) {
      try {
        // Try as view/table first
        try {
          final viewData = await supabase
              .from(pattern)
              .select('*')
              .eq('employee_id', employeeId)
              .order('created_at', ascending: false)
              .limit(10);
          
          if (viewData.isNotEmpty) {
            final first = viewData[0] as Map<String, dynamic>;
            final amount = first['amount'];
            print('ExpenseService: View "$pattern" - amount: $amount (type: ${amount.runtimeType})');
            
            if (amount != null && amount != 0) {
              print('ExpenseService: ✅✅✅ FOUND WORKING VIEW "$pattern" (same as website!) ✅✅✅');
              // Get all records, not just 10
              final allData = await supabase
                  .from(pattern)
                  .select('*')
                  .eq('employee_id', employeeId)
                  .order('created_at', ascending: false);
              return allData;
            }
          }
        } catch (e) {
          // Not a view, try as RPC
          try {
            final rpcData = await supabase.rpc(pattern, params: {
              'employee_id': employeeId,
              'p_employee_id': employeeId,
              'user_id': employeeId,
            });
            
            if (rpcData != null && (rpcData as List).isNotEmpty) {
              final first = (rpcData as List)[0] as Map<String, dynamic>;
              final amount = first['amount'];
              print('ExpenseService: RPC "$pattern" - amount: $amount (type: ${amount.runtimeType})');
              
              if (amount != null && amount != 0) {
                print('ExpenseService: ✅✅✅ FOUND WORKING RPC "$pattern" (same as website!) ✅✅✅');
                return rpcData;
              }
            }
          } catch (e2) {
            continue;
          }
        }
      } catch (e) {
        continue;
      }
    }
    
    print('ExpenseService: ⚠️ Could not find website approach automatically');
    return null;
  }
  
  /// Attempts to decrypt an encrypted amount value
  /// Returns the decrypted amount, or null if decryption fails
  Future<double?> _decryptAmount(String encryptedValue) async {
    if (encryptedValue.isEmpty) {
      print('ExpenseService: Encrypted value is empty');
      return null;
    }
    
    print('ExpenseService: Attempting to decrypt amount (encrypted length: ${encryptedValue.length})');
    
    // Try multiple approaches
    // Approach 1: Supabase RPC function
    try {
      print('ExpenseService: Trying RPC function decrypt_expense_amount...');
      final result = await supabase.rpc('decrypt_expense_amount', params: {
        'encrypted_amount': encryptedValue,
      }).maybeSingle();
      
      if (result != null) {
        final amount = (result as num?)?.toDouble();
        if (amount != null && amount > 0) {
          print('ExpenseService: ✅ RPC decryption successful: $amount');
          return amount;
        }
      }
      print('ExpenseService: RPC function returned null or invalid result');
    } catch (e) {
      print('ExpenseService: RPC decrypt function error: $e');
    }
    
    // Approach 2: Try alternative RPC function names
    final rpcFunctionNames = [
      'decrypt_amount',
      'get_decrypted_amount',
      'expense_decrypt_amount',
    ];
    
    for (final funcName in rpcFunctionNames) {
      try {
        print('ExpenseService: Trying RPC function $funcName...');
        final result = await supabase.rpc(funcName, params: {
          'encrypted_amount': encryptedValue,
        }).maybeSingle();
        
        if (result != null) {
          final amount = (result as num?)?.toDouble();
          if (amount != null && amount > 0) {
            print('ExpenseService: ✅ Alternative RPC decryption successful: $amount');
            return amount;
          }
        }
      } catch (e) {
        // Continue to next function
        continue;
      }
    }
    
    // If RPC doesn't work, the decryption needs to be handled server-side
    // or we need the encryption key to decrypt client-side
    print('ExpenseService: ⚠️ All decryption attempts failed. Amount remains encrypted.');
    print('ExpenseService: 💡 You need to create a Supabase RPC function to decrypt amounts');
    print('ExpenseService: 💡 OR use a database view that includes decrypted amounts');
    return null;
  }

  Future<List<ExpenseClaim>> getUserCharges(String userId) async {
    try {
      // Similar to getUserExpenses but from 'charges' table
      String? employeeId;
      try {
        final profileData = await supabase
            .from('user_profiles')
            .select('employee_id')
            .eq('user_id', userId)
            .maybeSingle();
        employeeId = profileData?['employee_id'] as String?;
      } catch (_) {}

      List<dynamic> data = [];
      try {
        if (employeeId != null && employeeId.isNotEmpty) {
          data = await supabase
              .from('employee_charges')
              .select('*')
              .eq('employee_id', employeeId)
              .order('created_at', ascending: false);
        } else {
          // Try with user_id if it exists, otherwise try without it
          try {
            data = await supabase
                .from('employee_charges')
                .select('*')
                .eq('user_id', userId)
                .order('created_at', ascending: false);
          } catch (e) {
            // If user_id doesn't exist, try fetching all and filter client-side
            print('ExpenseService: user_id column may not exist, fetching all charges');
            final allCharges = await supabase
                .from('employee_charges')
                .select('*')
                .order('created_at', ascending: false);
            // Note: Without user_id, we can't filter by user, so return empty or all
            data = [];
          }
        }
        
        // Log first charge to debug amount issue
        if (data.isNotEmpty) {
          final firstCharge = data[0] as Map<String, dynamic>;
          print('ExpenseService: First charge amount raw value: ${firstCharge['amount']} (type: ${firstCharge['amount']?.runtimeType})');
        }
      } catch (e) {
        print('ExpenseService: Error fetching charges: $e');
        data = [];
      }

      if (data.isEmpty) return [];

      // Batch fetch category names from expense_categories table
      final categoryIds = (data as List)
          .map((charge) => charge['category_id'] as String?)
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      
      final categoryNameMap = <String, String>{};
      if (categoryIds.isNotEmpty) {
        try {
          print('ExpenseService: Batch fetching category names for charges: ${categoryIds.length} categories');
          final categoriesData = await supabase
              .from('expense_categories')
              .select('id, name')
              .inFilter('id', categoryIds);
          
          for (var catData in categoriesData) {
            final catId = catData['id'] as String?;
            final catName = catData['name'] as String?;
            if (catId != null && catName != null && catName.isNotEmpty) {
              categoryNameMap[catId] = catName.trim();
              print('ExpenseService: Found category name for charge: $catName for $catId');
            }
          }
        } catch (e) {
          print('ExpenseService: Error batch fetching category names for charges: $e');
        }
      }

      final charges = await Future.wait((data as List).map((json) async {
        final map = Map<String, dynamic>.from(json as Map<String, dynamic>);
        // charges table may use similar fields, map to ExpenseClaim shape
        // fallbacks
        map['expense_number'] = map['charge_number'] ?? map['id'];
        map['expense_date'] = map['charge_date'] ?? map['created_at'];
        map['merchant_name'] = map['merchant_name'] ?? map['title'] ?? 'N/A';
        map['amount'] = map['amount'] ?? 0;
        map['status'] = map['status'] ?? 'pending';
        map['currency'] = map['currency'] ?? 'INR';
        
        // Attach category name from expense_categories table
        final chargeCategoryId = map['category_id'] as String?;
        if (chargeCategoryId != null && categoryNameMap.containsKey(chargeCategoryId)) {
          map['expense_categories'] = {
            'id': chargeCategoryId,
            'name': categoryNameMap[chargeCategoryId],
          };
          print('ExpenseService: Attached category name to charge: ${categoryNameMap[chargeCategoryId]}');
        } else if (chargeCategoryId != null) {
          // Try to fetch individually if not in batch map
          try {
            final catData = await supabase
                .from('expense_categories')
                .select('id, name')
                .eq('id', chargeCategoryId)
                .maybeSingle();
            
            if (catData != null) {
              final catName = catData['name'] as String?;
              if (catName != null && catName.isNotEmpty) {
                map['expense_categories'] = {
                  'id': chargeCategoryId,
                  'name': catName,
                };
                categoryNameMap[chargeCategoryId] = catName; // Cache it
                print('ExpenseService: Fetched category name individually for charge: $catName');
              }
            }
          } catch (e) {
            print('ExpenseService: Error fetching category name individually for charge $chargeCategoryId: $e');
          }
        }
        
        return ExpenseClaim.fromJson(map);
      }));

      return charges;
    } catch (e, st) {
      print('Error fetching user charges: $e');
      print(st);
      return [];
    }
  }

  Future<Map<String, dynamic>> getChargeStats(String userId) async {
    try {
      final charges = await getUserCharges(userId);
      final totalClaims = charges.length;
      final pending = charges.where((e) => e.status == ExpenseStatus.pending || e.status == ExpenseStatus.draft).length;
      final acknowledged = charges.where((e) => e.status == ExpenseStatus.acknowledged).length;
      final settled = charges.where((e) => e.status == ExpenseStatus.settled).length;
      // Calculate total amount with validation
      double totalAmount = 0.0;
      for (var charge in charges) {
        // Validate amount is reasonable before adding
        if (charge.amount > 0 && charge.amount <= 1000000000) {
          totalAmount += charge.amount;
        } else {
          print('ExpenseService.getChargeStats: ⚠ Skipping invalid amount for charge: ${charge.amount}');
        }
      }

      return {
        'total_claims': totalClaims,
        'pending': pending,
        'acknowledged': acknowledged,
        'settled': settled,
        'total_amount': totalAmount,
      };
    } catch (e) {
      print('Error fetching charge stats: $e');
      return {
        'total_claims': 0,
        'pending': 0,
        'approved': 0,
        'rejected': 0,
        'total_amount': 0.0,
      };
    }
  }

  // Get user's expense claims
  Future<List<ExpenseClaim>> getUserExpenses(String userId) async {
    try {
      print('Fetching expenses for user: $userId');
      
      // First, get employee_id from user_profiles
      String? employeeId;
      String? employeeName;
      try {
        final profileData = await supabase
            .from('user_profiles')
            .select('employee_id')
            .eq('user_id', userId)
            .maybeSingle();
        
        if (profileData != null) {
          employeeId = profileData['employee_id'] as String?;
          print('Found employee_id: $employeeId');
          
          // Fetch employee name from employees table
          if (employeeId != null && employeeId.isNotEmpty) {
            try {
              final employeeData = await supabase
                  .from('employees')
                  .select()
                  .eq('id', employeeId)
                  .maybeSingle();
              
              if (employeeData != null) {
                // Try different possible column names for name
                employeeName = employeeData['full_name'] as String? ?? 
                              employeeData['name'] as String? ??
                              employeeData['first_name'] as String? ??
                              employeeData['employee_name'] as String?;
                
                if (employeeName != null && employeeName.isNotEmpty) {
                  print('Found employee name from employees table: $employeeName');
                } else {
                  print('No name found in employees table, will try user_profiles');
                  // Fallback to user_profiles
                  final profileWithName = await supabase
                      .from('user_profiles')
                      .select('full_name')
                      .eq('user_id', userId)
                      .maybeSingle();
                  if (profileWithName != null) {
                    employeeName = profileWithName['full_name'] as String?;
                  }
                }
              }
            } catch (e) {
              print('Error fetching employee name from employees table: $e');
              // Fallback to user_profiles
              final profileWithName = await supabase
                  .from('user_profiles')
                  .select('full_name')
                  .eq('user_id', userId)
                  .maybeSingle();
              if (profileWithName != null) {
                employeeName = profileWithName['full_name'] as String?;
              }
            }
          }
        }
      } catch (e) {
        print('Error fetching user profile for expenses: $e');
      }

      // Fetch by employee_id from expenses table
      List<dynamic> data = [];
      
      if (employeeId != null && employeeId.isNotEmpty) {
        try {
          // Since the website works, it MUST be using a database view, RPC function, or computed column
          // that decrypts amounts. Let's try to find and use the same approach.
          print('\n🌐 ExpenseService: Website works, so there MUST be a view/function that decrypts');
          print('🌐 ExpenseService: Attempting to find the same approach the website uses...\n');
          
          final websiteData = await _tryWebsiteApproach(employeeId);
          
          if (websiteData != null && websiteData.isNotEmpty) {
            data = websiteData;
            print('ExpenseService: ✅ Using the same approach as the website!');
          } else {
            print('ExpenseService: ⚠️ Could not find website approach, trying alternatives...');
            
            // Try common patterns
            final possibleViews = [
              'expenses_with_amounts',
              'expenses_decrypted',
              'v_expenses',
              'expenses_view',
              'user_expenses',
              'employee_expenses',
            ];
            
            bool foundWorkingView = false;
            for (final viewName in possibleViews) {
              try {
                print('ExpenseService: Trying view/table: $viewName...');
                final viewData = await supabase
                    .from(viewName)
                    .select('*')
                    .eq('employee_id', employeeId)
                    .order('created_at', ascending: false)
                    .limit(100);
                
                if (viewData.isNotEmpty) {
                  final firstExpense = viewData[0] as Map<String, dynamic>;
                  final hasAmount = firstExpense['amount'] != null && firstExpense['amount'] != 0;
                  
                  if (hasAmount) {
                    data = viewData;
                    print('ExpenseService: ✅ Found working view "$viewName" with decrypted amounts!');
                    foundWorkingView = true;
                    break;
                  }
                }
              } catch (e) {
                continue;
              }
            }
            
            // Final fallback: direct query (will need decryption)
            if (!foundWorkingView) {
              print('ExpenseService: ⚠️ No working view/function found');
              print('ExpenseService: 💡 IMPORTANT: Your website uses a database view or RPC function');
              print('ExpenseService: 💡 To find it:');
              print('ExpenseService:    1. Open website → F12 → Network tab → Look for Supabase API calls');
              print('ExpenseService:    2. Or check Supabase Dashboard → Database → Views');
              print('ExpenseService:    3. Or run: SELECT * FROM information_schema.views WHERE table_name LIKE \'%expense%\';');
              print('ExpenseService: Using direct query (will attempt decryption)...');
              data = await supabase
                  .from('expenses')
                  .select('*')
                  .eq('employee_id', employeeId)
                  .order('created_at', ascending: false);
              print('ExpenseService: Query completed, got ${data.length} records');
              
              // Log a sample to see what we got
              if (data.isNotEmpty) {
                final sample = data[0] as Map<String, dynamic>;
                print('ExpenseService: Sample expense amount: ${sample['amount']}');
                print('ExpenseService: Sample expense has amount_encrypted: ${sample.containsKey('amount_encrypted')}');
              }
            }
          }
          print('ExpenseService: Found ${data.length} expenses by employee_id: $employeeId');
          
          // Log ALL expenses to debug amount issue - show ALL fields
          // Use very visible markers so logs are easy to find
          print('\n\n🔍🔍🔍 EXPENSE DEBUG: DATABASE RESPONSE 🔍🔍🔍');
          if (data.isNotEmpty) {
            print('Total expenses returned: ${data.length}');
            for (int i = 0; i < data.length; i++) {
              final expense = data[i] as Map<String, dynamic>;
              print('\n--- EXPENSE #${i + 1} ---');
              print('ID: ${expense['id']}');
              print('Expense Number: ${expense['expense_number'] ?? 'N/A'}');
              print('ALL KEYS IN RECORD: ${expense.keys.toList()}');
              print('AMOUNT FIELD VALUE: ${expense['amount']}');
              print('AMOUNT TYPE: ${expense['amount']?.runtimeType}');
              print('AMOUNT IS NULL: ${expense['amount'] == null}');
              
              // Check for any field containing 'amount' or numeric fields
              print('--- Checking all fields ---');
              for (var key in expense.keys) {
                final value = expense[key];
                print('  Field "$key": $value (type: ${value?.runtimeType})');
                if (key.toLowerCase().contains('amount')) {
                  print('    ⚠️  FOUND AMOUNT-RELATED FIELD!');
                }
                if (value is num && value != 0 && value != expense['id']) {
                  print('    ⚠️  FOUND NON-ZERO NUMERIC FIELD!');
                }
              }
              print('FULL EXPENSE DATA: $expense');
            }
          } else {
            print('❌ No expenses found in database');
          }
          print('🔍🔍🔍 END EXPENSE DEBUG 🔍🔍🔍\n\n');
        } catch (e) {
          print('Error fetching by employee_id: $e');
          rethrow;
        }
      }
      
      // If no results, try fetching all and filtering client-side
      if (data.isEmpty) {
        try {
          try {
            data = await supabase
                .from('expenses')
                .select('id, expense_number, employee_id, expense_date, amount, currency, merchant_name, status, category_id, description, created_at, approved_by, approved_at, rejection_reason, reimbursed_at, reimbursement_reference, receipt_url, proof_document_url, reimbursement_method')
                .order('created_at', ascending: false);
          } catch (e) {
            // Fallback to select all if explicit selection fails
            print('ExpenseService: Explicit select failed, using select(*): $e');
            data = await supabase
                .from('expenses')
                .select('*')
                .order('created_at', ascending: false);
          }
          print('Found ${data.length} total expenses, will filter client-side');
          
          // Filter by employee_id client-side
          if (employeeId != null && employeeId.isNotEmpty) {
            data = (data as List).where((expense) {
              final expEmpId = expense['employee_id'] as String?;
              return expEmpId == employeeId;
            }).toList();
            print('Filtered to ${data.length} matching expenses by employee_id');
          }
        } catch (e) {
          print('Error fetching all expenses: $e');
        }
      }

      if (data.isEmpty) {
        print('No expenses found for user');
        return [];
      }

      // Batch fetch category names from expense_categories table
      final categoryIds = (data as List)
          .map((exp) => exp['category_id'] as String?)
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      
      final categoryNameMap = <String, String>{};
      if (categoryIds.isNotEmpty) {
        try {
          print('ExpenseService: Batch fetching category names for ${categoryIds.length} categories');
          final categoriesData = await supabase
              .from('expense_categories')
              .select('id, name')
              .inFilter('id', categoryIds);
          
          for (var catData in categoriesData) {
            final catId = catData['id'] as String?;
            final catName = catData['name'] as String?;
            if (catId != null && catName != null && catName.isNotEmpty) {
              categoryNameMap[catId] = catName.trim();
              print('ExpenseService: Found category name: $catName for $catId');
            }
          }
        } catch (e) {
          print('ExpenseService: Error batch fetching category names: $e');
        }
      }

      // Batch fetch employee names from employees table for all expenses
      final employeeIds = (data as List)
          .map((exp) => exp['employee_id'] as String?)
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      
      // Batch fetch employee names
      final employeeNameMap = <String, String>{};
      if (employeeIds.isNotEmpty) {
        try {
          print('ExpenseService: Batch fetching employee names for ${employeeIds.length} employees');
          final employeesData = await supabase
              .from('employees')
              .select()
              .inFilter('id', employeeIds);
          
          for (var empData in employeesData) {
            final empId = empData['id'] as String?;
            if (empId == null) continue;
            
            final empName = empData['full_name'] as String? ?? 
                          empData['name'] as String? ??
                          empData['first_name'] as String? ??
                          empData['employee_name'] as String?;
            
            if (empName != null && empName.isNotEmpty && empName.trim().isNotEmpty) {
              employeeNameMap[empId] = empName.trim();
              print('ExpenseService: Found employee name from employees table: $empName for $empId');
            }
          }
        } catch (e) {
          print('ExpenseService: Error batch fetching from employees table: $e');
        }
        
        // Fallback: fetch from user_profiles for any missing names
        final missingIds = employeeIds.where((id) => !employeeNameMap.containsKey(id)).toList();
        if (missingIds.isNotEmpty) {
          try {
            final profiles = await supabase
                .from('user_profiles')
                .select('employee_id, full_name')
                .inFilter('employee_id', missingIds);
            
            for (var profile in profiles) {
              final empId = profile['employee_id'] as String?;
              final name = profile['full_name'] as String?;
              if (empId != null && name != null && name.isNotEmpty && !employeeNameMap.containsKey(empId)) {
                employeeNameMap[empId] = name;
              }
            }
          } catch (e) {
            print('ExpenseService: Error fetching from user_profiles: $e');
          }
        }
      }
      
      // Use current user's employee name if available
      if (employeeId != null && employeeName != null && !employeeNameMap.containsKey(employeeId)) {
        employeeNameMap[employeeId] = employeeName;
      }

      // Batch decrypt amounts for all expenses that need it
      print('ExpenseService: Checking ${data.length} expenses for encrypted amounts...');
      final expensesNeedingDecryption = <Map<String, dynamic>>[];
      for (var expense in data) {
        final expenseMap = expense as Map<String, dynamic>;
        if ((expenseMap['amount'] == null || expenseMap['amount'] == 0) && 
            expenseMap.containsKey('amount_encrypted') && 
            expenseMap['amount_encrypted'] != null) {
          expensesNeedingDecryption.add(expenseMap);
        }
      }
      
      print('ExpenseService: Found ${expensesNeedingDecryption.length} expenses needing decryption');
      
      // Try batch decryption using RPC if available
      if (expensesNeedingDecryption.isNotEmpty) {
        try {
          print('ExpenseService: Attempting batch decryption...');
          final encryptedValues = expensesNeedingDecryption
              .map((e) => e['amount_encrypted'].toString())
              .toList();
          
          final batchResult = await supabase.rpc('decrypt_expense_amounts_batch', params: {
            'encrypted_amounts': encryptedValues,
          });
          
          if (batchResult != null && batchResult is List) {
            print('ExpenseService: ✅ Batch decryption successful');
            for (int i = 0; i < expensesNeedingDecryption.length && i < batchResult.length; i++) {
              final decryptedAmount = (batchResult[i] as num?)?.toDouble();
              if (decryptedAmount != null && decryptedAmount > 0) {
                expensesNeedingDecryption[i]['amount'] = decryptedAmount;
                print('ExpenseService: Decrypted amount ${i + 1}: $decryptedAmount');
              }
            }
          }
        } catch (e) {
          print('ExpenseService: Batch decryption not available: $e');
          print('ExpenseService: Will try individual decryption...');
        }
      }

      // Map expenses and attach employee names from employees table
      final expenses = await Future.wait((data as List).map((json) async {
        // Create a new map with employee name from employees table
        final expenseData = Map<String, dynamic>.from(json as Map<String, dynamic>);
        
        // Log raw data for ALL expenses to debug amount issue
        print('\n🔍 PARSING EXPENSE: ${expenseData['expense_number'] ?? expenseData['id']}');
        print('🔍 Amount in data: ${expenseData['amount']} (type: ${expenseData['amount']?.runtimeType})');
        print('🔍 Has amount_encrypted: ${expenseData.containsKey('amount_encrypted') && expenseData['amount_encrypted'] != null}');
        
        // Decrypt amount_encrypted if amount is null or 0
        final currentAmount = expenseData['amount'];
        final hasEncrypted = expenseData.containsKey('amount_encrypted') && expenseData['amount_encrypted'] != null;
        
        print('🔐 Decryption check for ${expenseData['expense_number']}:');
        print('🔐   Current amount: $currentAmount');
        print('🔐   Has amount_encrypted: $hasEncrypted');
        
        if ((currentAmount == null || currentAmount == 0) && hasEncrypted) {
          final encryptedValue = expenseData['amount_encrypted'];
          print('🔐   Encrypted value type: ${encryptedValue.runtimeType}');
          
          if (encryptedValue != null) {
            String encryptedStr;
            if (encryptedValue is String) {
              encryptedStr = encryptedValue;
            } else {
              encryptedStr = encryptedValue.toString();
            }
            
            if (encryptedStr.isNotEmpty && encryptedStr != 'null') {
              print('🔐   Attempting to decrypt (encrypted length: ${encryptedStr.length})...');
              print('🔐   Encrypted preview: ${encryptedStr.length > 50 ? encryptedStr.substring(0, 50) + "..." : encryptedStr}');
              
              try {
                final decryptedAmount = await _decryptAmount(encryptedStr);
                if (decryptedAmount != null && decryptedAmount > 0) {
                  expenseData['amount'] = decryptedAmount;
                  print('🔐   ✅ SUCCESS: Decrypted amount = $decryptedAmount');
                } else {
                  print('🔐   ⚠️ Decryption returned null or 0');
                  print('🔐   💡 The RPC function may not be configured in your database');
                  print('🔐   💡 You need to create a Supabase function to decrypt amounts');
                }
              } catch (e, stackTrace) {
                print('🔐   ❌ Error during decryption: $e');
                if (e.toString().contains('function') || e.toString().contains('does not exist')) {
                  print('🔐   💡 Database function for decryption does not exist');
                  print('🔐   💡 Create an RPC function "decrypt_expense_amount" in Supabase');
                }
              }
            } else {
              print('🔐   ⚠️ Encrypted value is empty or null string');
            }
          } else {
            print('🔐   ⚠️ amount_encrypted field is null');
          }
        } else if (currentAmount != null && currentAmount != 0) {
          print('🔐   ✅ Amount already available: $currentAmount');
        } else {
          print('🔐   ⚠️ No amount and no encrypted amount available');
        }
        
        final expEmployeeId = expenseData['employee_id'] as String?;
        final expCategoryId = expenseData['category_id'] as String?;
        
        // Attach category name from expense_categories table
        if (expCategoryId != null && categoryNameMap.containsKey(expCategoryId)) {
          expenseData['expense_categories'] = {
            'id': expCategoryId,
            'name': categoryNameMap[expCategoryId],
          };
          print('ExpenseService: Attached category name: ${categoryNameMap[expCategoryId]}');
        } else if (expCategoryId != null) {
          // Try to fetch individually if not in batch map
          try {
            final catData = await supabase
                .from('expense_categories')
                .select('id, name')
                .eq('id', expCategoryId)
                .maybeSingle();
            
            if (catData != null) {
              final catName = catData['name'] as String?;
              if (catName != null && catName.isNotEmpty) {
                expenseData['expense_categories'] = {
                  'id': expCategoryId,
                  'name': catName,
                };
                categoryNameMap[expCategoryId] = catName; // Cache it
                print('ExpenseService: Fetched category name individually: $catName');
              }
            }
          } catch (e) {
            print('ExpenseService: Error fetching category name individually for $expCategoryId: $e');
          }
        }
        
        // Attach employee name from employees table
        String? finalEmployeeName;
        
        if (expEmployeeId != null && employeeNameMap.containsKey(expEmployeeId)) {
          finalEmployeeName = employeeNameMap[expEmployeeId];
        } else if (employeeName != null && expEmployeeId == employeeId) {
          // Use the current user's employee name
          finalEmployeeName = employeeName;
        } else if (expEmployeeId != null && expEmployeeId.isNotEmpty) {
          // Fallback: fetch individually if not in batch map
          try {
            final empData = await supabase
                .from('employees')
                .select()
                .eq('id', expEmployeeId)
                .maybeSingle();
            
            if (empData != null) {
              finalEmployeeName = empData['full_name'] as String? ?? 
                                empData['name'] as String? ??
                                empData['first_name'] as String? ??
                                empData['employee_name'] as String?;
              
              if (finalEmployeeName != null && finalEmployeeName.isNotEmpty) {
                print('ExpenseService: Fetched employee name individually: $finalEmployeeName for $expEmployeeId');
                employeeNameMap[expEmployeeId] = finalEmployeeName; // Cache it
              }
            }
          } catch (e) {
            print('ExpenseService: Error fetching employee name individually for $expEmployeeId: $e');
          }
        }
        
        // Attach employee name to expense data
        if (finalEmployeeName != null && finalEmployeeName.isNotEmpty) {
          expenseData['employees'] = {
            'name': finalEmployeeName,
            'full_name': finalEmployeeName,
          };
          print('ExpenseService: Attached employee name to expense: $finalEmployeeName');
        } else {
          print('ExpenseService: Warning - No employee name found for expense with employee_id: $expEmployeeId');
        }
        
        try {
          return ExpenseClaim.fromJson(expenseData);
        } catch (e) {
          print('Error parsing expense: $e, Data: $expenseData');
          rethrow;
        }
      }));

      print('Parsed ${expenses.length} expenses successfully');

      // Fetch formatted employee IDs for each expense
      final expensesWithFormattedIds = <ExpenseClaim>[];
      for (var expense in expenses) {
        String? formattedId;
        if (expense.employeeId.isNotEmpty) {
          try {
            final fetchedId = await _profileService.getFormattedEmployeeCode(expense.employeeId);
            if (fetchedId != 'N/A' && fetchedId != expense.employeeId) {
              formattedId = fetchedId;
            }
          } catch (e) {
            print('Error fetching formatted employee ID for ${expense.employeeId}: $e');
          }
        }
        
        expensesWithFormattedIds.add(ExpenseClaim(
          id: expense.id,
          expenseNumber: expense.expenseNumber,
          userId: expense.userId,
          employeeId: expense.employeeId,
          employeeName: expense.employeeName,
          claimantName: expense.claimantName,
          expenseDate: expense.expenseDate,
          category: expense.category,
          categoryId: expense.categoryId,
          merchantName: expense.merchantName,
          amount: expense.amount,
          currency: expense.currency,
          status: expense.status,
          reimbursementMethod: expense.reimbursementMethod,
          createdAt: expense.createdAt,
          approvedBy: expense.approvedBy,
          approvedAt: expense.approvedAt,
          rejectionReason: expense.rejectionReason,
          reimbursedAt: expense.reimbursedAt,
          reimbursementReference: expense.reimbursementReference,
          receiptUrl: expense.receiptUrl,
          proofDocumentUrl: expense.proofDocumentUrl,
          description: expense.description,
          formattedEmployeeId: formattedId ?? expense.formattedEmployeeId,
        ));
      }
      
      print('Returning ${expensesWithFormattedIds.length} expenses with formatted IDs');
      return expensesWithFormattedIds;
    } catch (e, stackTrace) {
      print('Error fetching user expenses: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  // Get expense statistics for a user
  Future<Map<String, dynamic>> getExpenseStats(String userId) async {
    try {
      final expenses = await getUserExpenses(userId);
      
      print('ExpenseService.getExpenseStats: Processing ${expenses.length} expenses');
      
      final totalClaims = expenses.length;
      final pending = expenses.where((e) => e.status == ExpenseStatus.pending || e.status == ExpenseStatus.draft).length;
      final approved = expenses.where((e) => e.status == ExpenseStatus.approved || e.status == ExpenseStatus.reimbursed).length;
      final rejected = expenses.where((e) => e.status == ExpenseStatus.rejected).length;
      
      // Calculate total amount with detailed logging and validation
      double totalAmount = 0.0;
      for (var expense in expenses) {
        // Validate amount is reasonable before adding
        if (expense.amount > 0 && expense.amount <= 1000000000) {
          print('ExpenseService.getExpenseStats: Expense ${expense.expenseNumber} - amount: ${expense.amount}');
          totalAmount += expense.amount;
        } else {
          print('ExpenseService.getExpenseStats: ⚠ Skipping invalid amount for expense ${expense.expenseNumber}: ${expense.amount}');
        }
      }
      
      print('ExpenseService.getExpenseStats: Total amount calculated: $totalAmount');
      print('ExpenseService.getExpenseStats: Stats - Total: $totalClaims, Pending: $pending, Approved: $approved, Rejected: $rejected, Amount: $totalAmount');

      return {
        'total_claims': totalClaims,
        'pending': pending,
        'approved': approved,
        'rejected': rejected,
        'total_amount': totalAmount,
      };
    } catch (e) {
      print('Error fetching expense stats: $e');
      return {
        'total_claims': 0,
        'pending': 0,
        'approved': 0,
        'rejected': 0,
        'total_amount': 0.0,
      };
    }
  }

  // Get all expenses for an organization (for admin)
  Future<List<ExpenseClaim>> getOrganizationExpenses(String organizationId) async {
    try {
      // Get all employee IDs from user profiles in the organization
      final profiles = await supabase
          .from('user_profiles')
          .select('employee_id')
          .eq('organization_id', organizationId);

      final employeeIds = (profiles as List)
          .map((p) => p['employee_id'] as String?)
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList();

      if (employeeIds.isEmpty) {
        print('No employee IDs found for organization: $organizationId');
        return [];
      }

      print('Found ${employeeIds.length} employee IDs for organization');

      // Get expenses for these employees - try explicit selection, fallback to select(*)
      List<dynamic> data = [];
      try {
        try {
          data = await supabase
              .from('expenses')
              .select('id, expense_number, employee_id, expense_date, amount, currency, merchant_name, status, category_id, description, created_at, approved_by, approved_at, rejection_reason, reimbursed_at, reimbursement_reference, receipt_url, proof_document_url, reimbursement_method')
              .inFilter('employee_id', employeeIds)
              .order('created_at', ascending: false);
        } catch (e) {
          // Fallback to select all if explicit selection fails
          print('ExpenseService: Explicit select failed, using select(*): $e');
          data = await supabase
              .from('expenses')
              .select('*')
              .inFilter('employee_id', employeeIds)
              .order('created_at', ascending: false);
        }
        print('Found ${data.length} expenses for organization');
        
        // Log first expense to debug amount issue
        if (data.isNotEmpty) {
          final firstExpense = data[0] as Map<String, dynamic>;
          print('ExpenseService: First expense amount raw value: ${firstExpense['amount']} (type: ${firstExpense['amount']?.runtimeType})');
        }
      } catch (e) {
        print('Error fetching expenses by employee_id list: $e');
        // Fallback: fetch all and filter client-side
        try {
          try {
            data = await supabase
                .from('expenses')
                .select('id, expense_number, employee_id, expense_date, amount, currency, merchant_name, status, category_id, description, created_at, approved_by, approved_at, rejection_reason, reimbursed_at, reimbursement_reference, receipt_url, proof_document_url, reimbursement_method')
                .order('created_at', ascending: false);
          } catch (e3) {
            // Fallback to select all
            print('ExpenseService: Explicit select failed, using select(*): $e3');
            data = await supabase
                .from('expenses')
                .select('*')
                .order('created_at', ascending: false);
          }
          data = (data as List).where((expense) {
            final expEmpId = expense['employee_id'] as String?;
            return expEmpId != null && employeeIds.contains(expEmpId);
          }).toList();
          print('Filtered to ${data.length} expenses by employee_id');
        } catch (e2) {
          print('Error fetching all expenses: $e2');
          return [];
        }
      }

      // Batch fetch employee names from employees table
      final employeeNameMap = <String, String>{};
      if (employeeIds.isNotEmpty) {
        try {
          print('ExpenseService: Batch fetching employee names for organization expenses');
          final employeesData = await supabase
              .from('employees')
              .select()
              .inFilter('id', employeeIds);
          
          for (var empData in employeesData) {
            final empId = empData['id'] as String?;
            if (empId == null) continue;
            
            final empName = empData['full_name'] as String? ?? 
                          empData['name'] as String? ??
                          empData['first_name'] as String? ??
                          empData['employee_name'] as String?;
            
            if (empName != null && empName.isNotEmpty && empName.trim().isNotEmpty) {
              employeeNameMap[empId] = empName.trim();
              print('ExpenseService: Found employee name from employees table: $empName for $empId');
            }
          }
        } catch (e) {
          print('ExpenseService: Error batch fetching from employees table: $e');
        }
        
        // Fallback: fetch from user_profiles for any missing names
        final missingIds = employeeIds.where((id) => !employeeNameMap.containsKey(id)).toList();
        if (missingIds.isNotEmpty) {
          try {
            final profiles = await supabase
                .from('user_profiles')
                .select('employee_id, full_name, user_id')
                .inFilter('employee_id', missingIds);
            
            for (var profile in profiles) {
              final empId = profile['employee_id'] as String?;
              final name = profile['full_name'] as String?;
              if (empId != null && name != null && name.isNotEmpty && !employeeNameMap.containsKey(empId)) {
                employeeNameMap[empId] = name;
              }
            }
          } catch (e) {
            print('ExpenseService: Error fetching from user_profiles: $e');
          }
        }
      }

      // Map expenses and attach employee names from employees table
      final expenses = await Future.wait((data as List).map((json) async {
        final expenseData = Map<String, dynamic>.from(json as Map<String, dynamic>);
        final empId = expenseData['employee_id'] as String?;
        
        // Attach employee name from employees table (prioritized)
        String? finalEmployeeName;
        
        if (empId != null && employeeNameMap.containsKey(empId)) {
          finalEmployeeName = employeeNameMap[empId];
        } else if (empId != null && empId.isNotEmpty) {
          // Fallback: fetch individually if not in batch map
          try {
            final empData = await supabase
                .from('employees')
                .select()
                .eq('id', empId)
                .maybeSingle();
            
            if (empData != null) {
              finalEmployeeName = empData['full_name'] as String? ?? 
                                empData['name'] as String? ??
                                empData['first_name'] as String? ??
                                empData['employee_name'] as String?;
              
              if (finalEmployeeName != null && finalEmployeeName.isNotEmpty) {
                print('ExpenseService: Fetched employee name individually (org): $finalEmployeeName for $empId');
                employeeNameMap[empId] = finalEmployeeName; // Cache it
              }
            }
          } catch (e) {
            print('ExpenseService: Error fetching employee name individually (org) for $empId: $e');
          }
        }
        
        // Attach employee name to expense data
        if (finalEmployeeName != null && finalEmployeeName.isNotEmpty) {
          expenseData['employees'] = {
            'name': finalEmployeeName,
            'full_name': finalEmployeeName,
          };
          print('ExpenseService: Attached employee name to expense (org): $finalEmployeeName');
        } else {
          print('ExpenseService: Warning - No employee name found for expense with employee_id: $empId');
        }
        
        return ExpenseClaim.fromJson(expenseData);
      }));

      print('Parsed ${expenses.length} expenses successfully');

      // Fetch formatted employee IDs for each expense
      final expensesWithFormattedIds = <ExpenseClaim>[];
      for (var expense in expenses) {
        String? formattedId;
        if (expense.employeeId.isNotEmpty) {
          try {
            final fetchedId = await _profileService.getFormattedEmployeeCode(expense.employeeId);
            if (fetchedId != 'N/A' && fetchedId != expense.employeeId) {
              formattedId = fetchedId;
            }
          } catch (e) {
            print('Error fetching formatted employee ID for ${expense.employeeId}: $e');
          }
        }
        
        expensesWithFormattedIds.add(ExpenseClaim(
          id: expense.id,
          expenseNumber: expense.expenseNumber,
          userId: expense.userId,
          employeeId: expense.employeeId,
          employeeName: expense.employeeName,
          claimantName: expense.claimantName,
          expenseDate: expense.expenseDate,
          category: expense.category,
          categoryId: expense.categoryId,
          merchantName: expense.merchantName,
          amount: expense.amount,
          currency: expense.currency,
          status: expense.status,
          reimbursementMethod: expense.reimbursementMethod,
          createdAt: expense.createdAt,
          approvedBy: expense.approvedBy,
          approvedAt: expense.approvedAt,
          rejectionReason: expense.rejectionReason,
          reimbursedAt: expense.reimbursedAt,
          reimbursementReference: expense.reimbursementReference,
          receiptUrl: expense.receiptUrl,
          proofDocumentUrl: expense.proofDocumentUrl,
          description: expense.description,
          formattedEmployeeId: formattedId ?? expense.formattedEmployeeId,
        ));
      }
      
      return expensesWithFormattedIds;

      return expenses;
    } catch (e) {
      print('Error fetching organization expenses: $e');
      return [];
    }
  }

  // Create a new expense claim
  Future<bool> createExpenseClaim({
    required String userId,
    required String employeeId,
    required double amount,
    required String category,
    required String merchant,
    required DateTime date,
    String? claimantName,
    String? description,
  }) async {
    try {
      // Generate expense ID
      final expenseId = 'EXP-${DateTime.now().millisecondsSinceEpoch}';
      
      // Get organization_id from user profile
      String? organizationId;
      try {
        final profile = await supabase
            .from('user_profiles')
            .select('organization_id')
            .eq('user_id', userId)
            .maybeSingle();
        organizationId = profile?['organization_id'] as String?;
      } catch (e) {
        print('Error fetching organization_id: $e');
      }
      
      if (organizationId == null) {
        print('Error: organization_id not found for user');
        return false;
      }
      
      // Build insert data matching the expenses table schema
      final insertData = <String, dynamic>{
        'organization_id': organizationId,
        'employee_id': employeeId,
        'expense_number': expenseId,
        'expense_date': date.toIso8601String().split('T')[0], // Date only, not datetime
        'amount': amount,
        'currency': 'INR',
        'merchant_name': merchant,
        'status': 'pending',
      };
      
      // Add category_id if provided (category should be a UUID)
      if (category != null && category.isNotEmpty) {
        // Try to find category_id by name
        try {
          final categoryData = await supabase
              .from('expense_categories')
              .select('id')
              .eq('name', category)
              .maybeSingle();
          if (categoryData != null) {
            insertData['category_id'] = categoryData['id'];
          }
        } catch (e) {
          print('Error finding category: $e');
        }
      }
      
      if (description != null && description.isNotEmpty) {
        insertData['description'] = description;
      }
      
      await supabase
          .from('expenses')
          .insert(insertData);
      
      print('Created expense: $expenseId for employee: $employeeId');

      return true;
    } catch (e) {
      print('Error creating expense claim: $e');
      return false;
    }
  }

  // Filter expenses by status
  List<ExpenseClaim> filterExpensesByStatus(
    List<ExpenseClaim> expenses,
    String? status,
  ) {
    if (status == null || status == 'All Status' || status.isEmpty) {
      return expenses;
    }

    ExpenseStatus? filterStatus;
    switch (status.toLowerCase()) {
      case 'pending':
        filterStatus = ExpenseStatus.pending;
        break;
      case 'approved':
        filterStatus = ExpenseStatus.approved;
        break;
      case 'rejected':
        filterStatus = ExpenseStatus.rejected;
        break;
      case 'acknowledged':
        filterStatus = ExpenseStatus.acknowledged;
        break;
      case 'settled':
        filterStatus = ExpenseStatus.settled;
        break;
      default:
        return expenses;
    }

    return expenses.where((e) => e.status == filterStatus).toList();
  }

  // Search expenses
  List<ExpenseClaim> filterExpensesByMethod(
    List<ExpenseClaim> expenses,
    String? method,
  ) {
    if (method == null || method == 'All Methods' || method.isEmpty) {
      return expenses;
    }
    
    final methodLower = method.toLowerCase().replaceAll(' ', '_');
    return expenses.where((e) {
      if (e.reimbursementMethod == null) return false;
      final expMethod = e.reimbursementMethod.toString().split('.').last.toLowerCase();
      // Handle bank_transfer vs bank transfer mapping if needed
      return expMethod == methodLower;
    }).toList();
  }

  List<ExpenseClaim> searchExpenses(
    List<ExpenseClaim> expenses,
    String query,
  ) {
    if (query.isEmpty) return expenses;

    final lowerQuery = query.toLowerCase();
    return expenses.where((expense) {
      return expense.merchant.toLowerCase().contains(lowerQuery) ||
          expense.category.toLowerCase().contains(lowerQuery) ||
          expense.expenseId.toLowerCase().contains(lowerQuery) ||
          expense.employeeName.toLowerCase().contains(lowerQuery) ||
          (expense.claimantName?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }
}

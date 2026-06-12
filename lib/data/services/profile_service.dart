import 'package:loghr_mobile/config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dart:typed_data';

class ProfileService {
  /// Tries to find employee data through database views/functions (similar to website approach)
  /// This might be needed if the website uses a view that joins employees with other tables
  Future<Map<String, dynamic>?> _tryEmployeeViewApproach(String employeeId) async {
    print('ProfileService: 🔍 Trying to find employee data through views/functions...');
    
    // Common patterns for employee views
    final viewPatterns = [
      'employees_with_details',
      'employee_details',
      'v_employees',
      'employees_view',
      'user_employees',
      'employees_full',
    ];
    
    for (final pattern in viewPatterns) {
      try {
        final viewData = await supabase
            .from(pattern)
            .select()
            .eq('id', employeeId)
            .maybeSingle();
        
        if (viewData != null) {
          final firstName = viewData['first_name'] as String?;
          final lastName = viewData['last_name'] as String?;
          String? constructedName;
          if (firstName != null && firstName.trim().isNotEmpty) {
            constructedName = firstName.trim();
            if (lastName != null && lastName.trim().isNotEmpty) {
              constructedName = '$constructedName ${lastName.trim()}';
            }
          }

          final name = constructedName ?? 
                       viewData['full_name'] as String? ?? 
                       viewData['name'] as String? ??
                       viewData['employee_name'] as String? ??
                       viewData['display_name'] as String?;
          
          if (name != null && name.isNotEmpty) {
            print('ProfileService: ✅✅✅ Found working view "$pattern" ✅✅✅');
            
            // Ensure the name is set in the full_name field for the UI
            final result = Map<String, dynamic>.from(viewData);
            result['full_name'] = name;
            return result;
          }
        }
      } catch (e) {
        // Not a view, continue
        continue;
      }
    }
    
    return null;
  }

  // Fetch employee default details from employees table
  Future<Map<String, dynamic>?> getEmployeeDetails(String employeeId) async {
    try {
      print('ProfileService: 🔍 Fetching employee details for employee_id: $employeeId');
      
      // First, try to find through views/functions (like website might use)
      final viewData = await _tryEmployeeViewApproach(employeeId);
      if (viewData != null) {
        return viewData;
      }
      
      // Fallback: Try to fetch from employees table directly using robust lookup
      return await _fetchEmployeeRecord(employeeId);
    } catch (e) {
      print('ProfileService: ❌ Error in getEmployeeDetails: $e');
      return null;
    }
  }

  // Robustly fetch employee record by ID or Employee Code
  Future<Map<String, dynamic>?> _fetchEmployeeRecord(String employeeId) async {
    if (employeeId.isEmpty) return null;

    // 1. Try by ID (primary key/UUID)
    try {
      final data = await supabase
          .from('employees')
          .select()
          .eq('id', employeeId)
          .maybeSingle();
      if (data != null) return data;
    } catch (e) {
      // Error might mean ID is not a UUID, try fallback
    }

    // 2. Try by employee_code
    try {
      final data = await supabase
          .from('employees')
          .select()
          .eq('employee_code', employeeId)
          .maybeSingle();
      if (data != null) return data;
    } catch (e) {
      print('ProfileService: Error fetching by employee_code: $e');
    }

    // 3. Fallback with explicit columns if full select fails
    try {
      final data = await supabase
          .from('employees')
          .select('id, full_name, name, first_name, last_name, employee_name, display_name, designation, position, job_title, title, designation_id, department_id, status, is_active, employee_code, email, company_email, work_email, official_email, phone, mobile, contact_number, work_phone, phone_number, date_of_joining, joining_date, doj, start_date, pan, pan_number, aadhaar, aadhaar_number, uan, uan_number, bank_name, account_number, account_no, bank_account_no, bank_acc_no, ifsc_code, ifsc, bank_branch, branch_name, branch')
          .or('id.eq.$employeeId,employee_code.eq.$employeeId')
          .maybeSingle();
      return data;
    } catch (e) {
      print('ProfileService: Final fallback select failed: $e');
    }

    return null;
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

  /// Resolves an avatar_url storage path to a public URL
  String? _resolveAvatarUrl(String? avatarPath) {
    if (avatarPath == null || avatarPath.isEmpty) return null;
    
    // If it's already a full URL, use it as is
    if (avatarPath.startsWith('http://') || avatarPath.startsWith('https://')) {
      return avatarPath;
    }
    
    // It's likely a storage path, try to get public URL from different buckets
    final buckets = [
      'avatars', 'profiles', 'public', 'employees', 
      'organizations', 'company-logos', 'logos', 
      'holiday-calendars', 'holidays', 'documents', 
      'images', 'storage', 'files'
    ];
    
    for (final bucket in buckets) {
      try {
        // Check if the path starts with bucket name (common if full path was stored)
        String cleanPath = avatarPath;
        if (cleanPath.startsWith('$bucket/')) {
          cleanPath = cleanPath.replaceFirst('$bucket/', '');
        } else if (cleanPath.startsWith('/')) {
          cleanPath = cleanPath.substring(1);
        }
        
        // Note: getPublicUrl just constructs a string, it doesn't verify existence.
        // However, if we store the full URL on upload, this fallback is less critical.
        final publicUrl = supabase.storage.from(bucket).getPublicUrl(cleanPath);
        
        // Basic heuristic: if the path was 'userId/file.jpg' and we are trying 'avatars' bucket,
        // we hope this is the right one.
        return publicUrl;
      } catch (e) {
        continue;
      }
    }
    
    return avatarPath;
  }

  // Get employee name from employees table (prioritized method)
  Future<String?> getEmployeeName(String employeeId) async {
    if (employeeId.isEmpty || employeeId == 'N/A') {
      return null;
    }
    
    try {
      print('ProfileService: Fetching employee name for employee_id: $employeeId');
      final employeeData = await supabase
          .from('employees')
          .select()
          .eq('id', employeeId)
          .maybeSingle();
      
      if (employeeData != null) {
        // PRIORITIZE: Construct name from first_name and last_name if they exist
        final firstName = employeeData['first_name'] as String?;
        final lastName = employeeData['last_name'] as String?;
        String? constructedName;
        
        if (firstName != null && firstName.trim().isNotEmpty) {
          constructedName = firstName.trim();
          if (lastName != null && lastName.trim().isNotEmpty) {
            constructedName = '$constructedName ${lastName.trim()}';
          }
        }

        final empName = constructedName ?? 
                       employeeData['full_name'] as String? ?? 
                       employeeData['display_name'] as String? ??
                       employeeData['name'] as String? ??
                       employeeData['employee_name'] as String?;
        
        if (empName != null && empName.isNotEmpty && empName.trim().isNotEmpty) {
          print('ProfileService: ✅ Found employee name in employees table: "$empName"');
          return empName.trim();
        } else {
          print('ProfileService: ⚠️ Employee record found but name fields are empty for ID: $employeeId');
        }
      }
    } catch (e) {
      print('ProfileService: Error fetching employee name: $e');
      return null;
    }
    return null;
  }

  /// Tries to find user profile through database views that join with employees table
  /// This might be what the website uses
  Future<Map<String, dynamic>?> _tryProfileViewApproach(String userId) async {
    print('ProfileService: 🔍 Trying to find profile through views/functions...');
    
    // Common patterns for profile views that join with employees
    final viewPatterns = [
      'user_profiles_with_employees',
      'user_profiles_full',
      'v_user_profiles',
      'user_profiles_view',
      'employees_with_profiles',
      'profile_details',
    ];
    
    for (final pattern in viewPatterns) {
      try {
        final viewData = await supabase
            .from(pattern)
            .select()
            .eq('user_id', userId)
            .maybeSingle();
        
        if (viewData != null) {
          // Check if it has employee name (indicating it's joined with employees)
          final firstName = viewData['first_name'] as String?;
          final lastName = viewData['last_name'] as String?;
          String? constructedName;
          if (firstName != null && firstName.trim().isNotEmpty) {
            constructedName = firstName.trim();
            if (lastName != null && lastName.trim().isNotEmpty) {
              constructedName = '$constructedName ${lastName.trim()}';
            }
          }

          final name = constructedName ?? 
                       viewData['full_name'] as String? ?? 
                       viewData['name'] as String? ??
                       viewData['employee_name'] as String? ??
                       viewData['display_name'] as String?;
          
          final designation = viewData['designation'] as String? ?? 
                             viewData['position'] as String? ?? 
                             viewData['job_title'] as String?;
          
          if (name != null && name.isNotEmpty) {
            print('ProfileService: ✅✅✅ Found working view "$pattern" ✅✅✅');
            print('ProfileService: 📋 View has name: $name, designation: $designation');
            
            // Ensure the name is set in the full_name field for the UI
            final result = Map<String, dynamic>.from(viewData);
            result['full_name'] = name;
            return result;
          }
        }
      } catch (e) {
        // Not a view, continue
        continue;
      }
    }
    
    return null;
  }

  // Fetch complete user profile data
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      print('ProfileService: 🔍 Fetching user profile for user_id: $userId');
      
      // First, try to find through views (like website might use)
      final viewData = await _tryProfileViewApproach(userId);
      if (viewData != null) {
        print('ProfileService: ✅ Found data in view');
      }
      
      // Fetch from user_profiles table
      final data = await supabase
          .from('user_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      
      if (data == null && viewData == null) {
        print('ProfileService: ❌ No profile found in user_profiles or views');
        return null;
      }

      // Base data is from user_profiles if found, otherwise from view
      final profileBase = data ?? Map<String, dynamic>.from(viewData!);
      
      if (data != null) {
        profileBase['avatar_url'] = _resolveAvatarUrl(profileBase['avatar_url'] as String?);
        print('ProfileService: ✅ Profile data fetched from user_profiles');
        
        // Merge viewData into profileBase for fields that might be missing in user_profiles
        if (viewData != null) {
          viewData.forEach((key, value) {
            if (value != null && (profileBase[key] == null || (profileBase[key] is String && (profileBase[key] as String).isEmpty))) {
              profileBase[key] = value;
            }
          });
        }
      }
      
      final employeeId = profileBase['employee_id'] as String?;
      
      // Some schemas might have user_id in employees table
      Map<String, dynamic>? employeeData;
        
        try {
          // FIRST PRIORITY: Try to find employee by user_id (if employees table has user_id column)
          // This ensures we get the correct employee record even if employee_id in user_profiles is wrong
          try {
            print('ProfileService: 🔍 STEP 1: Trying to find employee by user_id: $userId');
            Map<String, dynamic>? employeeByUserId;
            
            try {
              employeeByUserId = await supabase
                  .from('employees')
                  .select()
                  .eq('user_id', userId)
                  .maybeSingle();
            } catch (e) {
              // If select() fails, try with explicit columns
              print('ProfileService: ⚠️ Full select failed, trying explicit columns: $e');
              try {
                employeeByUserId = await supabase
                    .from('employees')
                    .select('id, full_name, name, first_name, employee_name, designation, position, job_title, title, designation_id, department_id, status, is_active, employee_code, email, company_email, work_email, official_email, phone, mobile, contact_number, work_phone, phone_number, date_of_joining, joining_date, doj, start_date, user_id, pan, pan_number, aadhaar, aadhaar_number, uan, uan_number, bank_name, account_number, account_no, bank_account_no, bank_acc_no, ifsc_code, ifsc, bank_branch, branch_name, branch')
                    .eq('user_id', userId)
                    .maybeSingle();
              } catch (e2) {
                print('ProfileService: ⚠️ Explicit select also failed: $e2');
              }
            }
            
            if (employeeByUserId != null) {
              final empId = employeeByUserId['id'] as String?;
              final name = employeeByUserId['full_name'] as String? ?? 
                          employeeByUserId['name'] as String? ??
                          employeeByUserId['first_name'] as String? ??
                          employeeByUserId['employee_name'] as String?;
              
              print('ProfileService: ✅✅✅ Found employee by user_id! Employee ID: $empId, Name: "$name" ✅✅✅');
              print('ProfileService: 📋 Email: ${employeeByUserId['email']}, Phone: ${employeeByUserId['phone']}');
              employeeData = employeeByUserId;
              
              // Verify if employee_id in user_profiles matches
              if (employeeId != null && employeeId != empId) {
                print('ProfileService: ⚠️⚠️⚠️ WARNING: employee_id mismatch! ⚠️⚠️⚠️');
                print('ProfileService: ⚠️ user_profiles.employee_id: "$employeeId"');
                print('ProfileService: ⚠️ employees.id (found by user_id): "$empId"');
                print('ProfileService: 💡 Using employee record found by user_id (this is the correct one)');
              }
            }
          } catch (e) {
            // employees table might not have user_id column, that's okay
            print('ProfileService: ⚠️ employees table might not have user_id column: $e');
          }
          
          // SECOND PRIORITY: If not found by user_id, try using employee_id from user_profiles
          if (employeeData == null && employeeId != null && employeeId.isNotEmpty) {
            print('ProfileService: 🔍 STEP 2: Fetching employee details for employee_id from user_profiles: $employeeId');
            try {
              final fetchedEmployee = await getEmployeeDetails(employeeId);
              if (fetchedEmployee != null) {
                employeeData = fetchedEmployee;
                
                final name = fetchedEmployee['full_name'] as String? ?? 
                           fetchedEmployee['name'] as String? ??
                           fetchedEmployee['first_name'] as String? ??
                           fetchedEmployee['employee_name'] as String?;
                
                print('ProfileService: ✅ Found employee by employee_id from user_profiles: "$name"');
              }
            } catch (e) {
              print('ProfileService: ❌ Error fetching employee by employee_id: $e');
            }
          }
          
          if (employeeData != null) {
              print('ProfileService: ✅ Employee data fetched from employees table');
              print('ProfileService: 📋 employees data keys: ${employeeData.keys.toList()}');
              print('ProfileService: 📋 employees full_name: ${employeeData['full_name']}');
              print('ProfileService: 📋 employees name: ${employeeData['name']}');
              print('ProfileService: 📋 employees designation: ${employeeData['designation']}');
              print('ProfileService: 📋 employees status: ${employeeData['status']}');
              print('ProfileService: 📋 employees is_active: ${employeeData['is_active']}');
              print('ProfileService: 📋 employees date_of_joining: ${employeeData['date_of_joining']}');
              print('ProfileService: 📋 employees joining_date: ${employeeData['joining_date']}');
              print('ProfileService: 📋 employees email: ${employeeData['email']}');
              print('ProfileService: 📋 employees company_email: ${employeeData['company_email']}');
              print('ProfileService: 📋 employees phone: ${employeeData['phone']}');
              print('ProfileService: 📋 employees mobile: ${employeeData['mobile']}');
              print('ProfileService: 📋 base email: ${profileBase['email']}');
              print('ProfileService: 📋 base phone: ${profileBase['phone']}');
              print('ProfileService: 📋 base mobile: ${profileBase['mobile']}');
              print('ProfileService: 📋 base date_of_joining: ${profileBase['date_of_joining']}');
              
              // Merge employee data into profile data, prioritizing base for existing fields
              // but adding employee table fields that might not exist in base
              final mergedData = Map<String, dynamic>.from(profileBase);
              
              // Merge employee data, only for fields that don't exist in user_profiles or are null
              // BUT always prioritize certain fields from employees table (department, designation, etc.)
              final fieldsToAlwaysPrioritize = [
                'designation', 'position', 'job_title', 'title', 
                'department', 'department_id', 'status', 'branch', 'branch_id',
                'date_of_joining', 'joining_date', 'doj', 'start_date', // Date of joining from employees
                'email', 'company_email', 'work_email', // Contact info from employees
                'phone', 'mobile', 'contact_number', 'work_phone', // Phone from employees
                'pan', 'pan_number', 'aadhaar', 'aadhaar_number', 'uan', 'uan_number', // IDs from employees
                'bank_name', 'account_number', 'account_no', 'bank_account_no', 'bank_acc_no', 'bank_account_number', 
                'ifsc_code', 'ifsc', 'bank_branch', 'branch_name', 'branch', // Bank from employees
                'highest_qualification', 'university', 'specialization', 'year_of_completion', // Education
              ];
              
              employeeData.forEach((key, value) {
                // Always prioritize certain fields from employees table
                if (fieldsToAlwaysPrioritize.contains(key) && value != null && 
                    (value is String ? value.toString().trim().isNotEmpty : true)) {
                  mergedData[key] = value;
                  print('ProfileService: ⭐ Prioritized employee field: $key = $value');
                }
                // For other fields, only merge if the field doesn't exist in user_profiles or is null/empty
                else if (!mergedData.containsKey(key) || 
                    mergedData[key] == null || 
                    mergedData[key] == '' ||
                    (mergedData[key] is String && (mergedData[key] as String).isEmpty)) {
                  mergedData[key] = value;
                  print('ProfileService: ➕ Merged employee field: $key = $value');
                }
              });
              
              // Specifically handle contact information from employees table
              // Company/Work Email
              final companyEmail = employeeData['email'] as String? ?? 
                                 employeeData['company_email'] as String? ??
                                 employeeData['work_email'] as String? ??
                                 employeeData['official_email'] as String?;
              
              if (companyEmail != null && companyEmail.isNotEmpty && companyEmail.trim().isNotEmpty) {
                // Always prioritize email from employees table if user_profiles doesn't have it
                if (mergedData['email'] == null || 
                    mergedData['email'] == '' ||
                    (mergedData['email'] is String && (mergedData['email'] as String).trim().isEmpty)) {
                  mergedData['email'] = companyEmail.trim();
                  print('ProfileService: ✅✅✅ Using company email from employees table: "$companyEmail" ✅✅✅');
                } else {
                  print('ProfileService: ℹ️ user_profiles already has email: ${mergedData['email']}, keeping it');
                }
              } else {
                print('ProfileService: ⚠️ No company email found in employees table');
              }
              
              // Also try to get email from auth.users if still not found
              if ((mergedData['email'] == null || 
                   mergedData['email'] == '' ||
                   (mergedData['email'] is String && (mergedData['email'] as String).trim().isEmpty)) &&
                  userId.isNotEmpty) {
                try {
                  final authUser = supabase.auth.currentUser;
                  if (authUser != null && authUser.email != null && authUser.email!.isNotEmpty) {
                    mergedData['email'] = authUser.email!.trim();
                    print('ProfileService: ✅ Using email from auth.users: ${authUser.email}');
                  }
                } catch (e) {
                  print('ProfileService: ⚠️ Could not get email from auth.users: $e');
                }
              }
              
              // Phone/Mobile
              print('ProfileService: 🔍 Checking all phone fields in employeeData:');
              print('  - phone: ${employeeData['phone']}');
              print('  - mobile: ${employeeData['mobile']}');
              print('  - contact_number: ${employeeData['contact_number']}');
              print('  - work_phone: ${employeeData['work_phone']}');
              print('  - phone_number: ${employeeData['phone_number']}');
              
              final phone = employeeData['phone'] as String? ?? 
                           employeeData['mobile'] as String? ??
                           employeeData['contact_number'] as String? ??
                           employeeData['work_phone'] as String? ??
                           employeeData['phone_number'] as String?;
              
              if (phone != null && phone.isNotEmpty && phone.trim().isNotEmpty) {
                // Always prioritize phone from employees table if user_profiles doesn't have it
                if ((mergedData['phone'] == null || 
                     mergedData['phone'] == '' ||
                     (mergedData['phone'] is String && (mergedData['phone'] as String).trim().isEmpty)) &&
                    (mergedData['mobile'] == null || 
                     mergedData['mobile'] == '' ||
                     (mergedData['mobile'] is String && (mergedData['mobile'] as String).trim().isEmpty))) {
                  mergedData['phone'] = phone.trim();
                  mergedData['mobile'] = phone.trim(); // Also set mobile for compatibility
                  print('ProfileService: ✅✅✅ Using phone from employees table: "$phone" ✅✅✅');
                } else {
                  print('ProfileService: ℹ️ user_profiles already has phone: ${mergedData['phone'] ?? mergedData['mobile']}, keeping it');
                }
              } else {
                print('ProfileService: ⚠️ No phone found in employees table');
              }
              
              // ALWAYS prioritize employee name from employees table (this is critical!)
              print('ProfileService: 🔍 Resolving name from employeeData...');
              
              final constructedName = _constructName(employeeData);
              final empFullName = employeeData['full_name'] as String? ?? 
                                 employeeData['display_name'] as String? ??
                                 employeeData['name'] as String? ??
                                 employeeData['employee_name'] as String?;
              
              final empName = (constructedName != null && constructedName.isNotEmpty) ? constructedName : empFullName;
              
              if (empName != null && empName.isNotEmpty && empName.trim().isNotEmpty) {
                final trimmedName = empName.trim();
                print('ProfileService: ✅✅✅ SUCCESS: Using employee name from employees table: "$trimmedName" ✅✅✅');
                print('ProfileService: 📋 (Previous name was: ${profileBase['full_name']})');
                mergedData['full_name'] = trimmedName;
              }
              
              // Always include employee_code and other employee-specific fields
              if (employeeData['employee_code'] != null) {
                mergedData['employee_code'] = employeeData['employee_code'];
              }
              
              // ALWAYS prioritize department and designation from employees table
              // Fetch department name if department_id exists
              final departmentId = employeeData['department_id'] as String?;
              if (departmentId != null && departmentId.isNotEmpty) {
                try {
                  final deptData = await supabase
                      .from('departments')
                      .select('name')
                      .eq('id', departmentId)
                      .maybeSingle();
                  
                  if (deptData != null) {
                    final deptName = deptData['name'] as String? ?? 
                                   deptData['department_name'] as String? ??
                                   deptData['title'] as String?;
                    
                    if (deptName != null) {
                      mergedData['department'] = deptName;
                      mergedData['department_id'] = departmentId;
                      print('ProfileService: ✅ Fetched department name: $deptName');
                    } else {
                      mergedData['department_id'] = departmentId;
                      print('ProfileService: ⚠️ Department ID found but name not found: $departmentId');
                    }
                  } else {
                    // If department not found, still set department_id
                    mergedData['department_id'] = departmentId;
                    print('ProfileService: ⚠️ Department ID found but name not found: $departmentId');
                  }
                } catch (e) {
                  print('ProfileService: Error fetching department name: $e');
                  // Still set department_id even if name fetch fails
                  mergedData['department_id'] = departmentId;
                }
              }
              
              // Always prioritize branch from employees table
              // Fetch branch name if branch_id exists
              final branchId = employeeData['branch_id'] as String?;
              if (branchId != null && branchId.isNotEmpty) {
                try {
                  final branchData = await supabase
                      .from('branches')
                      .select('name')
                      .eq('id', branchId)
                      .maybeSingle();
                  
                  if (branchData != null) {
                    final branchName = branchData['name'] as String? ??
                                     branchData['branch_name'] as String? ??
                                     branchData['location'] as String?;
                    
                    if (branchName != null) {
                      mergedData['branch'] = branchName;
                      mergedData['branch_id'] = branchId;
                      print('ProfileService: ✅ Fetched branch name: $branchName');
                    } else {
                      mergedData['branch_id'] = branchId;
                      print('ProfileService: ⚠️ Branch ID found but name not found: $branchId');
                    }
                  } else {
                    mergedData['branch_id'] = branchId;
                    print('ProfileService: ⚠️ Branch ID found but name not found: $branchId');
                  }
                } catch (e) {
                  print('ProfileService: Error fetching branch name: $e');
                  mergedData['branch_id'] = branchId;
                }
              }
              
              // Always prioritize designation from employees table
              print('ProfileService: 🔍 Checking designation in employeeData:');
              print('  - designation: ${employeeData['designation']} (type: ${employeeData['designation']?.runtimeType})');
              print('  - position: ${employeeData['position']} (type: ${employeeData['position']?.runtimeType})');
              print('  - job_title: ${employeeData['job_title']} (type: ${employeeData['job_title']?.runtimeType})');
              print('  - title: ${employeeData['title']} (type: ${employeeData['title']?.runtimeType})');
              print('  - All employeeData keys: ${employeeData.keys.toList()}');
              
              // Check if designation_id exists and fetch from designations table if needed
              String? designation;
              
              // FIRST: Try direct designation fields from employees table
              designation = employeeData['designation'] as String? ?? 
                           employeeData['position'] as String? ??
                           employeeData['job_title'] as String? ??
                           employeeData['title'] as String?;
              
              // If not found directly, try fetching from designations table via designation_id
              if ((designation == null || designation.isEmpty || designation.trim().isEmpty) && 
                  employeeData.containsKey('designation_id')) {
                final designationId = employeeData['designation_id'] as String?;
                if (designationId != null && designationId.isNotEmpty) {
                  print('ProfileService: 🔍 Designation not found directly, fetching from designations table - designation_id: $designationId');
                  try {
                    final designationRow = await supabase
                        .from('designations')
                        .select()
                        .eq('id', designationId)
                        .maybeSingle();
                    
                    if (designationRow != null) {
                      designation = designationRow['name'] as String? ??
                                   designationRow['title'] as String? ??
                                   designationRow['designation'] as String? ??
                                   designationRow['designation_name'] as String? ??
                                   designationRow['position'] as String? ??
                                   designationRow['job_title'] as String?;
                      
                      if (designation != null && designation.isNotEmpty) {
                        print('ProfileService: ✅ Found designation from designations table: "$designation"');
                      }
                    }
                  } catch (e) {
                    print('ProfileService: ❌ Error fetching designation from designations table: $e');
                  }
                }
              }
              
              if (designation != null && designation.isNotEmpty && designation.trim().isNotEmpty) {
                mergedData['designation'] = designation.trim();
                mergedData['position'] = designation.trim(); // Also set position for compatibility
                print('ProfileService: ✅✅✅ Using designation from employees/designations table: "${designation.trim()}" ✅✅✅');
                print('ProfileService: 📋 Previous designation was: ${profileBase['designation']}');
              } else {
                print('ProfileService: ⚠️⚠️⚠️ WARNING: No designation found in employees or designations table! ⚠️⚠️⚠️');
                print('ProfileService: ⚠️ Current designation: ${profileBase['designation']}');
                print('ProfileService: 💡 This might indicate:');
                print('ProfileService:     1. The employee record in employees table is missing designation');
                print('ProfileService:     2. The designation field uses a different column name');
                print('ProfileService:     3. The employee_id in user_profiles points to wrong record');
                print('ProfileService:     4. The designation_id exists but the designations table record is missing');
              }
              
              // Always prioritize status from employees table
              final status = employeeData['status'] as String?;
              if (status != null && status.isNotEmpty && status.trim().isNotEmpty) {
                mergedData['status'] = status.trim().toUpperCase();
                print('ProfileService: ✅✅✅ Using status from employees table: "${status.trim().toUpperCase()}" ✅✅✅');
              } else {
                // Fallback to is_active if status not available
                final isActive = employeeData['is_active'] as bool?;
                if (isActive != null) {
                  mergedData['status'] = isActive ? 'ACTIVE' : 'INACTIVE';
                  print('ProfileService: ✅ Using status from is_active: ${mergedData['status']}');
                } else {
                  print('ProfileService: ⚠️ No status or is_active found in employees table');
                }
              }
              
              // Always prioritize date_of_joining from employees table
              print('ProfileService: 🔍 Checking date_of_joining in employeeData:');
              print('  - date_of_joining: ${employeeData['date_of_joining']}');
              print('  - joining_date: ${employeeData['joining_date']}');
              print('  - doj: ${employeeData['doj']}');
              print('  - start_date: ${employeeData['start_date']}');
              
              final dateOfJoining = employeeData['date_of_joining'] as String? ??
                                   employeeData['joining_date'] as String? ??
                                   employeeData['doj'] as String? ??
                                   employeeData['start_date'] as String?;
              
              if (dateOfJoining != null && dateOfJoining.isNotEmpty && dateOfJoining != 'null') {
                mergedData['date_of_joining'] = dateOfJoining;
                mergedData['joining_date'] = dateOfJoining; // Also set for compatibility
                print('ProfileService: ✅✅✅ Using date_of_joining from employees table: "$dateOfJoining" ✅✅✅');
                print('ProfileService: 📋 Previous date_of_joining was: ${profileBase['date_of_joining']}');
              } else {
                print('ProfileService: ⚠️⚠️⚠️ WARNING: No date_of_joining found in employees table! ⚠️⚠️⚠️');
                print('ProfileService: ⚠️ Current date_of_joining: ${profileBase['date_of_joining']}');
                print('ProfileService: 💡 This might indicate:');
                print('ProfileService:     1. The employee record in employees table is missing date_of_joining');
                print('ProfileService:     2. The date_of_joining field uses a different column name');
                print('ProfileService:     3. The employee_id in user_profiles points to wrong record');
              }
              
              print('ProfileService: ✅ Merged profile data ready');
              print('ProfileService: 📋 Final merged data - full_name: ${mergedData['full_name']}, designation: ${mergedData['designation']}, status: ${mergedData['status']}, date_of_joining: ${mergedData['date_of_joining']}');
              return mergedData;
          } else {
            print('ProfileService: ⚠️ No employee data found for employee_id: $employeeId');
          }
        } catch (e, stackTrace) {
          print('ProfileService: ❌ Error fetching/merging employee data: $e');
          print('ProfileService: Stack trace: $stackTrace');
          // Continue with user_profiles data only if employee fetch fails
        }
        
        return profileBase;
      } catch (e, stackTrace) {
        print('ProfileService: ❌ Error fetching user profile: $e');
        print('ProfileService: Stack trace: $stackTrace');
        return null;
      }
    }

  // Fetch organization details
  Future<Map<String, dynamic>?> getOrganization(String organizationId) async {
    try {
      final data = await supabase
          .from('organizations')
          .select()
          .eq('id', organizationId)
          .maybeSingle();
      
      // If logo_url exists, try to get the public URL from Supabase storage
      if (data != null && data['logo_url'] != null) {
        final logoUrl = data['logo_url'] as String;
        try {
          // If it's already a full URL, use it as is
          if (logoUrl.startsWith('http://') || logoUrl.startsWith('https://')) {
            // Already a full URL, keep it
            data['logo_url'] = logoUrl;
          } else {
            // It's likely a storage path, try to get public URL from different buckets
            final buckets = ['organizations', 'company-logos', 'logos', 'public'];
            String? publicUrl;
            
            for (final bucket in buckets) {
              try {
                // Remove leading slash if present
                final cleanPath = logoUrl.startsWith('/') ? logoUrl.substring(1) : logoUrl;
                publicUrl = supabase.storage.from(bucket).getPublicUrl(cleanPath);
                // Test if URL is accessible (optional - can be removed if too slow)
                data['logo_url'] = publicUrl;
                break;
              } catch (e) {
                // Try next bucket
                continue;
              }
            }
            
            // If all buckets failed, use the original path
            if (publicUrl == null) {
              data['logo_url'] = logoUrl;
            }
          }
        } catch (e) {
          print('Error getting logo public URL: $e');
          // Keep original logo_url
        }
      }
      
      return data;
    } catch (e) {
      print('Error fetching organization: $e');
      return null;
    }
  }

  // Fetch departments for an organization
  Future<List<Map<String, dynamic>>> getDepartments(String organizationId) async {
    try {
      final data = await supabase
          .from('departments')
          .select()
          .eq('organization_id', organizationId)
          .order('name');
      
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('Error fetching departments: $e');
      return [];
    }
  }

  // Get employee count for organization
  Future<int> getEmployeeCount(String organizationId) async {
    try {
      final data = await supabase
          .from('user_profiles')
          .select('id')
          .eq('organization_id', organizationId)
          .eq('is_active', true);
      
      return data.length;
    } catch (e) {
      print('Error fetching employee count: $e');
      return 0;
    }
  }

  // Get department employee count
  // Uses employees table to find employees by department_id, then counts matching user_profiles
  Future<int> getDepartmentEmployeeCount(String departmentId) async {
    try {
      // Primary approach: Use employees table with department_id
      // employees.id is the employee_id, and employees.department_id links to departments
      try {
        final employeesData = await supabase
            .from('employees')
            .select('id')
            .eq('department_id', departmentId)
            .eq('is_active', true);
        
        if (employeesData.isNotEmpty) {
          // Get employee_ids (which are employees.id)
          final employeeIds = employeesData
              .map((e) => e['id'] as String?)
              .whereType<String>()
              .toList();
          
          if (employeeIds.isNotEmpty) {
            // Count matching user_profiles where employee_id matches
            try {
              final profiles = await supabase
                  .from('user_profiles')
                  .select('id')
                  .inFilter('employee_id', employeeIds)
                  .eq('is_active', true);
              
              return profiles.length;
            } catch (e) {
              // Fallback: fetch all and filter in code if inFilter fails
              final allProfiles = await supabase
                  .from('user_profiles')
                  .select('id, employee_id')
                  .eq('is_active', true)
                  .limit(1000);
              
              final matchingProfiles = allProfiles
                  .where((profile) {
                    final empId = profile['employee_id'] as String?;
                    return empId != null && employeeIds.contains(empId);
                  })
                  .toList();
              
              return matchingProfiles.length;
            }
          }
        }
        
        // If no employees found in employees table, return 0
        return 0;
      } catch (e) {
        // If employees table doesn't exist or query fails, return 0 silently
        // This is expected if the schema doesn't have an employees table
        return 0;
      }
    } catch (e) {
      // Any other error, return 0
      return 0;
    }
  }

  // Get employees for a specific department
  Future<List<Map<String, dynamic>>> getDepartmentEmployees(
    String departmentId, {
    String? currentUserId,
    String? currentEmployeeId,
  }) async {
    try {
      // Step 1: Get employee IDs from employees table for this department
      List<dynamic> employeesData;
      try {
        employeesData = await supabase
            .from('employees')
            .select('id')
            .eq('department_id', departmentId)
            .eq('is_active', true);
      } catch (e) {
        print('Error fetching from employees table: $e');
        return [];
      }
      
      if (employeesData.isEmpty) {
        return [];
      }
      
      final employeeIds = employeesData
          .map((e) => e['id'] as String?)
          .whereType<String>()
          .toList();
      
      if (employeeIds.isEmpty) {
        return [];
      }
      
      // Step 2: Fetch user_profiles for these employee_ids
      List<dynamic> profiles;
      try {
        profiles = await supabase
            .from('user_profiles')
            .select('full_name, employee_id')
            .inFilter('employee_id', employeeIds)
            .eq('is_active', true)
            .limit(1000);
      } catch (e) {
        // Fallback: fetch all and filter
        final allProfiles = await supabase
            .from('user_profiles')
            .select('full_name, employee_id')
            .eq('is_active', true)
            .limit(1000);
        
        profiles = allProfiles
            .where((profile) {
              final empId = profile['employee_id'] as String?;
              return empId != null && employeeIds.contains(empId);
            })
            .toList();
      }
      
      // Step 3: Check if current employee is in this department and add if not already included
      final currentEmployeeInList = currentEmployeeId != null &&
          employeeIds.contains(currentEmployeeId);
      
      if (!currentEmployeeInList && currentEmployeeId != null && currentUserId != null) {
        // Check if current employee belongs to this department
        try {
          final currentEmpData = await supabase
              .from('employees')
              .select('id, department_id')
              .eq('id', currentEmployeeId)
              .maybeSingle();
          
          if (currentEmpData != null) {
            final currentEmpDeptId = currentEmpData['department_id'] as String?;
            if (currentEmpDeptId == departmentId) {
              // Current employee is in this department, add to employeeIds
              employeeIds.add(currentEmployeeId);
              
              // Fetch current user's profile
              try {
                final currentProfile = await supabase
                    .from('user_profiles')
                    .select('full_name, employee_id')
                    .eq('user_id', currentUserId)
                    .eq('is_active', true)
                    .maybeSingle();
                
                if (currentProfile != null) {
                  // Add current employee to profiles list if not already there
                  final alreadyInList = profiles.any((p) => 
                    p['employee_id'] == currentEmployeeId
                  );
                  
                  if (!alreadyInList) {
                    profiles.add(currentProfile);
                  }
                }
              } catch (e) {
                print('Error fetching current user profile: $e');
              }
            }
          }
        } catch (e) {
          print('Error checking current employee department: $e');
        }
      }
      
      // Step 4: For each profile, fetch the employee name and code from employees table
      final result = <Map<String, dynamic>>[];
      
      for (var profile in profiles) {
        final empId = profile['employee_id'] as String?;
        String name = profile['full_name'] as String? ?? 'Unknown';
        
        if (empId == null) continue;
        
        // Fetch employee name and code from employees table
        String empCode = 'N/A';
        try {
          final empData = await supabase
              .from('employees')
              .select()
              .eq('id', empId)
              .maybeSingle();
          
          if (empData != null) {
            // PRIORITIZE: Construct name from first_name and last_name if they exist
            final firstName = empData['first_name'] as String?;
            final lastName = empData['last_name'] as String?;
            String? constructedName;
            
            if (firstName != null && firstName.trim().isNotEmpty) {
              constructedName = firstName.trim();
              if (lastName != null && lastName.trim().isNotEmpty) {
                constructedName = '$constructedName ${lastName.trim()}';
              }
            }

            // Get name from employees table (prioritize this)
            final empName = constructedName ??
                          empData['full_name'] as String? ?? 
                          empData['name'] as String? ??
                          empData['employee_name'] as String? ??
                          empData['display_name'] as String?;
            
            if (empName != null && empName.isNotEmpty && empName.trim().isNotEmpty) {
              name = empName.trim();
              print('ProfileService: Using employee name from employees table: $name');
            }
            
            // Get employee code
            empCode = empData['employee_code'] as String? ?? 'N/A';
            
            // If it's empty or a UUID (36 chars with dashes), use N/A
            // Formatted codes like "EMP-20260102-001" are shorter (15-20 chars)
            final isUUID = empCode.length >= 30 && 
                           empCode.contains('-') && 
                           RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false).hasMatch(empCode);
            
            if (empCode.isEmpty || empCode == 'N/A' || isUUID) {
              empCode = 'N/A';
            }
          }
        } catch (e) {
          print('ProfileService: Error fetching employee data: $e');
          // If employee_code column doesn't exist, try to use employee_id from user_profiles
          // which might already be formatted
          final profileEmpId = profile['employee_id'] as String?;
          if (profileEmpId != null && 
              !profileEmpId.contains('-') && 
              profileEmpId.length < 20) {
            empCode = profileEmpId;
          } else {
            empCode = 'N/A';
          }
        }
        
        final isCurrentEmployee = empId == currentEmployeeId;
        
        result.add({
          'full_name': name,
          'employee_id': empCode,
          'is_current_user': isCurrentEmployee,
        });
      }
      
      // Sort by name
      result.sort((a, b) {
        final nameA = (a['full_name'] as String? ?? '').toLowerCase();
        final nameB = (b['full_name'] as String? ?? '').toLowerCase();
        return nameA.compareTo(nameB);
      });
      
      return result;
    } catch (e) {
      print('Error fetching department employees: $e');
      return [];
    }
  }

  // Get formatted employee code for a user
  Future<String> getFormattedEmployeeCode(String employeeId) async {
    if (employeeId.isEmpty || employeeId == 'N/A') {
      return 'N/A';
    }
    
    // Check if employeeId itself is already formatted (not a UUID)
    // UUIDs are typically 36 characters: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    // Formatted codes like "EMP-20260102-001" are shorter (15-20 chars)
    final isUUID = employeeId.length >= 30 && 
                   employeeId.contains('-') && 
                   RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false).hasMatch(employeeId);
    
    if (!isUUID && employeeId.length < 30) {
      // Already formatted (not a UUID)
      return employeeId;
    }
    
    // If it's a UUID, fetch the formatted code from employees table
    try {
      final empData = await supabase
          .from('employees')
          .select('employee_code')
          .eq('id', employeeId)
          .maybeSingle();
      
      if (empData != null) {
        final empCode = empData['employee_code'] as String?;
        if (empCode != null && empCode.isNotEmpty) {
          // Accept if it's not a UUID (UUIDs are 36 chars, formatted codes are shorter)
          if (empCode.length < 30) {
            return empCode;
          }
        }
      }
    } catch (e) {
      print('Error fetching employee code from employees table: $e');
    }
    
    return 'N/A';
  }

  // Update user profile
  Future<bool> updateProfile(String userId, Map<String, dynamic> updates) async {
    try {
      print('ProfileService: Updating profile for user_id: $userId');
      print('ProfileService: Updates: $updates');
      
      final fieldMapping = {
        'full_name': ['full_name', 'name', 'employee_name'],
        'email': ['email', 'company_email', 'work_email'],
        'phone': ['phone', 'mobile', 'contact_number'],
        'mobile': ['mobile', 'phone'],
        'designation': ['designation', 'position', 'job_title'],
        'avatar_url': ['avatar_url', 'profile_picture', 'image_url'],
        'pan': ['pan', 'pan_number'],
        'aadhaar': ['aadhaar', 'aadhaar_number'],
        'uan': ['uan', 'uan_number'],
        'bank_name': ['bank_name'],
        'account_number': ['account_number', 'account_no', 'bank_account_no', 'bank_acc_no', 'bank_account_number'],
        'ifsc_code': ['ifsc_code', 'ifsc'],
        'bank_branch': ['bank_branch', 'branch_name', 'branch'],
        'highest_qualification': ['highest_qualification', 'qualification', 'education', 'degree'],
        'university': ['university', 'institution', 'college', 'school', 'university_name'],
        'specialization': ['specialization', 'field', 'stream', 'field_of_study'],
        'year_of_completion': ['year_of_completion', 'completion_year', 'pass_out_year', 'graduation_year'],
      };

      // 1. Update user_profiles table
      bool userProfileUpdated = false;
      try {
        // First, try to get the current profile to see what columns exist
        Map<String, dynamic>? existingProfile;
        try {
          existingProfile = await supabase
              .from('user_profiles')
              .select()
              .eq('user_id', userId)
              .maybeSingle();
        } catch (e) {
          print('ProfileService: Error fetching existing profile: $e');
        }
        
        // Filter updates to only include fields that exist in the table
        final filteredUpdates = <String, dynamic>{};
        
        if (existingProfile != null) {
          final existingKeys = existingProfile.keys.toSet();
          updates.forEach((key, value) {
            // Check if key exists directly or through mapping
            if (key == 'updated_at' || existingKeys.contains(key)) {
              filteredUpdates[key] = value;
            } else if (fieldMapping.containsKey(key)) {
              for (final mapKey in fieldMapping[key]!) {
                if (existingKeys.contains(mapKey)) {
                  filteredUpdates[mapKey] = value;
                  break; // Use the first matching key
                }
              }
            } else {
              print('ProfileService: Skipping field "$key" for user_profiles - column does not exist');
            }
          });
        } else {
          filteredUpdates.addAll(updates);
        }
        
        if (filteredUpdates.isNotEmpty) {
          final response = await supabase
              .from('user_profiles')
              .update(filteredUpdates)
              .eq('user_id', userId)
              .select();
          userProfileUpdated = response.isNotEmpty;
          print('ProfileService: user_profiles update successful: $userProfileUpdated');
        }
      } catch (e) {
        print('ProfileService: Error updating user_profiles: $e');
      }

      // 2. Synchronize with employees table if applicable
      bool employeesUpdated = false;
      try {
        // Find the linked employee record
        final profile = await supabase
            .from('user_profiles')
            .select('employee_id')
            .eq('user_id', userId)
            .maybeSingle();
            
        final employeeId = profile?['employee_id'] as String?;
        if (employeeId != null && employeeId.isNotEmpty) {
          print('ProfileService: Synchronizing updates to employees table for employee_id: $employeeId');
          
          // Map user_profiles fields to employees fields if they differ
          final employeeUpdates = <String, dynamic>{};

          // Check which columns exist in employees table
          final existingEmployee = await supabase.from('employees').select().eq('id', employeeId).maybeSingle();
          if (existingEmployee != null) {
            final empKeys = existingEmployee.keys.toSet();
            
            updates.forEach((key, value) {
              if (fieldMapping.containsKey(key)) {
                for (final empKey in fieldMapping[key]!) {
                  if (empKeys.contains(empKey)) {
                    employeeUpdates[empKey] = value;
                  }
                }
              } else if (empKeys.contains(key)) {
                employeeUpdates[key] = value;
              }
            });

            if (employeeUpdates.isNotEmpty) {
              final response = await supabase.from('employees').update(employeeUpdates).eq('id', employeeId).select();
              employeesUpdated = response.isNotEmpty;
              print('ProfileService: Successfully synchronized keys to employees: ${employeeUpdates.keys.toList()}');
            }
          }
        }
      } catch (e) {
        print('ProfileService: Warning - Sync with employees table failed: $e');
      }
      
      // Return true if either update succeeded
      return userProfileUpdated || employeesUpdated;
    } catch (e) {
      print('ProfileService: Critical error updating profile: $e');
      return false;
    }
  }

  /// Upload avatar image to Supabase storage
  Future<String?> uploadAvatar(String userId, List<int> imageBytes, String fileName) async {
    try {
      print('ProfileService: Starting avatar upload for user $userId, file: $fileName');
      
      final String path = '$userId/$fileName';
      final Uint8List bytesArray = Uint8List.fromList(imageBytes);
      
      // Get organization_id for dynamic bucket guessing
      String? organizationId;
      try {
        final profile = await getUserProfile(userId);
        organizationId = profile?['organization_id'] as String?;
      } catch (e) {
        print('ProfileService: Could not fetch organization_id for bucket guessing: $e');
      }

      // Try multiple bucket names in order of likelihood
      final buckets = [
        if (organizationId != null) organizationId,
        'avatars', 
        'profiles', 
        'public', 
        'employees',
        'organizations',
        'company-logos',
        'logos',
        'holiday-calendars',
        'holidays',
        'documents',
        'images',
        'storage',
        'files'
      ];
      
      String? successfulBucket;
      
      for (final bucket in buckets) {
        try {
          print('ProfileService: Attempting upload to bucket "$bucket"...');
          await supabase.storage.from(bucket).uploadBinary(
            path,
            bytesArray,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
          successfulBucket = bucket;
          print('ProfileService: ✅ Upload successful to bucket "$bucket"');
          break;
        } catch (e) {
          // If we explicitly get "Bucket not found", we continue. 
          // Other errors might be permissions (403), we still try others.
          print('ProfileService: ❌ Upload failed for bucket "$bucket": $e');
          continue;
        }
      }
      
      if (successfulBucket == null) {
        throw Exception('Could not upload to any of the available buckets: $buckets');
      }
      
      // Get public URL
      final String publicUrl = supabase.storage.from(successfulBucket).getPublicUrl(path);
      print('ProfileService: Public URL generated: $publicUrl');
      
      // Update user profile and employees table with the FULL public URL
      // This is the most reliable way to ensure the UI can display the image immediately
      final success = await updateProfile(userId, {'avatar_url': publicUrl});
      
      if (success) {
        print('ProfileService: ✅ Avatar records updated with full URL: $publicUrl');
        return publicUrl;
      } else {
        print('ProfileService: ⚠️ Avatar uploaded but failed to update database records');
        return publicUrl;
      }
    } catch (e) {
      print('ProfileService: ❌ Critical error in uploadAvatar: $e');
      return null;
    }
  }
}


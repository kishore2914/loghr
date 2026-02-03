import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:loghr_mobile/config/supabase_config.dart';
import 'package:loghr_mobile/utils/helpers.dart';

class PdfService {
  // Cache for loaded font
  pw.Font? _unicodeFont;
  bool _fontLoadAttempted = false;

  // Load a Unicode-compatible font that supports Rupee symbol
  Future<pw.Font?> _loadUnicodeFont() async {
    if (_fontLoadAttempted) return _unicodeFont;
    _fontLoadAttempted = true;

    try {
      // Try to load Noto Sans or another Unicode font from assets
      // You need to download Noto Sans from https://fonts.google.com/noto
      // and place it in assets/fonts/NotoSans-Regular.ttf
      final fontData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
      _unicodeFont = pw.Font.ttf(fontData);
      print('Unicode font loaded successfully');
      return _unicodeFont;
    } catch (e) {
      print('Could not load Unicode font from assets: $e');
      print('Using default font - Rupee symbol may not render correctly');
      print('To fix: Download Noto Sans from https://fonts.google.com/noto and place in assets/fonts/');
      return null;
    }
  }

  Future<void> generatePayslipPdf({
    required Map<String, dynamic> payslipData,
    required String employeeName,
    required String employeeCode,
    required String payPeriod,
    String? payPeriodStart,
    String? payPeriodEnd,
    String? organizationName,
    String location = 'Qatar',
    String? userId, // Add userId to fetch name if needed
  }) async {
    // Get organization name from payslip data if not provided
    String finalOrganizationName = organizationName ?? 
                                   payslipData['company_name'] as String? ??
                                   'LogHR';
    final pdf = pw.Document();
    final currency = payslipData['currency'] as String? ?? 'INR';
    
    // Try to load Unicode font for Rupee symbol
    final unicodeFont = await _loadUnicodeFont();
    
    // Use Rupee symbol (₹) for INR currency if font is available, otherwise use "Rs."
    // To get ₹ symbol working: Download Noto Sans from https://fonts.google.com/noto
    // and place NotoSans-Regular.ttf in assets/fonts/
    final currencySymbol = currency == 'INR' 
        ? (unicodeFont != null ? '₹' : 'Rs.') 
        : (currency == 'QAR' ? 'QAR' : currency);
    
    // Always try to fetch employee name and code to ensure we have the correct ones
    String finalEmployeeName = employeeName.trim();
    String finalEmployeeCode = employeeCode.trim();
    
    print('PDF Generation - Initial employee name: "$finalEmployeeName"');
    print('PDF Generation - Initial employee code: "$finalEmployeeCode"');
    print('PDF Generation - userId parameter: $userId');
    
    // Check if employee code is a UUID (common fallback issue)
    final uuidRegex = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);
    bool isUuid = uuidRegex.hasMatch(finalEmployeeCode);
    
    // Always try to fetch the name and code if they seem invalid
    bool shouldFetch = finalEmployeeName.isEmpty || 
                      finalEmployeeName == 'N/A' || 
                      finalEmployeeName == 'Employee' ||
                      finalEmployeeName.length < 2 ||
                      isUuid ||
                      finalEmployeeCode == 'N/A';
    
    if (shouldFetch) {
      try {
        String? idToFetch = userId;
        
        // If userId not provided, try to get from payroll data's user_id
        if (idToFetch == null && payslipData.containsKey('user_id')) {
          idToFetch = payslipData['user_id'] as String?;
          print('Using user_id from payroll data: $idToFetch');
        }
        
        // Try to get name and code from user_profiles and employees table
        if (idToFetch != null) {
          print('Fetching profile info for user_id: $idToFetch');
          
          // First get the profile to get employee_id (foreign key)
          final profile = await supabase
              .from('user_profiles')
              .select('full_name, employee_id')
              .eq('user_id', idToFetch)
              .maybeSingle();
          
          print('Profile query result: $profile');
          
          if (profile != null) {
            // Update name if invalid
            if (profile['full_name'] != null) {
              final name = profile['full_name'] as String;
              if (name.trim().isNotEmpty && name.trim() != 'Employee') {
                finalEmployeeName = name.trim();
                print('✓ Successfully fetched employee name from database: "$finalEmployeeName"');
              }
            }
            
            // Get the actual employee code and name from employees table
            final empId = profile['employee_id'] as String?;
            if (empId != null) {
              print('PDF Service: 🔍 Fetching employee details from employees table for employee_id: $empId');
              try {
                // Try to get full employee record from employees table
                final employee = await supabase
                    .from('employees')
                    .select()
                    .eq('id', empId)
                    .maybeSingle();
                
                print('PDF Service: 📋 Employee query result: $employee');
                
                if (employee != null) {
                  // ALWAYS prioritize employee name from employees table
                  final empName = employee['full_name'] as String? ?? 
                                employee['name'] as String? ??
                                employee['first_name'] as String? ??
                                employee['employee_name'] as String?;
                  
                  if (empName != null && empName.isNotEmpty && empName.trim().isNotEmpty) {
                    finalEmployeeName = empName.trim();
                    print('PDF Service: ✅✅✅ Using employee name from employees table: "$finalEmployeeName" ✅✅✅');
                  }
                  
                  // Try employee_code first, then code, then id
                  String? code = employee['employee_code'] as String?;
                  if (code == null || code.isEmpty) {
                    code = employee['code'] as String?;
                  }
                  if (code == null || code.isEmpty) {
                    code = employee['id'] as String?;
                  }
                  
                  if (code != null && code.trim().isNotEmpty && !uuidRegex.hasMatch(code)) {
                    finalEmployeeCode = code.trim();
                    print('PDF Service: ✅ Successfully fetched actual employee code from employees table: "$finalEmployeeCode"');
                  } else if (code != null && uuidRegex.hasMatch(code)) {
                    // If still UUID, generate from name
                    if (finalEmployeeName.isNotEmpty && finalEmployeeName != 'Employee') {
                      finalEmployeeCode = Helpers.generateEmployeeCode(finalEmployeeName);
                      print('PDF Service: ⚠️ Employee code is UUID, generated from name: "$finalEmployeeCode"');
                    }
                  }
                }
              } catch (e) {
                print('PDF Service: ❌ Error fetching from employees table: $e');
                // Fallback: if employee_id in profile is not a UUID, use it
                if (!uuidRegex.hasMatch(empId)) {
                  finalEmployeeCode = empId;
                  print('PDF Service: Using employee_id from profile as code: "$finalEmployeeCode"');
                }
              }
            }
          }
        }
        
        // If name still empty, try to get from payroll data's employee_name field
        if (finalEmployeeName.isEmpty && payslipData.containsKey('employee_name')) {
          final name = payslipData['employee_name'] as String?;
          if (name != null && name.trim().isNotEmpty) {
            finalEmployeeName = name;
            print('Using employee_name from payroll data: $finalEmployeeName');
          }
        }
        
        // Fallback for code if still UUID/empty
        if (finalEmployeeCode.isEmpty || uuidRegex.hasMatch(finalEmployeeCode)) {
          // If we have a name, we can "emergency generate" one if it's still a UUID in DB
          if (finalEmployeeName.isNotEmpty && finalEmployeeName != 'Employee') {
            finalEmployeeCode = Helpers.generateEmployeeCode(finalEmployeeName);
            print('⚠ Emergency generated code: "$finalEmployeeCode"');
          }
        }
        
        // Try to get from current auth user if still "Employee" (for name)
        if (finalEmployeeName.isEmpty || finalEmployeeName == 'Employee' || finalEmployeeCode.isEmpty || uuidRegex.hasMatch(finalEmployeeCode)) {
          try {
            final currentUser = supabase.auth.currentUser;
            if (currentUser != null) {
              final profile = await supabase
                  .from('user_profiles')
                  .select('full_name, employee_id')
                  .eq('user_id', currentUser.id)
                  .maybeSingle();
              
              if (profile != null) {
                // Update name
                if ((finalEmployeeName.isEmpty || finalEmployeeName == 'Employee') && profile['full_name'] != null) {
                  final name = profile['full_name'] as String;
                  if (name.trim().isNotEmpty && name.trim() != 'Employee') {
                    finalEmployeeName = name.trim();
                    print('✓ Fetched name from current user profile: "$finalEmployeeName"');
                  }
                }
                
                // Get employee code from employees table
                final empId = profile['employee_id'] as String?;
                if (empId != null && (finalEmployeeCode.isEmpty || uuidRegex.hasMatch(finalEmployeeCode))) {
                  try {
                    final employee = await supabase
                        .from('employees')
                        .select('employee_code, code, id')
                        .eq('id', empId)
                        .maybeSingle();
                    
                    if (employee != null) {
                      String? code = employee['employee_code'] as String?;
                      if (code == null || code.isEmpty) {
                        code = employee['code'] as String?;
                      }
                      if (code != null && code.trim().isNotEmpty && !uuidRegex.hasMatch(code)) {
                        finalEmployeeCode = code.trim();
                        print('✓ Fetched employee code from employees table: "$finalEmployeeCode"');
                      } else if (finalEmployeeName.isNotEmpty && finalEmployeeName != 'Employee') {
                        finalEmployeeCode = Helpers.generateEmployeeCode(finalEmployeeName);
                        print('⚠ Generated employee code from name: "$finalEmployeeCode"');
                      }
                    }
                  } catch (e) {
                    print('Error fetching employee code: $e');
                  }
                }
              }
            }
          } catch (e) {
            print('❌ Error fetching from current user: $e');
          }
        }
        
        // Final fallback
        if (finalEmployeeName.isEmpty || finalEmployeeName == 'Employee') {
          finalEmployeeName = 'Employee ($finalEmployeeCode)';
        }
      } catch (e) {
        print('Error fetching profile details: $e');
      }
    }
    
    print('Final employee name to use in PDF: $finalEmployeeName');
    print('Final employee code to use in PDF: $finalEmployeeCode');
    
    // Fetch company name and logo from organizations table
    String? companyLogoUrl;
    print('PDF Service: Starting organization fetch. Current name: $finalOrganizationName');
    
    try {
      // First, get organization_id from user profile
      String? organizationId;
      if (userId != null) {
        try {
          print('PDF Service: Fetching organization_id for userId: $userId');
          final profile = await supabase
              .from('user_profiles')
              .select('organization_id')
              .eq('user_id', userId)
              .maybeSingle();
          
          print('PDF Service: Profile result: $profile');
          if (profile != null) {
            organizationId = profile['organization_id'] as String?;
            print('PDF Service: Found organization_id: $organizationId');
          }
        } catch (e) {
          print('PDF Service: Error fetching organization_id from user profile: $e');
        }
      }
      
      // If still no organization_id, try to get from current user
      if (organizationId == null) {
        try {
          final currentUser = supabase.auth.currentUser;
          if (currentUser != null) {
            print('PDF Service: Trying current user: ${currentUser.id}');
            final profile = await supabase
                .from('user_profiles')
                .select('organization_id')
                .eq('user_id', currentUser.id)
                .maybeSingle();
            
            if (profile != null) {
              organizationId = profile['organization_id'] as String?;
              print('PDF Service: Found organization_id from current user: $organizationId');
            }
          }
        } catch (e) {
          print('PDF Service: Error fetching organization_id from current user: $e');
        }
      }
      
      // Also try to get organization_id from payroll data
      if (organizationId == null && payslipData.containsKey('organization_id')) {
        organizationId = payslipData['organization_id'] as String?;
        print('PDF Service: Found organization_id from payslip data: $organizationId');
      }
      
      // Try to get organization_id from employees table via employee_id
      if (organizationId == null && userId != null) {
        try {
          final profile = await supabase
              .from('user_profiles')
              .select('employee_id')
              .eq('user_id', userId)
              .maybeSingle();
          
          if (profile != null && profile['employee_id'] != null) {
            final employeeId = profile['employee_id'] as String;
            print('PDF Service: Found employee_id: $employeeId, fetching organization_id');
            
            final employee = await supabase
                .from('employees')
                .select('organization_id')
                .eq('id', employeeId)
                .maybeSingle();
            
            if (employee != null && employee['organization_id'] != null) {
              organizationId = employee['organization_id'] as String;
              print('PDF Service: Found organization_id from employees table: $organizationId');
            }
          }
        } catch (e) {
          print('PDF Service: Error fetching organization_id from employees: $e');
        }
      }
      
      // Fetch organization data
      if (organizationId != null && organizationId.isNotEmpty) {
        try {
          print('PDF Service: Fetching organization data for id: $organizationId');
          // Use select() without explicit column list so we don't break
          // when optional columns like company_name or logo_url are missing.
          final orgData = await supabase
              .from('organizations')
              .select()
              .eq('id', organizationId)
              .maybeSingle();
          
          print('PDF Service: Organization data result: $orgData');
          if (orgData != null) {
            // Always update company name from organizations table (override any existing value)
            final orgName = (orgData['company_name'] as String?) ?? 
                            (orgData['organization_name'] as String?) ??
                            (orgData['name'] as String?);
            
            if (orgName != null && orgName.isNotEmpty && orgName.trim().isNotEmpty) {
              finalOrganizationName = orgName.trim();
              print('PDF Service: Updated company name to: $finalOrganizationName');
            } else {
              print('PDF Service: Organization name is null or empty in database');
            }
            
            // Get logo URL (always try to fetch if available)
            final logoUrl = orgData['logo_url'] as String?;
            print('PDF Service: Logo URL from database: $logoUrl');
            if (logoUrl != null && logoUrl.isNotEmpty) {
              // If it's already a full URL, use it as is
              if (logoUrl.startsWith('http://') || logoUrl.startsWith('https://')) {
                companyLogoUrl = logoUrl;
                print('PDF Service: Using full URL for logo: $companyLogoUrl');
              } else {
                // Try to get public URL from storage buckets
                final buckets = ['organizations', 'company-logos', 'logos', 'public'];
                for (final bucket in buckets) {
                  try {
                    final cleanPath = logoUrl.startsWith('/') ? logoUrl.substring(1) : logoUrl;
                    companyLogoUrl = supabase.storage.from(bucket).getPublicUrl(cleanPath);
                    print('PDF Service: Generated logo URL from bucket $bucket: $companyLogoUrl');
                    break;
                  } catch (e) {
                    print('PDF Service: Failed to get URL from bucket $bucket: $e');
                    continue;
                  }
                }
              }
            } else {
              print('PDF Service: No logo URL found in organization data');
            }
          } else {
            print('PDF Service: No organization data found for id: $organizationId');
          }
        } catch (e) {
          print('PDF Service: Error fetching organization data: $e');
        }
      } else {
        print('PDF Service: No organization_id found. userId: $userId');
      }
      
      // Fallback: try to fetch first organization if no organization_id found OR if name is still LogHR
      if (organizationId == null || finalOrganizationName == 'LogHR' || finalOrganizationName.isEmpty) {
        try {
          print('PDF Service: Trying to fetch first organization as fallback');
          final orgs = await supabase
              .from('organizations')
              .select()
              .limit(1)
              .maybeSingle();
          
          print('PDF Service: First organization result: $orgs');
          if (orgs != null) {
            final orgName = (orgs['company_name'] as String?) ?? 
                            (orgs['organization_name'] as String?) ??
                            (orgs['name'] as String?);
            if (orgName != null && orgName.isNotEmpty && orgName.trim().isNotEmpty) {
              finalOrganizationName = orgName.trim();
              print('PDF Service: Updated company name from first organization: $finalOrganizationName');
            }
            
            // Also get logo if available
            final logoUrl = orgs['logo_url'] as String?;
            if (logoUrl != null && logoUrl.isNotEmpty && companyLogoUrl == null) {
              if (logoUrl.startsWith('http://') || logoUrl.startsWith('https://')) {
                companyLogoUrl = logoUrl;
              } else {
                final buckets = ['organizations', 'company-logos', 'logos', 'public'];
                for (final bucket in buckets) {
                  try {
                    final cleanPath = logoUrl.startsWith('/') ? logoUrl.substring(1) : logoUrl;
                    companyLogoUrl = supabase.storage.from(bucket).getPublicUrl(cleanPath);
                    break;
                  } catch (e) {
                    continue;
                  }
                }
              }
            }
          }
        } catch (e) {
          print('PDF Service: Error fetching first organization: $e');
        }
      }
      
      // Fallback: try organization_settings if organizations table didn't work
      if (finalOrganizationName == 'LogHR' || finalOrganizationName.isEmpty) {
        try {
          print('PDF Service: Trying organization_settings as fallback');
          final orgSettings = await supabase
              .from('organization_settings')
              .select('company_name, organization_name, name')
              .limit(1)
              .maybeSingle();
          
          if (orgSettings != null) {
            final orgName = orgSettings['company_name'] as String? ?? 
                          orgSettings['organization_name'] as String? ??
                          orgSettings['name'] as String?;
            if (orgName != null && orgName.isNotEmpty) {
              finalOrganizationName = orgName;
              print('PDF Service: Updated company name from organization_settings: $finalOrganizationName');
            }
          }
        } catch (e) {
          print('PDF Service: Error fetching organization settings: $e');
        }
      }
      
      print('PDF Service: Final organization name: $finalOrganizationName');
      print('PDF Service: Final logo URL: $companyLogoUrl');
    } catch (e) {
      print('PDF Service: Error fetching organization data: $e');
    }
    
    // Fetch employee designation and date of joining
    String designation = 'N/A';
    String dateOfJoining = 'N/A';
    
    try {
      String? employeeIdToFetch;
      
      // Get employee_id from user profile
      if (userId != null) {
        try {
          final profile = await supabase
              .from('user_profiles')
              .select('employee_id')
              .eq('user_id', userId)
              .maybeSingle();
          
          if (profile != null && profile['employee_id'] != null) {
            employeeIdToFetch = profile['employee_id'] as String;
          }
        } catch (e) {
          print('PDF Service: Error fetching employee_id: $e');
        }
      }
      
      // If still no employee_id, try current user
      if (employeeIdToFetch == null) {
        try {
          final currentUser = supabase.auth.currentUser;
          if (currentUser != null) {
            final profile = await supabase
                .from('user_profiles')
                .select('employee_id')
                .eq('user_id', currentUser.id)
                .maybeSingle();
            
            if (profile != null && profile['employee_id'] != null) {
              employeeIdToFetch = profile['employee_id'] as String;
            }
          }
        } catch (e) {
          print('PDF Service: Error fetching employee_id from current user: $e');
        }
      }
      
      // Fetch employee details
      if (employeeIdToFetch != null) {
        try {
          print('PDF Service: 🔍 Fetching employee details for PDF - employee_id: $employeeIdToFetch');
          
          // Try to fetch full employee record first
          Map<String, dynamic>? employee;
          try {
            employee = await supabase
                .from('employees')
                .select()
                .eq('id', employeeIdToFetch)
                .maybeSingle();
          } catch (e) {
            // If full select fails, try with explicit columns
            print('PDF Service: ⚠️ Full select failed, trying explicit columns: $e');
            try {
              employee = await supabase
                  .from('employees')
                  .select('id, designation, position, job_title, title, designation_id, date_of_joining, joining_date, start_date, doj')
                  .eq('id', employeeIdToFetch)
                  .maybeSingle();
            } catch (e2) {
              print('PDF Service: ❌ Explicit select also failed: $e2');
            }
          }
          
          if (employee != null) {
            print('PDF Service: ✅ Employee row for payslip: $employee');
            print('PDF Service: 📋 Employee keys: ${employee.keys.toList()}');
            
            // Get date of joining directly from employees table (check multiple field names)
            final dojRaw = employee['date_of_joining'] ??
                           employee['joining_date'] ??
                           employee['start_date'] ??
                           employee['doj'];
            final doj = dojRaw?.toString();
            
            print('PDF Service: 📋 Date of joining raw value: $doj');
            
            if (doj != null && doj.isNotEmpty && doj != 'null') {
              try {
                final date = DateTime.parse(doj);
                dateOfJoining = DateFormat('dd/MM/yyyy').format(date);
                print('PDF Service: ✅✅✅ Using date_of_joining from employees table: "$dateOfJoining" ✅✅✅');
              } catch (e) {
                dateOfJoining = doj; // Use as-is if parsing fails
                print('PDF Service: ⚠️ Could not parse date, using as-is: $doj');
              }
            } else {
              print('PDF Service: ⚠️ No date_of_joining found in employees table');
            }

            // FIRST: Try to get designation directly from employees table
            final directDesignation = employee['designation'] as String? ?? 
                                     employee['position'] as String? ??
                                     employee['job_title'] as String? ??
                                     employee['title'] as String?;
            
            print('PDF Service: 📋 Direct designation from employees table: $directDesignation');
            
            if (directDesignation != null && directDesignation.isNotEmpty && directDesignation.trim().isNotEmpty) {
              designation = directDesignation.trim();
              print('PDF Service: ✅✅✅ Using designation directly from employees table: "$designation" ✅✅✅');
            } else {
              // FALLBACK: Fetch designation name from designations table if designation_id exists
              final designationId = employee['designation_id'] as String?;
              if (designationId != null && designationId.isNotEmpty) {
                print('PDF Service: 🔍 Fetching designation from designations table - designation_id: $designationId');
                try {
                  final designationRow = await supabase
                      .from('designations')
                      .select()
                      .eq('id', designationId)
                      .maybeSingle();

                  print('PDF Service: 📋 Designation row: $designationRow');
                  if (designationRow != null) {
                    // Try multiple common keys first
                    final commonDesig = (designationRow['name'] as String?) ??
                                        (designationRow['title'] as String?) ??
                                        (designationRow['designation'] as String?) ??
                                        (designationRow['designation_name'] as String?);
                    String? picked = commonDesig;

                    // If still null/empty, fall back to first non-empty string field
                    if (picked == null || picked.trim().isEmpty) {
                      for (final entry in designationRow.entries) {
                        final value = entry.value;
                        if (value is String && value.trim().isNotEmpty) {
                          picked = value.trim();
                          print('PDF Service: Picked designation from column "${entry.key}": $picked');
                          break;
                        }
                      }
                    }

                    if (picked != null && picked.isNotEmpty) {
                      designation = picked;
                      print('PDF Service: ✅ Using designation from designations table: "$designation"');
                    }
                  } else {
                    print('PDF Service: ⚠️ No designation row found for id: $designationId');
                  }
                } catch (e) {
                  print('PDF Service: ❌ Error fetching designation from designations table: $e');
                }
              } else {
                print('PDF Service: ⚠️ designation_id is null for employee_id: $employeeIdToFetch');
              }
            }

            print('PDF Service: ✅✅✅ Final values - Designation: $designation, Date of Joining: $dateOfJoining ✅✅✅');
          } else {
            print('PDF Service: ⚠️ No employee data found for employee_id: $employeeIdToFetch');
          }
        } catch (e, stackTrace) {
          print('PDF Service: ❌ Error fetching employee details: $e');
          print('PDF Service: Stack trace: $stackTrace');
        }
      } else {
        print('PDF Service: ⚠️ No employee_id found to fetch designation and date of joining');
      }
    } catch (e) {
      print('PDF Service: Error in employee details fetch: $e');
    }
    
    print('PDF Service: Final values - Company: $finalOrganizationName, Designation: $designation, DOJ: $dateOfJoining');
    
    // Load logo image if available
    pw.ImageProvider? logoImage;
    if (companyLogoUrl != null && companyLogoUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(companyLogoUrl));
        if (response.statusCode == 200) {
          final imageBytes = response.bodyBytes;
          logoImage = pw.MemoryImage(imageBytes);
          print('Company logo loaded successfully');
        }
      } catch (e) {
        print('Error loading company logo: $e');
      }
    }
    
    // Use exact values from database - DO NOT RECALCULATE
    final basic = _toDouble(payslipData['basic_salary']) ?? 0.0;
    final medical = _toDouble(payslipData['medical_allowance']) ?? 
                    _toDouble(payslipData['medical']) ?? 0.0;
    
    // Sum up all OTHER earnings that aren't Basic or Medical into "Other Allowances"
    // This ensures the individual items sum up to Gross Salary in the PDF
    final da = _toDouble(payslipData['da']) ?? _toDouble(payslipData['dearness_allowance']) ?? 0.0;
    final hra = _toDouble(payslipData['hra']) ?? _toDouble(payslipData['house_rent_allowance']) ?? 0.0;
    final special = _toDouble(payslipData['special_allowance']) ?? _toDouble(payslipData['special']) ?? 0.0;
    final conveyance = _toDouble(payslipData['conveyance_allowance']) ?? _toDouble(payslipData['conveyance']) ?? 0.0;
    final bonus = _toDouble(payslipData['bonus']) ?? 0.0;
    final incentive = _toDouble(payslipData['incentive']) ?? 0.0;
    final overtime = _toDouble(payslipData['overtime_pay']) ?? _toDouble(payslipData['overtime']) ?? 0.0;
    final otherField = _toDouble(payslipData['other_allowance']) ?? _toDouble(payslipData['other_allowances']) ?? 0.0;
    
    final otherAllowance = da + hra + special + conveyance + bonus + incentive + overtime + otherField;
    
    final gross = _toDouble(payslipData['gross_salary']) ?? (basic + medical + otherAllowance);
    
    final pf = _toDouble(payslipData['pf']) ?? _toDouble(payslipData['pf_employee']) ?? 0.0;
    final esi = _toDouble(payslipData['esi']) ?? _toDouble(payslipData['esi_employee']) ?? 0.0;
    final professionalTax = _toDouble(payslipData['professional_tax']) ?? 0.0;
    final tds = _toDouble(payslipData['tds']) ?? 0.0;
    
    // Get working days and LOP from database
    final workingDays = payslipData['working_days'] as int? ?? 0;
    final totalWorkingDays = payslipData['total_working_days'] as int? ?? 30;
    final lopDays = totalWorkingDays - workingDays;
    
    // Use absence deduction from database if available, otherwise calculate
    final absenceDeduction = _toDouble(payslipData['absence_deduction']) ?? 0.0;
    
    // Total deductions: prefer database value, otherwise sum components
    final totalDeductions = _toDouble(payslipData['total_deductions']) ??
        (pf + esi + professionalTax + tds + absenceDeduction);
    
    // Use exact net_salary from database - DO NOT RECALCULATE
    final net = _toDouble(payslipData['net_salary']) ?? (gross - totalDeductions - absenceDeduction);
    
    // For YTD, use provided fields if available, else current month values
    double _ytd(String key, double fallback) {
      final candidates = [
        '${key}_ytd',
        'ytd_$key',
        '${key}Ytd',
        'year_to_date_$key',
      ];
      for (final c in candidates) {
        final v = payslipData[c];
        if (v is num) return v.toDouble();
      }
      return fallback;
    }

    final basicYtd = _ytd('basic_salary', basic);
    final medicalYtd = _ytd('medical_allowance', medical);
    final otherYtd = _ytd('other_allowance', otherAllowance);
    final grossYtd = _ytd('gross_salary', gross);
    final pfYtd = _ytd('pf', pf);
    final esiYtd = _ytd('esi', esi);
    final professionalTaxYtd = _ytd('professional_tax', professionalTax);
    final tdsYtd = _ytd('tds', tds);
    final absenceYtd = _ytd('absence_deduction', absenceDeduction);
    final totalDeductionsYtd = _ytd('total_deductions', totalDeductions);
    
    // Parse dates - use payment_date from database if available
    DateTime? paymentDate;
    
    // First try to use payment_date from database
    if (payslipData['payment_date'] != null) {
      try {
        paymentDate = DateTime.parse(payslipData['payment_date'] as String);
      } catch (e) {
        print('Error parsing payment_date: $e');
      }
    }
    
    // If not in database, calculate from pay_period_end
    if (paymentDate == null && payPeriodEnd != null) {
      try {
        final periodEnd = DateTime.parse(payPeriodEnd);
        paymentDate = periodEnd.add(const Duration(days: 1));
      } catch (e) {
        paymentDate = DateTime.now();
      }
    } else if (paymentDate == null) {
      paymentDate = DateTime.now();
    }
    
    // Format payment date
    final paymentDateStr = DateFormat('dd/MM/yyyy').format(paymentDate);
    
    // Generate filename
    final fileName = 'Payslip_${finalEmployeeCode}_${DateFormat('yyyyMMdd').format(paymentDate)}_${payPeriod.replaceAll(' ', '_')}.pdf';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(16),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header - Company Logo, Name and Payslip Title
              pw.Center(
                child: pw.Column(
                  children: [
                    // Company Logo (if available)
                    if (logoImage != null) ...[
                      pw.Image(
                        logoImage!,
                        width: 80,
                        height: 80,
                        fit: pw.BoxFit.contain,
                      ),
                      pw.SizedBox(height: 12),
                    ],
                    pw.Text(
                      finalOrganizationName,
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                        decoration: pw.TextDecoration.underline,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'PAYSLIP FOR THE MONTH OF ${payPeriod.toUpperCase()}',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                        letterSpacing: 0.5,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 24),
              
              // Employee Pay Summary Section (Boxed)
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300, width: 1),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Left Column
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildSummaryRow('Employee Name:', finalEmployeeName),
                          pw.SizedBox(height: 8),
                          _buildSummaryRow('Designation:', designation),
                          pw.SizedBox(height: 8),
                          _buildSummaryRow('Date of Joining:', dateOfJoining),
                          pw.SizedBox(height: 8),
                          _buildSummaryRow('Pay Period:', payPeriod),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 24),
                    // Right Column
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildSummaryRow('Pay Date:', paymentDateStr),
                          pw.SizedBox(height: 12),
                          pw.Text(
                            'Employee Net Pay',
                            style: pw.TextStyle(
                              fontSize: 12,
                              color: PdfColors.grey700,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            '$currencySymbol${_formatCurrency(net)}',
                            style: pw.TextStyle(
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.black,
                              font: unicodeFont,
                            ),
                          ),
                          pw.SizedBox(height: 12),
                          pw.Text(
                            'Paid Days: $workingDays | LOP Days: $lopDays',
                            style: const pw.TextStyle(
                              fontSize: 12,
                              color: PdfColors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 24),
              
              // Earnings and Deductions Section
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Earnings Section (Boxed)
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(16),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey700, width: 1.5),
                        borderRadius: pw.BorderRadius.circular(4),
                        color: PdfColors.white,
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'EARNINGS',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.black,
                            ),
                          ),
                          pw.SizedBox(height: 12),
                          _buildTableHeader(['AMOUNT', 'YTD']),
                          pw.SizedBox(height: 8),
                          _buildTableRow('Basic', basic, basicYtd, currencySymbol, font: unicodeFont),
                          pw.SizedBox(height: 8),
                          _buildTableRow('Medical Allowance', medical, medicalYtd, currencySymbol, font: unicodeFont),
                          pw.SizedBox(height: 8),
                          _buildTableRow('Other Allowances', otherAllowance, otherYtd, currencySymbol, font: unicodeFont),
                          pw.SizedBox(height: 8),
                          _buildTableRow('Gross Earnings', gross, grossYtd, currencySymbol, isBold: true, font: unicodeFont),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 24),
                  // Deductions Section (Boxed)
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(16),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey700, width: 1.5),
                        borderRadius: pw.BorderRadius.circular(4),
                        color: PdfColors.white,
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'DEDUCTIONS',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.black,
                            ),
                          ),
                          pw.SizedBox(height: 12),
                          _buildTableHeader(['AMOUNT', 'YTD']),
                          pw.SizedBox(height: 8),
                          if (professionalTax > 0) ...[
                            _buildTableRow('Professional Tax', professionalTax, professionalTaxYtd, currencySymbol, font: unicodeFont),
                            pw.SizedBox(height: 8),
                          ],
                          if (pf > 0) ...[
                            _buildTableRow('Provident Fund', pf, pfYtd, currencySymbol, font: unicodeFont),
                            pw.SizedBox(height: 8),
                          ],
                          if (esi > 0) ...[
                            _buildTableRow('ESI', esi, esiYtd, currencySymbol, font: unicodeFont),
                            pw.SizedBox(height: 8),
                          ],
                          if (tds > 0) ...[
                            _buildTableRow('TDS', tds, tdsYtd, currencySymbol, font: unicodeFont),
                            pw.SizedBox(height: 8),
                          ],
                          if (absenceDeduction > 0) ...[
                            _buildTableRow('Absence Deduction', absenceDeduction, absenceYtd, currencySymbol, font: unicodeFont),
                            pw.SizedBox(height: 8),
                          ],
                          _buildTableRow('Total Deductions', totalDeductions, totalDeductionsYtd, currencySymbol, isBold: true, font: unicodeFont),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              pw.SizedBox(height: 24),
              
              // Net Pay Section
              pw.Text(
                'NET PAY',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
              pw.SizedBox(height: 12),
              _buildNetPayRow('Gross Earnings:', '$currencySymbol${_formatCurrency(gross)}', font: unicodeFont),
              pw.SizedBox(height: 8),
              _buildNetPayRow('Total Deductions:', '(-) $currencySymbol${_formatCurrency(totalDeductions)}', font: unicodeFont),
              pw.SizedBox(height: 8),
              _buildNetPayRow('Total Net Payable:', '$currencySymbol${_formatCurrency(net)}', isBold: true, font: unicodeFont),
              
              pw.SizedBox(height: 24),
              
              // Net Pay in Words
              pw.Text(
                'Total Net Payable $currencySymbol${_formatCurrency(net)} (${_numberToWords(net, currency)})',
                style: const pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.black,
                ),
              ),
              
              pw.SizedBox(height: 24),
              
              // Footer
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '**Total Net Payable = Gross Earnings - Total Deductions',
                    style: pw.TextStyle(
                      fontSize: 11,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'This is a computer-generated payslip and does not require a signature.',
                    style: pw.TextStyle(
                      fontSize: 11,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    // Save PDF to file
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Desktop platforms
      final directory = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(await pdf.save());
      await OpenFilex.open(file.path);
    } else {
      // Mobile platforms - use printing package
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    }
  }

  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 120,
          child: pw.Text(
            label,
            style: const pw.TextStyle(
              fontSize: 13,
              color: PdfColors.grey700,
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
            textAlign: pw.TextAlign.right,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildSummaryRow(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 100,
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 12,
              color: PdfColors.grey700,
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildTableHeader(List<String> headers) {
    return pw.Row(
      children: [
        // Label column
        pw.Expanded(
          flex: 2,
          child: pw.Text(
            '',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
        ),
        pw.SizedBox(width: 8),
        // Amount column – wider so values like "Rs.35,000.00" stay on one line
        pw.Expanded(
          flex: 3,
          child: pw.Text(
            headers[0],
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
            textAlign: pw.TextAlign.right,
          ),
        ),
        pw.SizedBox(width: 8),
        // YTD column – same width as Amount
        pw.Expanded(
          flex: 3,
          child: pw.Text(
            headers[1],
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
            textAlign: pw.TextAlign.right,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildTableRow(String label, double amount, double ytd, String currencySymbol, {bool isBold = false, pw.Font? font}) {
    return pw.Row(
      children: [
        // Label column
        pw.Expanded(
          flex: 2,
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: PdfColors.black,
            ),
          ),
        ),
        pw.SizedBox(width: 8),
        // Amount column
        pw.Expanded(
          flex: 3,
          child: pw.Text(
            '$currencySymbol${_formatCurrency(amount)}',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: PdfColors.black,
              font: font,
            ),
            textAlign: pw.TextAlign.right,
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
          ),
        ),
        pw.SizedBox(width: 8),
        // YTD column
        pw.Expanded(
          flex: 3,
          child: pw.Text(
            '$currencySymbol${_formatCurrency(ytd)}',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: PdfColors.black,
              font: font,
            ),
            textAlign: pw.TextAlign.right,
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildNetPayRow(String label, String value, {bool isBold = false, pw.Font? font}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: PdfColors.black,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.bold,
            color: PdfColors.black,
            font: font,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildAmountRow(String label, double amount, String currencySymbol, {bool isTotal = false, pw.Font? font}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: isTotal ? 14 : 13,
              fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: PdfColors.black,
            ),
          ),
        ),
        pw.SizedBox(width: 16),
        pw.Text(
          '$currencySymbol${_formatCurrency(amount)}',
          style: pw.TextStyle(
            fontSize: isTotal ? 14 : 13,
            fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: PdfColors.black,
            font: font, // Use Unicode font if available
          ),
          textAlign: pw.TextAlign.right,
        ),
      ],
    );
  }

  String _formatCurrency(double amount) {
    return NumberFormat('#,##0.00').format(amount);
  }

  String _numberToWords(double amount, String currency) {
    final wholePart = amount.toInt();
    
    String currencyName = 'Indian Rupee';
    if (currency == 'QAR') {
      currencyName = 'Qatari Riyals';
    } else if (currency == 'USD') {
      currencyName = 'Dollars';
    }
    
    String words = _convertNumberToWords(wholePart);
    words += ' $currencyName Only';
    
    return words;
  }

  String _convertNumberToWords(int number) {
    if (number == 0) return 'Zero';
    
    final ones = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 
                  'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 
                  'Seventeen', 'Eighteen', 'Nineteen'];
    final tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];
    
    if (number < 20) {
      return ones[number];
    } else if (number < 100) {
      return '${tens[number ~/ 10]} ${ones[number % 10]}'.trim();
    } else if (number < 1000) {
      return '${ones[number ~/ 100]} Hundred ${_convertNumberToWords(number % 100)}'.trim();
    } else if (number < 100000) {
      return '${_convertNumberToWords(number ~/ 1000)} Thousand ${_convertNumberToWords(number % 1000)}'.trim();
    } else if (number < 10000000) {
      return '${_convertNumberToWords(number ~/ 100000)} Lakh ${_convertNumberToWords(number % 100000)}'.trim();
    } else {
      return '${_convertNumberToWords(number ~/ 10000000)} Crore ${_convertNumberToWords(number % 10000000)}'.trim();
    }
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[^\d\.\-]'), '');
      if (cleaned.isEmpty) return null;
      return double.tryParse(cleaned);
    }
    return null;
  }
}







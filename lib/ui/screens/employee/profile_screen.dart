import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:loghr_mobile/logic/auth_provider.dart';
import 'package:loghr_mobile/logic/attendance_provider.dart';
import 'package:loghr_mobile/logic/leave_provider.dart';
import 'package:loghr_mobile/logic/profile_provider.dart';
import 'package:loghr_mobile/data/services/payroll_service.dart';
import 'package:loghr_mobile/data/services/profile_service.dart';
import 'package:loghr_mobile/ui/screens/shared/settings_screen.dart';
import 'package:loghr_mobile/ui/screens/employee/payslip_detail_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'dart:io';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onNavigateToDashboard;
  
  const ProfileScreen({
    super.key,
    this.onNavigateToDashboard,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTab = 0;
  bool _isEditMode = false;
  bool _isSaving = false;
  final ProfileService _profileService = ProfileService();
  
  // Controllers for editable fields
  final TextEditingController _companyEmailController = TextEditingController();
  final TextEditingController _personalEmailController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _alternateController = TextEditingController();
  final TextEditingController _dateOfBirthController = TextEditingController();
  String? _gender;
  final TextEditingController _bloodGroupController = TextEditingController();
  String? _maritalStatus;
  final TextEditingController _nationalityController = TextEditingController();
  final TextEditingController _religionController = TextEditingController();
  final TextEditingController _placeOfBirthController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _designationController = TextEditingController();
  final TextEditingController _branchController = TextEditingController();
  final TextEditingController _joiningDateController = TextEditingController();
  String? _employmentType;
  String? _status;
  final TextEditingController _noticePeriodController = TextEditingController();
  final TextEditingController _fatherNameController = TextEditingController();
  final TextEditingController _motherNameController = TextEditingController();
  final TextEditingController _spouseNameController = TextEditingController();
  final TextEditingController _numberOfChildrenController = TextEditingController();
  final TextEditingController _currentAddressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();
  final TextEditingController _permanentAddressController = TextEditingController();
  bool _sameAsCurrent = false;
  final TextEditingController _emergencyContactNameController = TextEditingController();
  final TextEditingController _emergencyRelationshipController = TextEditingController();
  final TextEditingController _emergencyPhoneController = TextEditingController();
  final TextEditingController _emergencyAlternateController = TextEditingController();
  // Personal Tab - Personal Interests
  final TextEditingController _hobbiesController = TextEditingController();
  
  // Professional Tab - Education
  final TextEditingController _highestQualificationController = TextEditingController();
  final TextEditingController _universityController = TextEditingController();
  final TextEditingController _yearOfCompletionController = TextEditingController();
  final TextEditingController _specializationController = TextEditingController();

  // Professional Tab - Previous Employment
  final TextEditingController _previousEmployerController = TextEditingController();
  final TextEditingController _previousDesignationController = TextEditingController();
  final TextEditingController _previousEmploymentFromController = TextEditingController();
  final TextEditingController _previousEmploymentToController = TextEditingController();
  final TextEditingController _previousSalaryController = TextEditingController();
  final TextEditingController _totalExperienceController = TextEditingController();
  final TextEditingController _reasonForLeavingController = TextEditingController();

  // Professional Tab - Professional Links
  final TextEditingController _linkedInController = TextEditingController();
  final TextEditingController _gitHubController = TextEditingController();
  final TextEditingController _portfolioController = TextEditingController();
  final TextEditingController _panController = TextEditingController();
  final TextEditingController _aadhaarController = TextEditingController();
  final TextEditingController _uanController = TextEditingController();
  final TextEditingController _pfAccountController = TextEditingController();
  final TextEditingController _pfUanController = TextEditingController();
  final TextEditingController _esiController = TextEditingController();
  final TextEditingController _professionalTaxController = TextEditingController();
  final TextEditingController _lwfController = TextEditingController();
  final TextEditingController _drivingLicenseController = TextEditingController();
  final TextEditingController _dlExpiryController = TextEditingController();
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _accountNumberController = TextEditingController();
  final TextEditingController _ifscCodeController = TextEditingController();
  final TextEditingController _bankBranchController = TextEditingController();
  final TextEditingController _passportNumberController = TextEditingController();
  final TextEditingController _passportIssueDateController = TextEditingController();

  // Payroll filter state
  int? _selectedMonth;
  int? _selectedYear;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _selectedTab = _tabController.index;
        });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _companyEmailController.dispose();
    _personalEmailController.dispose();
    _mobileController.dispose();
    _alternateController.dispose();
    _dateOfBirthController.dispose();
    _bloodGroupController.dispose();
    _nationalityController.dispose();
    _religionController.dispose();
    _placeOfBirthController.dispose();
    _departmentController.dispose();
    _designationController.dispose();
    _branchController.dispose();
    _joiningDateController.dispose();
    _noticePeriodController.dispose();
    _fatherNameController.dispose();
    _motherNameController.dispose();
    _spouseNameController.dispose();
    _numberOfChildrenController.dispose();
    _currentAddressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _permanentAddressController.dispose();
    _emergencyContactNameController.dispose();
    _emergencyRelationshipController.dispose();
    _emergencyPhoneController.dispose();
    _emergencyAlternateController.dispose();
    _hobbiesController.dispose();
    _highestQualificationController.dispose();
    _universityController.dispose();
    _yearOfCompletionController.dispose();
    _specializationController.dispose();
    _previousEmployerController.dispose();
    _previousDesignationController.dispose();
    _previousEmploymentFromController.dispose();
    _previousEmploymentToController.dispose();
    _previousSalaryController.dispose();
    _totalExperienceController.dispose();
    _reasonForLeavingController.dispose();
    _linkedInController.dispose();
    _gitHubController.dispose();
    _portfolioController.dispose();
    _panController.dispose();
    _aadhaarController.dispose();
    _uanController.dispose();
    _pfAccountController.dispose();
    _pfUanController.dispose();
    _esiController.dispose();
    _professionalTaxController.dispose();
    _lwfController.dispose();
    _drivingLicenseController.dispose();
    _dlExpiryController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _ifscCodeController.dispose();
    _bankBranchController.dispose();
    _passportNumberController.dispose();
    _passportIssueDateController.dispose();
    super.dispose();
  }
  
  void _loadDataIntoControllers(Map<String, dynamic>? profileData) {
    if (profileData == null) return;
    
    print('ProfileScreen: Loading data into controllers');
    print('ProfileScreen: Profile data keys: ${profileData.keys}');
    
    // Load contact information (prioritize user_profiles, fallback to employee defaults)
    _companyEmailController.text = profileData['email'] as String? ?? '';
    _personalEmailController.text = profileData['personal_email'] as String? ?? '';
    _mobileController.text = profileData['phone'] as String? ?? profileData['mobile'] as String? ?? '';
    _alternateController.text = profileData['alternate_phone'] as String? ?? '';
    
    // Load personal details
    if (profileData['date_of_birth'] != null) {
      try {
        final dob = DateTime.parse(profileData['date_of_birth'] as String);
        _dateOfBirthController.text = DateFormat('dd-MM-yyyy').format(dob);
      } catch (e) {
        print('Error parsing date_of_birth: $e');
      }
    }
    _gender = profileData['gender'] as String?;
    _bloodGroupController.text = profileData['blood_group'] as String? ?? '';
    _maritalStatus = profileData['marital_status'] as String?;
    _nationalityController.text = profileData['nationality'] as String? ?? '';
    _religionController.text = profileData['religion'] as String? ?? '';
    _placeOfBirthController.text = profileData['place_of_birth'] as String? ?? '';
    
    // Load employment details (these often come from employees table as defaults)
    _departmentController.text = profileData['department'] as String? ?? '';
    _designationController.text = profileData['designation'] as String? ?? 
                                 profileData['position'] as String? ?? 
                                 profileData['job_title'] as String? ?? '';
    _branchController.text = profileData['branch'] as String? ?? '';
    
    if (profileData['date_of_joining'] != null) {
      try {
        final doj = DateTime.parse(profileData['date_of_joining'] as String);
        _joiningDateController.text = DateFormat('dd/MM/yyyy').format(doj);
      } catch (e) {
        print('Error parsing date_of_joining: $e');
      }
    }
    
    // Normalize employment type to match dropdown format
    final empType = profileData['employment_type'] as String?;
    if (empType != null) {
      // Convert database format (full_time) to display format (FULL TIME)
      _employmentType = empType
          .toUpperCase()
          .replaceAll('_', ' ')
          .replaceAll('-', ' ');
      // Ensure it matches one of the valid dropdown values
      const validTypes = ['FULL TIME', 'PART TIME', 'CONTRACT', 'INTERN'];
      if (!validTypes.contains(_employmentType)) {
        _employmentType = 'FULL TIME'; // Default fallback
      }
    } else {
      _employmentType = 'FULL TIME';
    }
    _status = profileData['status'] as String? ?? 
             (profileData['is_active'] == true ? 'ACTIVE' : 'INACTIVE');
    _noticePeriodController.text = profileData['notice_period'] != null 
        ? '${profileData['notice_period']}' 
        : (profileData['notice_period_days'] != null 
            ? '${profileData['notice_period_days']}' 
            : '30');
    
    // Load family information
    _fatherNameController.text = profileData['father_name'] as String? ?? '';
    _motherNameController.text = profileData['mother_name'] as String? ?? '';
    _spouseNameController.text = profileData['spouse_name'] as String? ?? '';
    
    final childrenCount = profileData['number_of_children'] as int?;
    _numberOfChildrenController.text = childrenCount != null 
        ? (childrenCount < 0 ? '0' : '$childrenCount') 
        : '';
    
    // Load address information
    _currentAddressController.text = profileData['current_address'] as String? ?? '';
    _cityController.text = profileData['city'] as String? ?? '';
    _stateController.text = profileData['state'] as String? ?? '';
    _pincodeController.text = profileData['pincode'] as String? ?? '';
    _permanentAddressController.text = profileData['permanent_address'] as String? ?? '';
    
    // Load emergency contact
    _emergencyContactNameController.text = profileData['emergency_contact_name'] as String? ?? '';
    _emergencyRelationshipController.text = profileData['emergency_contact_relationship'] as String? ?? '';
    _emergencyPhoneController.text = profileData['emergency_contact_phone'] as String? ?? '';
    _emergencyAlternateController.text = profileData['emergency_contact_alternate'] as String? ?? '';
    
    // Load personal interests
    _hobbiesController.text = profileData['hobbies'] as String? ?? 
                             profileData['interests'] as String? ?? 
                             profileData['personal_interests'] as String? ?? '';
    
    // Load Education with synonyms and fallbacks
    final qualification = profileData['highest_qualification'] as String? ?? 
                         profileData['qualification'] as String? ?? 
                         profileData['education'] as String? ?? '';
    _highestQualificationController.text = qualification.trim().isNotEmpty ? qualification : '';
    
    final university = profileData['university'] as String? ?? 
                      profileData['institution'] as String? ?? 
                      profileData['college'] as String? ?? 
                      profileData['school'] as String? ?? '';
    _universityController.text = university.trim().isNotEmpty ? university : '';
    
    _yearOfCompletionController.text = (profileData['year_of_completion'] ?? profileData['completion_year'] ?? profileData['pass_out_year']) != null 
        ? '${profileData['year_of_completion'] ?? profileData['completion_year'] ?? profileData['pass_out_year']}' 
        : '';
        
    final spec = profileData['specialization'] as String? ?? 
                profileData['field'] as String? ?? 
                profileData['stream'] as String? ?? '';
    _specializationController.text = spec.trim().isNotEmpty ? spec : '';

    // Load Previous Employment
    _previousEmployerController.text = profileData['previous_employer'] as String? ?? '';
    _previousDesignationController.text = profileData['previous_designation'] as String? ?? '';
    if (profileData['previous_employment_from'] != null) {
      try {
        final fromDate = DateTime.parse(profileData['previous_employment_from'] as String);
        _previousEmploymentFromController.text = DateFormat('dd-MM-yyyy').format(fromDate);
      } catch (e) { print('Error parsing prev emp from: $e'); }
    }
    if (profileData['previous_employment_to'] != null) {
      try {
        final toDate = DateTime.parse(profileData['previous_employment_to'] as String);
        _previousEmploymentToController.text = DateFormat('dd-MM-yyyy').format(toDate);
      } catch (e) { print('Error parsing prev emp to: $e'); }
    }
    _previousSalaryController.text = profileData['previous_salary'] != null ? '${profileData['previous_salary']}' : '';
    _totalExperienceController.text = profileData['total_experience'] != null ? '${profileData['total_experience']}' : '';
    _reasonForLeavingController.text = profileData['reason_for_leaving'] as String? ?? '';

    // Load professional links
    _linkedInController.text = profileData['linkedin_url'] as String? ?? 
                              profileData['linkedin'] as String? ?? '';
    _gitHubController.text = profileData['github_url'] as String? ?? 
                            profileData['github'] as String? ?? '';
    _portfolioController.text = profileData['portfolio_url'] as String? ?? 
                               profileData['portfolio'] as String? ?? '';
    
    // Load Indian Government IDs
    _panController.text = profileData['pan'] as String? ?? profileData['pan_number'] as String? ?? '';
    _aadhaarController.text = profileData['aadhaar'] as String? ?? profileData['aadhaar_number'] as String? ?? '';
    _uanController.text = profileData['uan'] as String? ?? profileData['uan_number'] as String? ?? '';
    _pfAccountController.text = profileData['pf_account'] as String? ?? profileData['pf_account_number'] as String? ?? '';
    _pfUanController.text = profileData['pf_uan'] as String? ?? profileData['pf_uan_number'] as String? ?? '';
    _esiController.text = profileData['esi'] as String? ?? profileData['esi_number'] as String? ?? '';
    _professionalTaxController.text = profileData['professional_tax'] as String? ?? profileData['professional_tax_number'] as String? ?? '';
    _lwfController.text = profileData['lwf'] as String? ?? profileData['lwf_number'] as String? ?? '';
    _drivingLicenseController.text = profileData['driving_license'] as String? ?? profileData['driving_license_number'] as String? ?? '';
    
    if (profileData['driving_license_expiry'] != null) {
      try {
        final dlExp = DateTime.parse(profileData['driving_license_expiry'] as String);
        _dlExpiryController.text = DateFormat('dd-MM-yyyy').format(dlExp);
      } catch (e) {
        print('Error parsing driving_license_expiry: $e');
      }
    }
    
    // Load bank details
    _bankNameController.text = profileData['bank_name'] as String? ?? '';
    // Load account number with fallbacks
    final accNo = profileData['account_number'] as String? ?? 
                  profileData['account_no'] as String? ?? 
                  profileData['bank_account_no'] as String? ?? 
                  profileData['bank_acc_no'] as String? ?? 
                  profileData['bank_account_number'] as String? ?? '';
    _accountNumberController.text = accNo.trim().isNotEmpty ? accNo : '';
    _ifscCodeController.text = profileData['ifsc_code'] as String? ?? 
                               profileData['ifsc'] as String? ?? '';
    _bankBranchController.text = profileData['bank_branch'] as String? ?? 
                                 profileData['branch_name'] as String? ?? 
                                 profileData['branch'] as String? ?? '';
    
    // Load passport details
    _passportNumberController.text = profileData['passport_number'] as String? ?? '';
    
    if (profileData['passport_issue_date'] != null) {
      try {
        final passportIssue = DateTime.parse(profileData['passport_issue_date'] as String);
        _passportIssueDateController.text = DateFormat('dd-MM-yyyy').format(passportIssue);
      } catch (e) {
        print('Error parsing passport_issue_date: $e');
      }
    }
    
    print('ProfileScreen: Data loaded into controllers successfully');
  }
  
  void _toggleEditMode() async {
    setState(() {
      _isEditMode = !_isEditMode;
    });
    
    if (_isEditMode) {
      // Reload profile data to get fresh employee details from employees table
      final authProvider = context.read<AuthProvider>();
      final profileProvider = context.read<ProfileProvider>();
      final user = authProvider.user;
      
      if (user != null) {
        // Force reload profile to get latest data from employees table
        await profileProvider.loadProfile(user.id);
      }
      
      // Load data into controllers when entering edit mode
      final profileData = profileProvider.profileData;
      _loadDataIntoControllers(profileData);
      
      if (mounted) {
        setState(() {});
      }
    }
  }
  
  Future<void> _saveProfile() async {
    setState(() {
      _isSaving = true;
    });
    
    try {
      final authProvider = context.read<AuthProvider>();
      final profileProvider = context.read<ProfileProvider>();
      final user = authProvider.user;
      
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No user found')),
        );
        return;
      }
      
      String? _parseDate(String dateString) {
        if (dateString.isEmpty) return null;
        try {
          List<DateFormat> formats = [
            DateFormat('dd-MM-yyyy'),
            DateFormat('dd/MM/yyyy'),
            DateFormat('MM/dd/yyyy'),
            DateFormat('yyyy-MM-dd'),
          ];
          for (var format in formats) {
            try {
              return format.parse(dateString).toIso8601String();
            } catch (e) {
              continue;
            }
          }
          return null;
        } catch (e) {
          return null;
        }
      }
      
      final updates = <String, dynamic>{
        'email': _companyEmailController.text.trim().isEmpty ? null : _companyEmailController.text.trim(),
        'personal_email': _personalEmailController.text.trim().isEmpty ? null : _personalEmailController.text.trim(),
        'phone': _mobileController.text.trim().isEmpty ? null : _mobileController.text.trim(),
        'mobile': _mobileController.text.trim().isEmpty ? null : _mobileController.text.trim(),
        'alternate_phone': _alternateController.text.trim().isEmpty ? null : _alternateController.text.trim(),
        'date_of_birth': _parseDate(_dateOfBirthController.text.trim()),
        'gender': _gender,
        'blood_group': _bloodGroupController.text.trim().isEmpty ? null : _bloodGroupController.text.trim(),
        'marital_status': _maritalStatus,
        'nationality': _nationalityController.text.trim().isEmpty ? null : _nationalityController.text.trim(),
        'religion': _religionController.text.trim().isEmpty ? null : _religionController.text.trim(),
        'place_of_birth': _placeOfBirthController.text.trim().isEmpty ? null : _placeOfBirthController.text.trim(),
        // HR-managed fields - should not be updated by employee
        // 'department': _departmentController.text.trim().isEmpty ? null : _departmentController.text.trim(),
        // 'designation': _designationController.text.trim().isEmpty ? null : _designationController.text.trim(),
        // 'position': _designationController.text.trim().isEmpty ? null : _designationController.text.trim(),
        // 'branch': _branchController.text.trim().isEmpty ? null : _branchController.text.trim(),
        // 'date_of_joining': _parseDate(_joiningDateController.text.trim()),
        // 'employment_type': _employmentType?.toUpperCase().replaceAll(' ', '_'),
        // 'status': _status,
        // 'is_active': _status == 'ACTIVE',
        'notice_period': _noticePeriodController.text.trim().isEmpty ? null : int.tryParse(_noticePeriodController.text.trim()),
        'father_name': _fatherNameController.text.trim().isEmpty ? null : _fatherNameController.text.trim(),
        'mother_name': _motherNameController.text.trim().isEmpty ? null : _motherNameController.text.trim(),
        'spouse_name': _spouseNameController.text.trim().isEmpty ? null : _spouseNameController.text.trim(),
        'number_of_children': _numberOfChildrenController.text.trim().isEmpty 
            ? null 
            : (int.tryParse(_numberOfChildrenController.text.trim()) != null 
                ? (int.parse(_numberOfChildrenController.text.trim()) < 0 ? 0 : int.parse(_numberOfChildrenController.text.trim()))
                : null),
        'current_address': _currentAddressController.text.trim().isEmpty ? null : _currentAddressController.text.trim(),
        'city': _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
        'state': _stateController.text.trim().isEmpty ? null : _stateController.text.trim(),
        'pincode': _pincodeController.text.trim().isEmpty ? null : _pincodeController.text.trim(),
        'permanent_address': _sameAsCurrent ? _currentAddressController.text.trim().isEmpty ? null : _currentAddressController.text.trim() : (_permanentAddressController.text.trim().isEmpty ? null : _permanentAddressController.text.trim()),
        'emergency_contact_name': _emergencyContactNameController.text.trim().isEmpty ? null : _emergencyContactNameController.text.trim(),
        'emergency_contact_relationship': _emergencyRelationshipController.text.trim().isEmpty ? null : _emergencyRelationshipController.text.trim(),
        'emergency_contact_phone': _emergencyPhoneController.text.trim().isEmpty ? null : _emergencyPhoneController.text.trim(),
        'emergency_contact_alternate': _emergencyAlternateController.text.trim().isEmpty ? null : _emergencyAlternateController.text.trim(),
        'hobbies': _hobbiesController.text.trim().isEmpty ? null : _hobbiesController.text.trim(),
        'interests': _hobbiesController.text.trim().isEmpty ? null : _hobbiesController.text.trim(),
        'highest_qualification': _highestQualificationController.text.trim().isEmpty ? null : _highestQualificationController.text.trim(),
        'university': _universityController.text.trim().isEmpty ? null : _universityController.text.trim(),
        'year_of_completion': _yearOfCompletionController.text.trim().isEmpty ? null : int.tryParse(_yearOfCompletionController.text.trim()),
        'specialization': _specializationController.text.trim().isEmpty ? null : _specializationController.text.trim(),
        'previous_employer': _previousEmployerController.text.trim().isEmpty ? null : _previousEmployerController.text.trim(),
        'previous_designation': _previousDesignationController.text.trim().isEmpty ? null : _previousDesignationController.text.trim(),
        'previous_employment_from': _previousEmploymentFromController.text.trim().isEmpty ? null : _parseDate(_previousEmploymentFromController.text.trim()),
        'previous_employment_to': _previousEmploymentToController.text.trim().isEmpty ? null : _parseDate(_previousEmploymentToController.text.trim()),
        'previous_salary': _previousSalaryController.text.trim().isEmpty ? null : double.tryParse(_previousSalaryController.text.trim()),
        'total_experience': _totalExperienceController.text.trim().isEmpty ? null : double.tryParse(_totalExperienceController.text.trim()),
        'reason_for_leaving': _reasonForLeavingController.text.trim().isEmpty ? null : _reasonForLeavingController.text.trim(),
        'linkedin_url': _linkedInController.text.trim().isEmpty ? null : _linkedInController.text.trim(),
        'linkedin': _linkedInController.text.trim().isEmpty ? null : _linkedInController.text.trim(),
        'github_url': _gitHubController.text.trim().isEmpty ? null : _gitHubController.text.trim(),
        'github': _gitHubController.text.trim().isEmpty ? null : _gitHubController.text.trim(),
        'portfolio_url': _portfolioController.text.trim().isEmpty ? null : _portfolioController.text.trim(),
        'portfolio': _portfolioController.text.trim().isEmpty ? null : _portfolioController.text.trim(),
        'pan': _panController.text.trim().isEmpty ? null : _panController.text.trim(),
        'aadhaar': _aadhaarController.text.trim().isEmpty ? null : _aadhaarController.text.trim(),
        'uan': _uanController.text.trim().isEmpty ? null : _uanController.text.trim(),
        'pf_account': _pfAccountController.text.trim().isEmpty ? null : _pfAccountController.text.trim(),
        'pf_uan': _pfUanController.text.trim().isEmpty ? null : _pfUanController.text.trim(),
        'esi': _esiController.text.trim().isEmpty ? null : _esiController.text.trim(),
        'professional_tax': _professionalTaxController.text.trim().isEmpty ? null : _professionalTaxController.text.trim(),
        'lwf': _lwfController.text.trim().isEmpty ? null : _lwfController.text.trim(),
        'driving_license': _drivingLicenseController.text.trim().isEmpty ? null : _drivingLicenseController.text.trim(),
        'driving_license_expiry': _parseDate(_dlExpiryController.text.trim()),
        'bank_name': _bankNameController.text.trim().isEmpty ? null : _bankNameController.text.trim(),
        'account_number': _accountNumberController.text.trim().isEmpty ? null : _accountNumberController.text.trim(),
        'ifsc_code': _ifscCodeController.text.trim().isEmpty ? null : _ifscCodeController.text.trim(),
        'bank_branch': _bankBranchController.text.trim().isEmpty ? null : _bankBranchController.text.trim(),
        'passport_number': _passportNumberController.text.trim().isEmpty ? null : _passportNumberController.text.trim(),
        'passport_issue_date': _parseDate(_passportIssueDateController.text.trim()),
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      updates.removeWhere((key, value) => value == null);
      
      final success = await _profileService.updateProfile(user.id, updates);
      
      if (success) {
        await profileProvider.loadProfile(user.id);
        setState(() {
          _isEditMode = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update profile')),
          );
        }
      }
    } catch (e) {
      print('Error saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }
  
  Future<void> _selectDate(BuildContext context, TextEditingController controller, {DateFormat? format}) async {
    final dateFormat = format ?? DateFormat('dd-MM-yyyy');
    DateTime? initialDate;
    
    if (controller.text.isNotEmpty) {
      try {
        initialDate = dateFormat.parse(controller.text);
      } catch (e) {
        initialDate = DateTime.now();
      }
    } else {
      initialDate = DateTime.now();
    }
    
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    
    if (picked != null) {
      controller.text = dateFormat.format(picked);
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 512,
      maxHeight: 512,
    );
    
    if (image != null) {
      final authProvider = context.read<AuthProvider>();
      final profileProvider = context.read<ProfileProvider>();
      final user = authProvider.user;
      
      if (user != null) {
        final bytes = await image.readAsBytes();
        final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
        
        final success = await profileProvider.uploadAvatar(user.id, bytes, fileName);
        
        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profile picture updated successfully')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to update profile picture')),
            );
          }
        }
      }
    }
  }

  void _loadData() {
    final authProvider = context.read<AuthProvider>();
    final profileProvider = context.read<ProfileProvider>();
    final user = authProvider.user;
    if (user != null) {
      profileProvider.loadProfile(user.id);
      profileProvider.loadPayrollHistory(user.id);
      context.read<AttendanceProvider>().loadTodayAttendance(user.id);
      context.read<AttendanceProvider>().loadHistory(user.id);
      context.read<LeaveProvider>().loadLeaveBalances(user.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final profileProvider = context.watch<ProfileProvider>();
    final attendanceProvider = context.watch<AttendanceProvider>();
    final leaveProvider = context.watch<LeaveProvider>();
    final user = authProvider.user;

    if (user == null) {
      return const Center(child: Text('No user data'));
    }

    // Show loading indicator while profile is being loaded
    if (profileProvider.isLoading && profileProvider.profileData == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final profileData = profileProvider.profileData;
    // ALWAYS prioritize profileData['full_name'] from database over cached user.fullName
    // The database is the source of truth, not the cached User object
    String fullName = 'N/A';
    
    // First priority: Use full_name from freshly loaded profile data
    if (profileData != null) {
      final profileName = profileData['full_name'] as String?;
      if (profileName != null && profileName.toString().trim().isNotEmpty) {
        fullName = profileName.toString().trim();
        print('ProfileScreen: Using full_name from profileData: $fullName');
      }
    }
    
    // Only fallback to user.fullName if profileData is null or doesn't have full_name
    // This should rarely happen if profile is loaded correctly
    if (fullName == 'N/A' && user.fullName.isNotEmpty) {
      fullName = user.fullName;
      print('ProfileScreen: Falling back to user.fullName: $fullName');
    }
    final designation = profileData?['designation'] as String? ?? 
                        profileData?['position'] as String? ?? 
                        'Employee';
    final orgData = profileProvider.organizationData;
    final companyLogoUrl = orgData?['logo_url'] as String? ?? 
                          orgData?['logo'] as String? ?? 
                          orgData?['company_logo'] as String?;
    final companyName = orgData?['name'] as String? ??
                        orgData?['company_name'] as String? ??
                        orgData?['organization_name'] as String? ??
                        '';
    // Use formatted employee code if available, otherwise fallback to employee_id
    final employeeId = profileProvider.formattedEmployeeCode ?? 
                      profileData?['employee_id'] as String? ?? 
                      user.employeeId ?? 
                      'N/A';

    final userAvatarUrl = profileData?['avatar_url'] as String? ?? user.avatarUrl;

    // Get initials for profile picture
    final nameParts = fullName.split(' ');
    final initials = nameParts.length >= 2
        ? '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase()
        : fullName.length >= 2
            ? fullName.substring(0, 2).toUpperCase()
            : 'U';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header with title and buttons
            Padding(
              padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                  if (companyName.isNotEmpty)
                    Row(
                      children: [
                        if (companyLogoUrl != null && companyLogoUrl.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(
                              companyLogoUrl,
                              width: 28,
                              height: 28,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.business, size: 22, color: Colors.blue);
                              },
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                );
                              },
                            ),
                          )
                        else
                          const Icon(Icons.business, size: 22, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            companyName,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                  if (companyName.isNotEmpty) const SizedBox(height: 8),
                  const Text(
                    'My Profile',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
              const SizedBox(height: 4),
                  Text(
                    'Complete employee information - India',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const PrivacySecurityScreen()),
                            );
                          },
                          icon: const Icon(Icons.lock_outline, size: 16),
                          label: const Text('Change Password', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (!_isEditMode)
                        Flexible(
                          child: ElevatedButton.icon(
                            onPressed: _toggleEditMode,
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text('Edit Profile', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ),
                      if (_isEditMode) ...[
                        Flexible(
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : () {
                              setState(() {
                                _isEditMode = false;
                              });
                            },
                            icon: const Icon(Icons.close, size: 16),
                            label: const Text('Cancel', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _saveProfile,
                            icon: _isSaving 
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.save, size: 16),
                            label: Text(
                              _isSaving ? 'Saving...' : 'Save Changes',
                              style: const TextStyle(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Profile Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade700, Colors.blue.shade900],
                ),
              ),
              child: Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: (userAvatarUrl != null && userAvatarUrl.isNotEmpty)
                            ? GestureDetector(
                                onTap: () => _showProfilePicturePreview(context, userAvatarUrl),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(40),
                                  child: Image.network(
                                    userAvatarUrl,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Center(
                                        child: Text(
                                          initials,
                                          style: TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue.shade700,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  initials,
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.blue.shade700,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          Text(
                          fullName,
                          style: const TextStyle(
                            fontSize: 24,
                              fontWeight: FontWeight.bold,
                            color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                          designation,
                          style: TextStyle(
                              fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          employeeId == 'N/A' || 
                          (employeeId.contains('-') && employeeId.length > 20)
                              ? (profileProvider.formattedEmployeeCode ?? 'N/A')
                              : employeeId,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tabs
            Container(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: Colors.blue.shade700,
                labelColor: Colors.blue.shade700,
                unselectedLabelColor: Colors.grey,
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Personal'),
                  Tab(text: 'Organization'),
                  Tab(text: 'Professional'),
                  Tab(text: 'Documents'),
                  Tab(text: 'Payroll'),
                ],
              ),
            ),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(profileData, textColor, isDark),
                  _buildPersonalTab(profileData, textColor, isDark),
                  _buildOrganizationTab(profileProvider, textColor, isDark),
                  _buildProfessionalTab(profileData, textColor, isDark),
                  _buildDocumentsTab(profileData, textColor, isDark),
                  _buildPayrollTab(profileProvider, user.id, textColor, isDark),
                ],
              ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

  Widget _buildOverviewTab(Map<String, dynamic>? profileData, Color textColor, bool isDark) {
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Contact Information
          _buildSectionCard(
            title: 'Contact Information',
            icon: Icons.contact_mail,
            children: [
              _buildInfoRow(
                'Company Email',
                profileData?['email'] as String? ?? 'N/A',
                controller: _companyEmailController,
                icon: Icons.email,
              ),
              _buildInfoRow(
                'Mobile',
                profileData?['phone'] as String? ?? profileData?['mobile'] as String? ?? 'N/A',
                controller: _mobileController,
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
              ),
              _buildInfoRow(
                'Personal Email',
                profileData?['personal_email'] as String? ?? 'N/A',
                controller: _personalEmailController,
                icon: Icons.email,
              ),
              _buildInfoRow(
                'Alternate',
                profileData?['alternate_phone'] as String? ?? 'N/A',
                controller: _alternateController,
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
              ),
            ],
            cardColor: cardColor,
            borderColor: borderColor,
          ),

          const SizedBox(height: 16),

          // Employment Details
          _buildSectionCard(
            title: 'Employment Details',
            icon: Icons.business_center,
                children: [
              _buildInfoRow(
                'Department',
                profileData?['department'] as String? ?? 'N/A',
                icon: Icons.business,
              ),
              _buildInfoRow(
                'Branch',
                profileData?['branch'] as String? ?? 'N/A',
                icon: Icons.location_on,
              ),
              _buildInfoRow(
                'Employment Type',
                profileData?['employment_type'] as String? ?? 'FULL TIME',
              ),
              _buildInfoRow(
                'Notice Period',
                profileData?['notice_period'] != null 
                    ? '${profileData!['notice_period']} days' 
                    : (profileData?['notice_period_days'] != null 
                        ? '${profileData!['notice_period_days']} days' 
                        : '30 days'),
                controller: _noticePeriodController,
                keyboardType: TextInputType.number,
              ),
              _buildInfoRow(
                'Designation',
                profileData?['designation'] as String? ?? profileData?['position'] as String? ?? 'N/A',
                icon: Icons.business_center,
              ),
              _buildInfoRow(
                'Joining Date',
                profileData?['date_of_joining'] != null
                    ? DateFormat('dd/MM/yyyy').format(DateTime.parse(profileData!['date_of_joining']))
                    : 'N/A',
                icon: Icons.calendar_today,
              ),
              _buildInfoRow(
                'Status',
                profileData?['status'] as String? ?? (profileData?['is_active'] == true ? 'ACTIVE' : 'INACTIVE'),
              ),
            ],
            cardColor: cardColor,
            borderColor: borderColor,
          ),

          const SizedBox(height: 16),

          // Personal Details
          _buildSectionCard(
            title: 'Personal Details',
            icon: Icons.person,
            children: [
              _buildInfoRow(
                'Date of Birth',
                profileData?['date_of_birth'] != null
                    ? DateFormat('dd-MM-yyyy').format(DateTime.parse(profileData!['date_of_birth']))
                    : 'N/A',
                controller: _dateOfBirthController,
                readOnly: true,
                onTap: () => _selectDate(context, _dateOfBirthController),
                icon: Icons.calendar_today,
              ),
              _buildInfoRow(
                'Gender',
                profileData?['gender'] as String? ?? 'N/A',
                dropdownValue: _gender,
                dropdownItems: ['Male', 'Female', 'Other'],
                onDropdownChanged: (value) => setState(() => _gender = value),
                icon: Icons.person_outline,
              ),
              _buildInfoRow(
                'Blood Group',
                profileData?['blood_group'] as String? ?? 'N/A',
                controller: _bloodGroupController,
              ),
              _buildInfoRow(
                'Marital Status',
                profileData?['marital_status'] as String? ?? 'N/A',
                dropdownValue: _maritalStatus,
                dropdownItems: ['Single', 'Married', 'Divorced', 'Widowed'],
                onDropdownChanged: (value) => setState(() => _maritalStatus = value),
              ),
              _buildInfoRow(
                'Nationality',
                profileData?['nationality'] as String? ?? 'N/A',
                controller: _nationalityController,
              ),
              _buildInfoRow(
                'Religion',
                profileData?['religion'] as String? ?? 'N/A',
                controller: _religionController,
              ),
              _buildInfoRow(
                'Place of Birth',
                profileData?['place_of_birth'] as String? ?? 'N/A',
                controller: _placeOfBirthController,
              ),
            ],
            cardColor: cardColor,
            borderColor: borderColor,
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalTab(Map<String, dynamic>? profileData, Color textColor, bool isDark) {
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Family Information
          _buildSectionCard(
            title: 'Family Information',
            icon: Icons.family_restroom,
            children: [
              _buildInfoRow(
                'Father\'s Name',
                profileData?['father_name'] as String? ?? 'Not provided',
                controller: _fatherNameController,
              ),
              _buildInfoRow(
                'Mother\'s Name',
                profileData?['mother_name'] as String? ?? 'Not provided',
                controller: _motherNameController,
              ),
              _buildInfoRow(
                'Spouse\'s Name',
                profileData?['spouse_name'] as String? ?? 'Not provided',
                controller: _spouseNameController,
              ),
              _buildInfoRow(
                'Number of Children',
                profileData?['number_of_children'] != null 
                    ? ((profileData!['number_of_children'] as int) < 0 ? '0' : '${profileData!['number_of_children']}') 
                    : 'Not provided',
                controller: _numberOfChildrenController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                icon: Icons.child_care,
              ),
            ],
            cardColor: cardColor,
            borderColor: borderColor,
          ),

          const SizedBox(height: 16),

          // Emergency Contact
          _buildSectionCard(
            title: 'Emergency Contact',
                    icon: Icons.warning_amber,
            children: [
              _buildInfoRow(
                'Name',
                profileData?['emergency_contact_name'] as String? ?? 'Not provided',
                controller: _emergencyContactNameController,
              ),
              _buildInfoRow(
                'Relationship',
                profileData?['emergency_contact_relationship'] as String? ?? 'Not provided',
                controller: _emergencyRelationshipController,
              ),
              _buildInfoRow(
                'Primary Phone',
                profileData?['emergency_contact_phone'] as String? ?? 'Not provided',
                controller: _emergencyPhoneController,
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
              ),
              _buildInfoRow(
                'Alternate Phone',
                profileData?['emergency_contact_alternate'] as String? ?? 'Not provided',
                controller: _emergencyAlternateController,
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
              ),
            ],
            cardColor: cardColor,
            borderColor: borderColor,
          ),

          const SizedBox(height: 16),

          // Address Information
          _buildSectionCard(
            title: 'Address Information',
            icon: Icons.location_on,
            children: [
              _buildInfoRow(
                'Current Address',
                profileData?['current_address'] as String? ?? 'Not provided',
                controller: _currentAddressController,
                maxLines: 3,
              ),
              _buildInfoRow(
                'City',
                profileData?['city'] as String? ?? 'N/A',
                controller: _cityController,
              ),
              _buildInfoRow(
                'State',
                profileData?['state'] as String? ?? 'N/A',
                controller: _stateController,
              ),
              _buildInfoRow(
                'Pincode',
                profileData?['pincode'] as String? ?? 'N/A',
                controller: _pincodeController,
                keyboardType: TextInputType.number,
              ),
              if (_isEditMode)
                CheckboxListTile(
                  title: const Text('Same as current or different'),
                  value: _sameAsCurrent,
                  onChanged: (value) => setState(() => _sameAsCurrent = value ?? false),
                  contentPadding: EdgeInsets.zero,
                ),
              if (!_sameAsCurrent || !_isEditMode)
                _buildInfoRow(
                  'Permanent Address',
                  profileData?['permanent_address'] as String? ?? 'Not provided',
                  controller: _permanentAddressController,
                  maxLines: 3,
                ),
            ],
            cardColor: cardColor,
            borderColor: borderColor,
          ),
          
          const SizedBox(height: 16),
          
          // Personal Interests
          if (_isEditMode)
            _buildSectionCard(
              title: 'Personal Interests',
              icon: Icons.favorite,
              children: [
                _buildInfoRow(
                  'Hobbies & Interests',
                  profileData?['hobbies'] as String? ?? profileData?['interests'] as String? ?? '',
                  controller: _hobbiesController,
                  maxLines: 5,
                ),
              ],
              cardColor: cardColor,
              borderColor: borderColor,
            ),
        ],
      ),
    );
  }

  Widget _buildOrganizationTab(ProfileProvider profileProvider, Color textColor, bool isDark) {
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1);
    final orgData = profileProvider.organizationData;
    final departments = profileProvider.departments;
    final profileData = profileProvider.profileData;
    final orgId = profileData?['organization_id'] as String?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Company Overview
          if (orgData != null)
            Card(
              elevation: 0,
              color: Colors.blue.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(Icons.business, color: Colors.white, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            orgData['name'] as String? ?? 'Organization',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${orgData['country'] as String? ?? 'India'} • ${profileProvider.departments.length} Departments • ${profileProvider.totalEmployees} ${profileProvider.totalEmployees == 1 ? 'Employee' : 'Employees'}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                                  ),
                                ),
                              ),

          const SizedBox(height: 16),

          // Department List
              const Text(
            'Departments',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
          if (departments.isEmpty)
            Card(
                                    elevation: 0,
              color: cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: borderColor),
              ),
              child: const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: Text('No departments found'),
                ),
              ),
            )
          else
            ...departments.map((dept) => Card(
              elevation: 0,
              color: cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: borderColor),
              ),
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const Icon(Icons.business, color: Colors.blue),
                title: Text(dept['name'] as String? ?? 'Unknown'),
                subtitle: Text(
                  'Code: ${dept['code'] as String? ?? 'N/A'} • ${dept['employee_count'] ?? 0} ${(dept['employee_count'] ?? 0) == 1 ? 'employee' : 'employees'}',
                ),
                trailing: const Icon(Icons.arrow_drop_down),
                onTap: () => _showDepartmentEmployees(context, dept, profileProvider, textColor, isDark),
              ),
            )),
        ],
      ),
    );
  }

  Widget _buildProfessionalTab(Map<String, dynamic>? profileData, Color textColor, bool isDark) {
                  final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
                  final borderColor = isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1);
                  
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Education
          _buildSectionCard(
            title: 'Education',
            icon: Icons.school,
            children: [
              _buildInfoRow(
                'Highest Qualification',
                ((profileData?['highest_qualification'] as String? ?? '').isNotEmpty) ? profileData!['highest_qualification'] :
                ((profileData?['qualification'] as String? ?? '').isNotEmpty) ? profileData!['qualification'] :
                ((profileData?['education'] as String? ?? '').isNotEmpty) ? profileData!['education'] : 'N/A',
                controller: _highestQualificationController,
                hintText: 'B.Tech, MBA, etc.',
              ),
              _buildInfoRow(
                'Institution/University',
                ((profileData?['university'] as String? ?? '').isNotEmpty) ? profileData!['university'] :
                ((profileData?['institution'] as String? ?? '').isNotEmpty) ? profileData!['institution'] :
                ((profileData?['college'] as String? ?? '').isNotEmpty) ? profileData!['college'] :
                ((profileData?['school'] as String? ?? '').isNotEmpty) ? profileData!['school'] : 'N/A',
                controller: _universityController,
                hintText: 'University name',
              ),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoRow(
                      'Year of Completion',
                      (profileData?['year_of_completion'] ?? profileData?['completion_year'] ?? profileData?['pass_out_year']) != null 
                        ? '${profileData?['year_of_completion'] ?? profileData?['completion_year'] ?? profileData?['pass_out_year']}' 
                        : 'N/A',
                      controller: _yearOfCompletionController,
                      keyboardType: TextInputType.number,
                      hintText: '2020',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildInfoRow(
                      'Specialization/Field',
                      ((profileData?['specialization'] as String? ?? '').isNotEmpty) ? profileData!['specialization'] :
                      ((profileData?['field'] as String? ?? '').isNotEmpty) ? profileData!['field'] :
                      ((profileData?['stream'] as String? ?? '').isNotEmpty) ? profileData!['stream'] : 'N/A',
                      controller: _specializationController,
                      hintText: 'Computer Science, etc.',
                    ),
                  ),
                ],
              ),
            ],
            cardColor: cardColor,
            borderColor: borderColor,
          ),

          const SizedBox(height: 16),

          // Previous Employment
          _buildSectionCard(
            title: 'Previous Employment',
            icon: Icons.work_history,
            children: [
              _buildInfoRow(
                'Previous Employer',
                profileData?['previous_employer'] as String? ?? 'N/A',
                controller: _previousEmployerController,
                hintText: 'Company name',
              ),
              _buildInfoRow(
                'Previous Designation',
                profileData?['previous_designation'] as String? ?? 'N/A',
                controller: _previousDesignationController,
                hintText: 'Job title',
              ),
              Row(
                children: [
                   Expanded(
                    child: _buildInfoRow(
                      'Employment From', 
                      profileData?['previous_employment_from'] != null 
                        ? DateFormat('dd-MM-yyyy').format(DateTime.parse(profileData!['previous_employment_from']))
                        : 'N/A',
                      controller: _previousEmploymentFromController, 
                      icon: Icons.calendar_today,
                      readOnly: true,
                      onTap: _isEditMode ? () => _selectDate(context, _previousEmploymentFromController) : null,
                      hintText: 'dd-mm-yyyy',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildInfoRow(
                      'Employment To', 
                      profileData?['previous_employment_to'] != null 
                        ? DateFormat('dd-MM-yyyy').format(DateTime.parse(profileData!['previous_employment_to']))
                        : 'N/A',
                      controller: _previousEmploymentToController, 
                      icon: Icons.calendar_today,
                      readOnly: true,
                      onTap: _isEditMode ? () => _selectDate(context, _previousEmploymentToController) : null,
                      hintText: 'dd-mm-yyyy',
                    ),
                  ),
                ],
              ),
              _buildInfoRow(
                'Previous Salary',
                profileData?['previous_salary'] != null ? '${profileData!['previous_salary']}' : 'N/A',
                controller: _previousSalaryController,
                keyboardType: TextInputType.number,
                hintText: 'Annual CTC',
              ),
              _buildInfoRow(
                'Total Experience (Years)',
                profileData?['total_experience'] != null ? '${profileData!['total_experience']}' : 'N/A',
                controller: _totalExperienceController,
                keyboardType: TextInputType.number,
                hintText: 'Years of exp',
              ),
              _buildInfoRow(
                'Reason for Leaving',
                profileData?['reason_for_leaving'] as String? ?? 'N/A',
                controller: _reasonForLeavingController,
                maxLines: 3,
                hintText: 'Reason for leaving previous job',
              ),
            ],
            cardColor: cardColor,
            borderColor: borderColor,
          ),

          const SizedBox(height: 16),

          _buildSectionCard(
            title: 'Professional Links',
            icon: Icons.link,
            children: [
              _buildInfoRow(
                'LinkedIn',
                profileData?['linkedin_url'] as String? ?? profileData?['linkedin'] as String? ?? 'N/A',
                controller: _linkedInController,
                hintText: 'https://linkedin.com/in/username',
              ),
              _buildInfoRow(
                'GitHub',
                profileData?['github_url'] as String? ?? profileData?['github'] as String? ?? 'N/A',
                controller: _gitHubController,
                hintText: 'https://github.com/username',
              ),
              _buildInfoRow(
                'Portfolio',
                profileData?['portfolio_url'] as String? ?? profileData?['portfolio'] as String? ?? 'N/A',
                controller: _portfolioController,
                hintText: 'https://yourwebsite.com',
              ),
            ],
            cardColor: cardColor,
            borderColor: borderColor,
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsTab(Map<String, dynamic>? profileData, Color textColor, bool isDark) {
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Indian Government IDs
          _buildSectionCard(
            title: 'Indian Government IDs',
            icon: Icons.shield,
            children: [
              _buildInfoRow(
                'PAN Number',
                profileData?['pan'] as String? ?? profileData?['pan_number'] as String? ?? 'N/A',
                controller: _panController,
                icon: Icons.badge,
              ),
              _buildInfoRow(
                'Aadhaar Number',
                profileData?['aadhaar'] as String? ?? profileData?['aadhaar_number'] as String? ?? 'N/A',
                controller: _aadhaarController,
                icon: Icons.verified_user,
              ),
              _buildInfoRow(
                'UAN Number',
                profileData?['uan'] as String? ?? 'N/A',
                controller: _uanController,
                icon: Icons.work,
              ),
              _buildInfoRow(
                'PF Account',
                profileData?['pf_account'] as String? ?? 'N/A',
                controller: _pfAccountController,
                icon: Icons.account_balance_wallet,
              ),
              _buildInfoRow(
                'PF UAN',
                profileData?['pf_uan'] as String? ?? 'N/A',
                controller: _pfUanController,
                icon: Icons.work_outline,
              ),
              _buildInfoRow(
                'ESI Number',
                profileData?['esi'] as String? ?? 'N/A',
                controller: _esiController,
                icon: Icons.health_and_safety,
              ),
              _buildInfoRow(
                'Professional Tax',
                profileData?['professional_tax'] as String? ?? 'N/A',
                controller: _professionalTaxController,
                icon: Icons.receipt,
              ),
              _buildInfoRow(
                'LWF Number',
                profileData?['lwf'] as String? ?? 'N/A',
                controller: _lwfController,
                icon: Icons.description,
              ),
            ],
            cardColor: cardColor,
            borderColor: borderColor,
          ),

          const SizedBox(height: 16),

          // Bank Details
          _buildSectionCard(
            title: 'Bank Details',
            icon: Icons.account_balance,
            children: [
              _buildInfoRow(
                'Bank Name',
                profileData?['bank_name'] as String? ?? 'N/A',
                controller: _bankNameController,
                icon: Icons.account_balance,
              ),
              _buildInfoRow(
                'Account Number',
                ((profileData?['account_number'] as String? ?? '').isNotEmpty) ? profileData!['account_number'] :
                ((profileData?['account_no'] as String? ?? '').isNotEmpty) ? profileData!['account_no'] :
                ((profileData?['bank_account_no'] as String? ?? '').isNotEmpty) ? profileData!['bank_account_no'] :
                ((profileData?['bank_acc_no'] as String? ?? '').isNotEmpty) ? profileData!['bank_acc_no'] :
                ((profileData?['bank_account_number'] as String? ?? '').isNotEmpty) ? profileData!['bank_account_number'] : 'N/A',
                controller: _accountNumberController,
                icon: Icons.numbers,
                keyboardType: TextInputType.number,
              ),
              _buildInfoRow(
                'IFSC Code',
                profileData?['ifsc_code'] as String? ?? profileData?['ifsc'] as String? ?? 'N/A',
                controller: _ifscCodeController,
                icon: Icons.qr_code,
              ),
              _buildInfoRow(
                'Branch',
                profileData?['bank_branch'] as String? ?? 
                profileData?['branch_name'] as String? ?? 
                profileData?['branch'] as String? ?? 'N/A',
                controller: _bankBranchController,
                icon: Icons.location_city,
              ),
            ],
            cardColor: cardColor,
            borderColor: borderColor,
          ),

          const SizedBox(height: 16),

          // Passport Details
          _buildSectionCard(
            title: 'Passport Details',
            icon: Icons.airplane_ticket,
            children: [
              _buildInfoRow(
                'Passport Number',
                profileData?['passport_number'] as String? ?? 'N/A',
                controller: _passportNumberController,
                icon: Icons.airplane_ticket,
              ),
              _buildInfoRow(
                'Passport Issue Date',
                profileData?['passport_issue_date'] != null
                    ? DateFormat('dd-MM-yyyy').format(DateTime.parse(profileData!['passport_issue_date']))
                    : 'N/A',
                controller: _passportIssueDateController,
                icon: Icons.calendar_today,
                onTap: _isEditMode ? () => _selectDate(context, _passportIssueDateController) : null,
              ),
            ],
            cardColor: cardColor,
            borderColor: borderColor,
          ),
        ],
                    ),
                  );
                }

  Widget _buildPayrollTab(ProfileProvider profileProvider, String userId, Color textColor, bool isDark) {
    final payrollHistory = profileProvider.payrollHistory;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1);

    // Available years from payroll data, plus current year
    final allYears = <int>{
      DateTime.now().year,
      ...payrollHistory.map((p) {
        final date = p['pay_date'] ?? p['payroll_date'] ?? p['month'] ?? p['date'];
        if (date == null) return DateTime.now().year;
        try { return DateTime.parse(date.toString()).year; } catch (_) { return DateTime.now().year; }
      }),
    }.toList()..sort((a, b) => b.compareTo(a));

    // Filter payroll list
    final filtered = payrollHistory.where((p) {
      final rawDate = p['pay_date'] ?? p['payroll_date'] ?? p['month'] ?? p['date'];
      if (rawDate == null) return _selectedMonth == null && _selectedYear == null;
      try {
        final date = DateTime.parse(rawDate.toString());
        if (_selectedMonth != null && date.month != _selectedMonth) return false;
        if (_selectedYear != null && date.year != _selectedYear) return false;
        return true;
      } catch (_) { return true; }
    }).toList();

    final monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];

    // Dropdown button builder helper
    Widget filterDropdown({
      required String hint,
      required int? value,
      required List<DropdownMenuItem<int>> items,
      required void Function(int?) onChanged,
    }) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: value,
            hint: Text(hint, style: const TextStyle(fontSize: 12)),
            isDense: true,
            style: TextStyle(fontSize: 12, color: textColor),
            dropdownColor: cardColor,
            icon: Icon(Icons.arrow_drop_down, size: 18, color: Colors.grey.shade400),
            items: items,
            onChanged: (v) => setState(() => onChanged(v)),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Payroll History',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'View and download your payslips',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Month filter
                  filterDropdown(
                    hint: 'All Months',
                    value: _selectedMonth,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Months', style: TextStyle(fontSize: 12))),
                      ...List.generate(12, (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text(monthNames[i], style: const TextStyle(fontSize: 12)),
                      )),
                    ],
                    onChanged: (v) { _selectedMonth = v; },
                  ),
                  const SizedBox(width: 8),
                  // Year filter
                  filterDropdown(
                    hint: 'All Years',
                    value: _selectedYear,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Years', style: TextStyle(fontSize: 12))),
                      ...allYears.map((y) => DropdownMenuItem(
                        value: y,
                        child: Text('$y', style: const TextStyle(fontSize: 12)),
                      )),
                    ],
                    onChanged: (v) { _selectedYear = v; },
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (filtered.isEmpty)
            Card(
                    elevation: 0,
                    color: cardColor,
                    shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: borderColor),
                    ),
              child: const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No payroll records found'),
                    ],
                  ),
                ),
              ),
            )
          else
            ...filtered.map((payslip) => Card(
              elevation: 0,
              color: cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: borderColor),
              ),
              margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                padding: const EdgeInsets.all(16),
                      child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          payslip['month'] as String? ?? 'Unknown',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (payslip['status'] as String? ?? '').toUpperCase().contains('APPROVED')
                                ? Colors.green.shade50
                                : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            payslip['status'] as String? ?? 'PENDING',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: (payslip['status'] as String? ?? '').toUpperCase().contains('APPROVED')
                                  ? Colors.green.shade700
                                  : Colors.orange.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildPayrollRow('Gross Salary', payslip['gross'] as String? ?? '₹0'),
                    _buildPayrollRow('Total Deductions', payslip['deductions'] as String? ?? '₹0'),
                    _buildPayrollRow('Net Salary', payslip['net'] as String? ?? '₹0'),
                    _buildPayrollRow('Working Days', payslip['workingDays'] as String? ?? '0 days'),
              const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () async {
                            final rawData = payslip['raw_data'] as Map<String, dynamic>?;
                            if (rawData != null) {
                              final payslipId = rawData['id'] as String?;
                              if (payslipId != null) {
                                // Fetch full payslip details
                                final payrollService = PayrollService();
                                final details = await payrollService.getPayslipDetails(payslipId);
                                if (details != null && mounted) {
                                  // Format the data for PayslipDetailScreen
                                  final formattedPayslip = {
                                    'month': payslip['month'] as String? ?? 'Unknown',
                                    'status': details['status'] as String? ?? 'PENDING',
                                    'basic_salary': '₹${NumberFormat('#,##0.00').format(details['basic_salary'] as num? ?? 0)}',
                                    'da': '₹${NumberFormat('#,##0.00').format(details['da'] as num? ?? 0)}',
                                    'hra': '₹${NumberFormat('#,##0.00').format(details['hra'] as num? ?? 0)}',
                                    'special': '₹${NumberFormat('#,##0.00').format(details['special'] as num? ?? 0)}',
                                    'gross': '₹${NumberFormat('#,##0.00').format(details['gross_salary'] as num? ?? 0)}',
                                    'pf': '₹${NumberFormat('#,##0.00').format(details['pf'] as num? ?? 0)}',
                                    'esi': '₹${NumberFormat('#,##0.00').format(details['esi'] as num? ?? 0)}',
                                    'tds': '₹${NumberFormat('#,##0.00').format(details['tds'] as num? ?? 0)}',
                                    'professional_tax': '₹${NumberFormat('#,##0.00').format(details['professional_tax'] as num? ?? 0)}',
                                    'deductions': '₹${NumberFormat('#,##0.00').format(details['deductions'] as num? ?? 0)}',
                                    'net': '₹${NumberFormat('#,##0.00').format(details['net_salary'] as num? ?? 0)}',
                                  };
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PayslipDetailScreen(payslip: formattedPayslip),
                    ),
                  );
                }
                              }
                            }
                          },
                          icon: const Icon(Icons.visibility, size: 16),
                          label: const Text('View'),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () {
                            // TODO: Implement download
                          },
                          icon: const Icon(Icons.download, size: 16),
                          label: const Text('Download'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    required Color cardColor,
    required Color borderColor,
  }) {
                  return Card(
                    elevation: 0,
                    color: cardColor,
                    shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: borderColor),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
                        children: [
                Icon(icon, size: 20, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    TextEditingController? controller,
    TextInputType? keyboardType,
    String? dropdownValue,
    List<String>? dropdownItems,
    Function(String?)? onDropdownChanged,
    bool readOnly = false,
    VoidCallback? onTap,
    IconData? icon,
    int maxLines = 1,
    String? hintText,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          const SizedBox(height: 8),
          if (_isEditMode && controller != null)
            TextFormField(
              controller: controller,
              readOnly: readOnly,
                onTap: onTap,
                keyboardType: keyboardType,
                maxLines: maxLines,
                inputFormatters: inputFormatters,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: hintText,
                prefixIcon: icon != null ? Icon(icon, size: 18, color: Colors.grey.shade600) : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.blue),
                ),
                filled: true,
                fillColor: cardColor,
              ),
            )
          else if (_isEditMode && dropdownItems != null)
            DropdownButtonFormField<String>(
              value: dropdownValue != null && dropdownItems.contains(dropdownValue) 
                  ? dropdownValue 
                  : (dropdownItems.isNotEmpty ? dropdownItems.first : null),
              items: dropdownItems.map((item) => DropdownMenuItem(
                value: item,
                child: Text(item, style: TextStyle(color: textColor)),
              )).toList(),
              onChanged: onDropdownChanged,
              decoration: InputDecoration(
                prefixIcon: icon != null ? Icon(icon, size: 18, color: Colors.grey.shade600) : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.blue),
                ),
                filled: true,
                fillColor: cardColor,
              ),
              style: TextStyle(color: textColor),
            )
          else
              Text(
                value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
        ],
      ),
    );
  }

  Widget _buildPayrollRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Future<void> _showDepartmentEmployees(
    BuildContext context,
    Map<String, dynamic> department,
    ProfileProvider profileProvider,
    Color textColor,
    bool isDark,
  ) async {
    final deptId = department['id'] as String?;
    final deptName = department['name'] as String? ?? 'Unknown';
    
    if (deptId == null) return;

    // Get current user info
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.user;
    final currentProfile = profileProvider.profileData;
    final currentEmployeeId = currentProfile?['employee_id'] as String?;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Fetch employees for this department
      final employees = await profileProvider.getDepartmentEmployees(
        deptId,
        currentUserId: currentUser?.id,
        currentEmployeeId: currentEmployeeId,
      );
      
      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog

      final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
      final borderColor = isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1);

      // Show employees dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.business, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  deptName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: employees.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: Text('No employees found in this department'),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: employees.length,
                    itemBuilder: (context, index) {
                      final employee = employees[index];
                      final name = employee['full_name'] as String? ?? 'Unknown';
                      final empId = employee['employee_id'] as String? ?? 'N/A';
                      final isCurrentUser = employee['is_current_user'] as bool? ?? false;
                      
                      return Card(
                        elevation: 0,
                        color: isCurrentUser ? Colors.blue.shade50 : cardColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: isCurrentUser ? Colors.blue.shade300 : borderColor,
                            width: isCurrentUser ? 1.5 : 1,
                          ),
                        ),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isCurrentUser 
                                ? Colors.blue.shade200 
                                : Colors.blue.shade100,
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: isCurrentUser ? Colors.blue.shade900 : textColor,
                                  ),
                                ),
                              ),
                              if (isCurrentUser)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade700,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'You',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Text(
                            'Employee ID: $empId',
                            style: TextStyle(
                              fontSize: 12, 
                              color: isCurrentUser ? Colors.blue.shade700 : Colors.grey,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading employees: $e')),
      );
    }
  }

  void _showProfilePicturePreview(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          clipBehavior: Clip.none, // Allow close button to be outside
          alignment: Alignment.center,
          children: [
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.9,
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const SizedBox(
                      width: 200,
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => const SizedBox(
                    width: 200,
                    height: 200,
                    child: Icon(Icons.error, size: 50, color: Colors.red),
                  ),
                ),
              ),
            ),
            Positioned(
              top: -15,
              right: -15,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                    ],
                  ),
                  child: const Icon(Icons.close, color: Colors.black, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

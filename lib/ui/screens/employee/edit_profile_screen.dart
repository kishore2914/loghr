import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:loghr_mobile/logic/auth_provider.dart';
import 'package:loghr_mobile/logic/profile_provider.dart';
import 'package:loghr_mobile/data/services/profile_service.dart';
import 'package:flutter/services.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ProfileService _profileService = ProfileService();
  
  bool _isLoading = false;
  bool _isSaving = false;
  
  // Overview Tab - Contact Information
  final TextEditingController _companyEmailController = TextEditingController();
  final TextEditingController _personalEmailController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _alternateController = TextEditingController();
  
  // Overview Tab - Personal Details
  final TextEditingController _dateOfBirthController = TextEditingController();
  String? _gender;
  final TextEditingController _bloodGroupController = TextEditingController();
  String? _maritalStatus;
  final TextEditingController _nationalityController = TextEditingController();
  final TextEditingController _religionController = TextEditingController();
  final TextEditingController _placeOfBirthController = TextEditingController();
  
  // Overview Tab - Employment Details
  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _designationController = TextEditingController();
  final TextEditingController _branchController = TextEditingController();
  final TextEditingController _joiningDateController = TextEditingController();
  String? _employmentType;
  String? _status;
  final TextEditingController _noticePeriodController = TextEditingController();
  
  // Personal Tab - Family Information
  final TextEditingController _fatherNameController = TextEditingController();
  final TextEditingController _motherNameController = TextEditingController();
  final TextEditingController _spouseNameController = TextEditingController();
  final TextEditingController _numberOfChildrenController = TextEditingController();
  
  // Personal Tab - Address Information
  final TextEditingController _currentAddressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();
  final TextEditingController _permanentAddressController = TextEditingController();
  bool _sameAsCurrent = false;
  
  // Personal Tab - Emergency Contact
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
  
  // Documents Tab - Indian Government IDs
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
  
  // Documents Tab - Bank Details
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _accountNumberController = TextEditingController();
  final TextEditingController _ifscCodeController = TextEditingController();
  final TextEditingController _bankBranchController = TextEditingController();
  
  // Documents Tab - Passport Details
  final TextEditingController _passportNumberController = TextEditingController();
  final TextEditingController _passportIssueDateController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadProfileData();
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
  
  Future<void> _loadProfileData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final authProvider = context.read<AuthProvider>();
      final profileProvider = context.read<ProfileProvider>();
      final user = authProvider.user;
      
      if (user == null) return;
      
      // Load fresh profile data
      await profileProvider.loadProfile(user.id);
      final profileData = profileProvider.profileData;
      
      if (profileData != null) {
        // Overview Tab - Contact Information
        _companyEmailController.text = profileData['email'] as String? ?? '';
        _personalEmailController.text = profileData['personal_email'] as String? ?? '';
        _mobileController.text = profileData['phone'] as String? ?? profileData['mobile'] as String? ?? '';
        _alternateController.text = profileData['alternate_phone'] as String? ?? '';
        
        // Overview Tab - Personal Details
        if (profileData['date_of_birth'] != null) {
          final dob = DateTime.parse(profileData['date_of_birth'] as String);
          _dateOfBirthController.text = DateFormat('dd-MM-yyyy').format(dob);
        }
        _gender = profileData['gender'] as String?;
        _bloodGroupController.text = profileData['blood_group'] as String? ?? '';
        _maritalStatus = profileData['marital_status'] as String?;
        _nationalityController.text = profileData['nationality'] as String? ?? '';
        _religionController.text = profileData['religion'] as String? ?? '';
        _placeOfBirthController.text = profileData['place_of_birth'] as String? ?? '';
        
        // Overview Tab - Employment Details
        _departmentController.text = profileData['department'] as String? ?? '';
        _designationController.text = profileData['designation'] as String? ?? profileData['position'] as String? ?? '';
        _branchController.text = profileData['branch'] as String? ?? '';
        if (profileData['date_of_joining'] != null) {
          final doj = DateTime.parse(profileData['date_of_joining'] as String);
          _joiningDateController.text = DateFormat('dd/MM/yyyy').format(doj);
        }
        _employmentType = profileData['employment_type'] as String? ?? 'FULL TIME';
        _status = profileData['status'] as String? ?? (profileData['is_active'] == true ? 'ACTIVE' : 'INACTIVE');
        _noticePeriodController.text = profileData['notice_period'] != null ? '${profileData['notice_period']}' : '30';
        
        // Personal Tab - Family Information
        _fatherNameController.text = profileData['father_name'] as String? ?? '';
        _motherNameController.text = profileData['mother_name'] as String? ?? '';
        _spouseNameController.text = profileData['spouse_name'] as String? ?? '';
        
        final childrenCount = profileData['number_of_children'] as int?;
        _numberOfChildrenController.text = childrenCount != null 
            ? (childrenCount < 0 ? '0' : '$childrenCount') 
            : '';
        
        // Personal Tab - Address Information
        _currentAddressController.text = profileData['current_address'] as String? ?? '';
        _cityController.text = profileData['city'] as String? ?? '';
        _stateController.text = profileData['state'] as String? ?? '';
        _pincodeController.text = profileData['pincode'] as String? ?? '';
        _permanentAddressController.text = profileData['permanent_address'] as String? ?? '';
        
        // Personal Tab - Emergency Contact
        _emergencyContactNameController.text = profileData['emergency_contact_name'] as String? ?? '';
        _emergencyRelationshipController.text = profileData['emergency_contact_relationship'] as String? ?? '';
        _emergencyPhoneController.text = profileData['emergency_contact_phone'] as String? ?? '';
        _emergencyAlternateController.text = profileData['emergency_contact_alternate'] as String? ?? '';
        
        // Personal Tab - Personal Interests
        _hobbiesController.text = profileData['hobbies'] as String? ?? profileData['interests'] as String? ?? '';
        
        // Professional Tab - Education with synonyms and fallbacks
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

        // Professional Tab - Previous Employment
        _previousEmployerController.text = profileData['previous_employer'] as String? ?? '';
        _previousDesignationController.text = profileData['previous_designation'] as String? ?? '';
        if (profileData['previous_employment_from'] != null) {
          final fromDate = DateTime.parse(profileData['previous_employment_from'] as String);
          _previousEmploymentFromController.text = DateFormat('dd-MM-yyyy').format(fromDate);
        }
        if (profileData['previous_employment_to'] != null) {
          final toDate = DateTime.parse(profileData['previous_employment_to'] as String);
          _previousEmploymentToController.text = DateFormat('dd-MM-yyyy').format(toDate);
        }
        _previousSalaryController.text = profileData['previous_salary'] != null ? '${profileData['previous_salary']}' : '';
        _totalExperienceController.text = profileData['total_experience'] != null ? '${profileData['total_experience']}' : '';
        _reasonForLeavingController.text = profileData['reason_for_leaving'] as String? ?? '';
        
        // Professional Tab - Professional Links
        _linkedInController.text = profileData['linkedin_url'] as String? ?? profileData['linkedin'] as String? ?? '';
        _gitHubController.text = profileData['github_url'] as String? ?? profileData['github'] as String? ?? '';
        _portfolioController.text = profileData['portfolio_url'] as String? ?? profileData['portfolio'] as String? ?? '';
        
        // Documents Tab - Indian Government IDs
        _panController.text = profileData['pan'] as String? ?? '';
        _aadhaarController.text = profileData['aadhaar'] as String? ?? '';
        _uanController.text = profileData['uan'] as String? ?? '';
        _pfAccountController.text = profileData['pf_account'] as String? ?? '';
        _pfUanController.text = profileData['pf_uan'] as String? ?? '';
        _esiController.text = profileData['esi'] as String? ?? '';
        _professionalTaxController.text = profileData['professional_tax'] as String? ?? '';
        _lwfController.text = profileData['lwf'] as String? ?? '';
        _drivingLicenseController.text = profileData['driving_license'] as String? ?? '';
        if (profileData['driving_license_expiry'] != null) {
          final dlExp = DateTime.parse(profileData['driving_license_expiry'] as String);
          _dlExpiryController.text = DateFormat('dd-MM-yyyy').format(dlExp);
        }
        
        // Documents Tab - Bank Details
        _bankNameController.text = profileData['bank_name'] as String? ?? '';
        
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
        
        // Documents Tab - Passport Details
        _passportNumberController.text = profileData['passport_number'] as String? ?? '';
        if (profileData['passport_issue_date'] != null) {
          final passportIssue = DateTime.parse(profileData['passport_issue_date'] as String);
          _passportIssueDateController.text = DateFormat('dd-MM-yyyy').format(passportIssue);
        }
      }
    } catch (e) {
      print('Error loading profile data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
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
      
      // Prepare update data
      final updates = <String, dynamic>{
        'email': _companyEmailController.text.trim().isEmpty ? null : _companyEmailController.text.trim(),
        'personal_email': _personalEmailController.text.trim().isEmpty ? null : _personalEmailController.text.trim(),
        'phone': _mobileController.text.trim().isEmpty ? null : _mobileController.text.trim(),
        'mobile': _mobileController.text.trim().isEmpty ? null : _mobileController.text.trim(),
        'alternate_phone': _alternateController.text.trim().isEmpty ? null : _alternateController.text.trim(),
        'date_of_birth': _dateOfBirthController.text.trim().isEmpty ? null : _parseDate(_dateOfBirthController.text.trim()),
        'gender': _gender,
        'blood_group': _bloodGroupController.text.trim().isEmpty ? null : _bloodGroupController.text.trim(),
        'marital_status': _maritalStatus,
        'nationality': _nationalityController.text.trim().isEmpty ? null : _nationalityController.text.trim(),
        'religion': _religionController.text.trim().isEmpty ? null : _religionController.text.trim(),
        'place_of_birth': _placeOfBirthController.text.trim().isEmpty ? null : _placeOfBirthController.text.trim(),
        'department': _departmentController.text.trim().isEmpty ? null : _departmentController.text.trim(),
        'designation': _designationController.text.trim().isEmpty ? null : _designationController.text.trim(),
        'position': _designationController.text.trim().isEmpty ? null : _designationController.text.trim(),
        'branch': _branchController.text.trim().isEmpty ? null : _branchController.text.trim(),
        'date_of_joining': _joiningDateController.text.trim().isEmpty ? null : _parseDate(_joiningDateController.text.trim()),
        'employment_type': _employmentType,
        'status': _status,
        'is_active': _status == 'ACTIVE',
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
        'driving_license_expiry': _dlExpiryController.text.trim().isEmpty ? null : _parseDate(_dlExpiryController.text.trim()),
        'bank_name': _bankNameController.text.trim().isEmpty ? null : _bankNameController.text.trim(),
        'account_number': _accountNumberController.text.trim().isEmpty ? null : _accountNumberController.text.trim(),
        'ifsc_code': _ifscCodeController.text.trim().isEmpty ? null : _ifscCodeController.text.trim(),
        'bank_branch': _bankBranchController.text.trim().isEmpty ? null : _bankBranchController.text.trim(),
        'passport_number': _passportNumberController.text.trim().isEmpty ? null : _passportNumberController.text.trim(),
        'passport_issue_date': _passportIssueDateController.text.trim().isEmpty ? null : _parseDate(_passportIssueDateController.text.trim()),
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      // Remove null values
      updates.removeWhere((key, value) => value == null);
      
      // Update profile
      final success = await _profileService.updateProfile(user.id, updates);
      
      if (success) {
        // Reload profile data
        await profileProvider.loadProfile(user.id);
        
        if (mounted) {
          Navigator.pop(context);
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
  
  String? _parseDate(String dateString) {
    if (dateString.isEmpty) return null;
    
    try {
      // Try different date formats
      List<DateFormat> formats = [
        DateFormat('dd-MM-yyyy'),
        DateFormat('dd/MM/yyyy'),
        DateFormat('MM/dd/yyyy'),
        DateFormat('yyyy-MM-dd'),
      ];
      
      for (var format in formats) {
        try {
          final date = format.parse(dateString);
          return date.toIso8601String();
        } catch (e) {
          continue;
        }
      }
      
      return null;
    } catch (e) {
      return null;
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
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300;
    
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: textColor),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text('Edit Profile', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Edit Profile', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _saveProfile,
            icon: _isSaving 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green),
                  )
                : const Icon(Icons.save, color: Colors.green),
            label: Text(
              'Save Changes',
              style: TextStyle(color: _isSaving ? Colors.grey : Colors.green, fontWeight: FontWeight.bold),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.blue.shade700,
          labelColor: Colors.blue.shade700,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Personal'),
            Tab(text: 'Professional'),
            Tab(text: 'Documents'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(textColor, cardColor, borderColor),
          _buildPersonalTab(textColor, cardColor, borderColor),
          _buildProfessionalTab(textColor, cardColor, borderColor),
          _buildDocumentsTab(textColor, cardColor, borderColor),
        ],
      ),
    );
  }
  
  Widget _buildOverviewTab(Color textColor, Color cardColor, Color borderColor) {
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
              _buildTextField('Company Email', _companyEmailController, icon: Icons.email),
              _buildTextField('Personal Email', _personalEmailController, icon: Icons.email),
              _buildTextField('Mobile', _mobileController, icon: Icons.phone, keyboardType: TextInputType.phone),
              _buildTextField('Alternate', _alternateController, icon: Icons.phone, keyboardType: TextInputType.phone),
            ],
            cardColor: cardColor,
            borderColor: borderColor,
            textColor: textColor,
          ),
          
          const SizedBox(height: 16),
          
          // Personal Details
          _buildSectionCard(
            title: 'Personal Details',
            icon: Icons.person,
            children: [
              _buildTextField(
                'Date of Birth',
                _dateOfBirthController,
                icon: Icons.calendar_today,
                readOnly: true,
                onTap: () => _selectDate(context, _dateOfBirthController),
              ),
              _buildDropdownField(
                'Gender',
                _gender,
                ['Male', 'Female', 'Other'],
                (value) => setState(() => _gender = value),
                icon: Icons.person_outline,
              ),
              _buildTextField('Blood Group', _bloodGroupController),
              _buildDropdownField(
                'Marital Status',
                _maritalStatus,
                ['Single', 'Married', 'Divorced', 'Widowed'],
                (value) => setState(() => _maritalStatus = value),
              ),
              _buildTextField('Nationality', _nationalityController),
              _buildTextField('Religion', _religionController),
              _buildTextField('Place of Birth', _placeOfBirthController),
            ],
            cardColor: cardColor,
            borderColor: borderColor,
            textColor: textColor,
          ),
          
          const SizedBox(height: 16),
          
          // Employment Details
          _buildSectionCard(
            title: 'Employment Details',
            icon: Icons.business_center,
            children: [
              _buildTextField('Department', _departmentController, icon: Icons.business),
              _buildTextField('Designation', _designationController, icon: Icons.business_center),
              _buildTextField('Branch', _branchController, icon: Icons.location_on),
              _buildTextField(
                'Joining Date',
                _joiningDateController,
                icon: Icons.calendar_today,
                readOnly: true,
                onTap: () => _selectDate(context, _joiningDateController, format: DateFormat('dd/MM/yyyy')),
              ),
              _buildDropdownField(
                'Employment Type',
                _employmentType,
                ['FULL TIME', 'PART TIME', 'CONTRACT', 'INTERN'],
                (value) => setState(() => _employmentType = value),
              ),
              _buildDropdownField(
                'Status',
                _status,
                ['ACTIVE', 'INACTIVE'],
                (value) => setState(() => _status = value),
              ),
              _buildTextField('Notice Period (days)', _noticePeriodController, keyboardType: TextInputType.number),
            ],
            cardColor: cardColor,
            borderColor: borderColor,
            textColor: textColor,
          ),
        ],
      ),
    );
  }
  
  Widget _buildPersonalTab(Color textColor, Color cardColor, Color borderColor) {
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
              _buildTextField('Father\'s Name', _fatherNameController),
              _buildTextField('Mother\'s Name', _motherNameController),
              _buildTextField('Spouse\'s Name', _spouseNameController),
              _buildTextField(
                'Number of Children', 
                _numberOfChildrenController, 
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ],
            cardColor: cardColor,
            borderColor: borderColor,
            textColor: textColor,
          ),
          
          const SizedBox(height: 16),
          
          // Address Information
          _buildSectionCard(
            title: 'Address Information',
            icon: Icons.location_on,
            children: [
              _buildTextField('Current Address', _currentAddressController, maxLines: 3),
              _buildTextField('City', _cityController),
              _buildTextField('State', _stateController),
              _buildTextField('Pincode', _pincodeController, keyboardType: TextInputType.number),
              CheckboxListTile(
                title: const Text('Same as current or different'),
                value: _sameAsCurrent,
                onChanged: (value) => setState(() => _sameAsCurrent = value ?? false),
                contentPadding: EdgeInsets.zero,
              ),
              if (!_sameAsCurrent)
                _buildTextField('Permanent Address', _permanentAddressController, maxLines: 3),
            ],
            cardColor: cardColor,
            borderColor: borderColor,
            textColor: textColor,
          ),
          
          const SizedBox(height: 16),
          
          // Emergency Contact
          _buildSectionCard(
            title: 'Emergency Contact',
            icon: Icons.warning_amber,
            children: [
              _buildTextField('Contact Name', _emergencyContactNameController),
              _buildTextField('Relationship', _emergencyRelationshipController),
              _buildTextField('Primary Phone', _emergencyPhoneController, icon: Icons.phone, keyboardType: TextInputType.phone),
              _buildTextField('Alternate Phone', _emergencyAlternateController, icon: Icons.phone, keyboardType: TextInputType.phone),
            ],
            cardColor: cardColor,
            borderColor: borderColor,
            textColor: textColor,
          ),
          
          const SizedBox(height: 16),
          
          // Personal Interests
          _buildSectionCard(
            title: 'Personal Interests',
            icon: Icons.favorite,
            children: [
              _buildTextField(
                'Hobbies & Interests',
                _hobbiesController,
                maxLines: 5,
                hintText: 'Your hobbies, interests, activities...',
              ),
            ],
            cardColor: cardColor,
            borderColor: borderColor,
            textColor: textColor,
          ),
        ],
      ),
    );
  }
  
  Widget _buildProfessionalTab(Color textColor, Color cardColor, Color borderColor) {
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
              _buildTextField('Highest Qualification', _highestQualificationController, hintText: 'B.Tech, MBA, M.Sc, etc'),
              _buildTextField('Institution/University', _universityController, hintText: 'University name'),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField('Year of Completion', _yearOfCompletionController, keyboardType: TextInputType.number, hintText: '2020'),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField('Specialization/Field', _specializationController, hintText: 'Computer Science, Finance, etc'),
                  ),
                ],
              ),
            ],
            cardColor: cardColor,
            borderColor: borderColor,
            textColor: textColor,
          ),

          const SizedBox(height: 16),

          // Previous Employment
          _buildSectionCard(
            title: 'Previous Employment',
            icon: Icons.work_history,
            children: [
              _buildTextField('Previous Employer', _previousEmployerController, hintText: 'Company name'),
              _buildTextField('Previous Designation', _previousDesignationController, hintText: 'Job title'),
              Row(
                children: [
                   Expanded(
                    child: _buildTextField(
                      'Employment From', 
                      _previousEmploymentFromController, 
                      icon: Icons.calendar_today,
                      readOnly: true,
                      onTap: () => _selectDate(context, _previousEmploymentFromController),
                      hintText: 'dd-mm-yyyy',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      'Employment To', 
                      _previousEmploymentToController, 
                      icon: Icons.calendar_today,
                      readOnly: true,
                      onTap: () => _selectDate(context, _previousEmploymentToController),
                      hintText: 'dd-mm-yyyy',
                    ),
                  ),
                ],
              ),
              _buildTextField('Previous Salary', _previousSalaryController, keyboardType: TextInputType.number),
              _buildTextField('Total Experience (Years)', _totalExperienceController, keyboardType: TextInputType.number),
              _buildTextField('Reason for Leaving', _reasonForLeavingController, maxLines: 3, hintText: 'Reason for leaving previous employment'),
            ],
            cardColor: cardColor,
            borderColor: borderColor,
            textColor: textColor,
          ),

          const SizedBox(height: 16),

          // Professional Links
          _buildSectionCard(
            title: 'Professional Links',
            icon: Icons.link,
            children: [
              _buildTextField('LinkedIn', _linkedInController, hintText: 'https://linkedin.com/in/username'),
              _buildTextField('GitHub', _gitHubController, hintText: 'https://github.com/username'),
              _buildTextField('Portfolio', _portfolioController, hintText: 'https://yourwebsite.com'),
            ],
            cardColor: cardColor,
            borderColor: borderColor,
            textColor: textColor,
          ),
        ],
      ),
    );
  }
  
  Widget _buildDocumentsTab(Color textColor, Color cardColor, Color borderColor) {
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
              _buildTextField('PAN Number', _panController),
              _buildTextField('Aadhaar Number', _aadhaarController),
              _buildTextField('UAN Number', _uanController),
              _buildTextField('PF Account', _pfAccountController),
              _buildTextField('PF UAN', _pfUanController),
              _buildTextField('ESI Number', _esiController),
              _buildTextField('Professional Tax', _professionalTaxController),
              _buildTextField('LWF Number', _lwfController),
              _buildTextField('Driving License', _drivingLicenseController),
              _buildTextField(
                'DL Expiry',
                _dlExpiryController,
                icon: Icons.calendar_today,
                readOnly: true,
                onTap: () => _selectDate(context, _dlExpiryController),
              ),
            ],
            cardColor: cardColor,
            borderColor: borderColor,
            textColor: textColor,
          ),
          
          const SizedBox(height: 16),
          
          // Bank Details
          _buildSectionCard(
            title: 'Bank Details',
            icon: Icons.account_balance,
            children: [
              _buildTextField('Bank Name', _bankNameController),
              _buildTextField('Account Number', _accountNumberController, keyboardType: TextInputType.number),
              _buildTextField('IFSC Code', _ifscCodeController),
              _buildTextField('Branch', _bankBranchController),
            ],
            cardColor: cardColor,
            borderColor: borderColor,
            textColor: textColor,
          ),
          
            const SizedBox(height: 16),
          
          // Passport Details
          _buildSectionCard(
            title: 'Passport Details',
            icon: Icons.airplane_ticket,
            children: [
              _buildTextField('Passport Number', _passportNumberController),
              _buildTextField(
                'Passport Issue Date',
                _passportIssueDateController,
                icon: Icons.calendar_today,
                readOnly: true,
                onTap: () => _selectDate(context, _passportIssueDateController),
              ),
            ],
            cardColor: cardColor,
            borderColor: borderColor,
            textColor: textColor,
          ),
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
    required Color textColor,
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
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

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    IconData? icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? hintText,
    bool readOnly = false,
    VoidCallback? onTap,
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
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
            readOnly: readOnly,
            onTap: onTap,
            keyboardType: keyboardType,
            maxLines: maxLines,
            inputFormatters: inputFormatters,
          style: TextStyle(color: textColor),
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
          ),
        ],
      ),
    );
  }
  
  Widget _buildDropdownField(
    String label,
    String? value,
    List<String> items,
    Function(String?) onChanged, {
    IconData? icon,
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
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: value,
            items: items.map((item) => DropdownMenuItem(
              value: item,
              child: Text(item, style: TextStyle(color: textColor)),
            )).toList(),
            onChanged: onChanged,
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
          ),
        ],
        ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Assuming provider is used globally, though AdminService is instantiated directly in other screens. 
// Ideally we should use a provider for state management, but following the pattern in admin_payroll_screen.dart (StatefulWidget + Service).

import 'package:loghr_mobile/data/services/admin_service.dart';
import 'package:loghr_mobile/logic/admin_provider.dart';
import 'package:loghr_mobile/utils/helpers.dart';
import 'package:intl/intl.dart';

class AdminEmployeesScreen extends StatefulWidget {
  const AdminEmployeesScreen({super.key});

  @override
  State<AdminEmployeesScreen> createState() => _AdminEmployeesScreenState();
}

class _AdminEmployeesScreenState extends State<AdminEmployeesScreen> {
  final AdminService _adminService = AdminService();
  final TextEditingController _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _filteredEmployees = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _selectedDepartment;
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
    // Trigger provider update for stats
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).loadDashboardData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    setState(() => _isLoading = true);
    try {
      final employees = await _adminService.getAllEmployees();
      setState(() {
        _employees = employees;
        _filteredEmployees = employees;
        _isLoading = false;
      });
      _filterEmployees(); 
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading employees: $e')),
        );
      }
    }
  }

  void _filterEmployees() {
    setState(() {
      _filteredEmployees = _employees.where((emp) {
        final name = (emp['full_name'] ?? emp['name'] ?? '').toString().toLowerCase();
        final email = (emp['email'] ?? '').toString().toLowerCase();
        final role = (emp['role'] ?? '').toString().toLowerCase();
        final dept = (emp['department'] ?? '').toString();
        final status = (emp['is_active'] ?? true) ? 'Active' : 'Inactive';

        final matchesSearch = _searchQuery.isEmpty || 
                             name.contains(_searchQuery.toLowerCase()) || 
                             email.contains(_searchQuery.toLowerCase()) || 
                             role.contains(_searchQuery.toLowerCase());
        
        final matchesDept = _selectedDepartment == null || dept == _selectedDepartment;
        final matchesStatus = _selectedStatus == null || status == _selectedStatus;

        return matchesSearch && matchesDept && matchesStatus;
      }).toList();
    });
  }

  void _openEmployeeForm({Map<String, dynamic>? employee}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EmployeeFormScreen(
          employee: employee,
          onSave: (data) async {
            bool success;
            if (employee == null) {
              success = await _adminService.createEmployee(data);
            } else {
              success = await _adminService.updateEmployee(employee['id'], data);
            }

            if (success) {
              if (mounted) _loadEmployees();
              return true;
            }
            return false;
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton(
        heroTag: 'admin_employees_fab',
        onPressed: () => _openEmployeeForm(),
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Employees',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manage your team members',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _openEmployeeForm(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Employee'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Stats Row
            // Stats Grid 2x2
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Consumer<AdminProvider>(
                builder: (context, provider, _) {
                  return GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.5, // Adjusts the height of cards relative to width
                    children: [
                      _buildStatCard(
                        'Total Employees',
                        '${provider.totalEmployees}',
                        Icons.people_outline,
                        isDark,
                      ),
                      _buildStatCard(
                        'Active',
                        '${provider.totalActive}',
                        Icons.business_center_outlined,
                        isDark,
                      ),
                      _buildStatCard(
                        'On Leave',
                        '${provider.onLeaveToday}',
                        Icons.calendar_today_outlined,
                        isDark,
                      ),
                       _buildStatCard(
                        'Departments',
                        '${provider.departmentStats.length}',
                        Icons.apartment_outlined,
                        isDark,
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            // Search & Filters
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // Search Bar
                  TextField(
                    controller: _searchController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: cardColor,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.withOpacity(0.1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.withOpacity(0.1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Colors.blue, width: 1.5),
                      ),
                    ),
                    onChanged: (value) {
                      _searchQuery = value;
                      _filterEmployees();
                    },
                  ),
                  const SizedBox(height: 12),
                  // Filters Row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip(
                          label: _selectedDepartment ?? 'All Depts',
                          icon: Icons.business,
                          isSelected: _selectedDepartment != null,
                          onTap: _showDepartmentFilter,
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: _selectedStatus ?? 'All Status',
                          icon: Icons.filter_alt_outlined,
                          isSelected: _selectedStatus != null,
                          onTap: _showStatusFilter,
                          isDark: isDark,
                        ),
                         const SizedBox(width: 8),
                        _buildFilterChip(
                          label: 'Export',
                          icon: Icons.download_outlined,
                          isSelected: false,
                          onTap: () {}, // Placeholder
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 10),

            // Employee List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredEmployees.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              Text(
                                'No employees found',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          itemCount: _filteredEmployees.length,
                          itemBuilder: (context, index) {
                            final emp = _filteredEmployees[index];
                            return _buildEmployeeCard(emp, isDark);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, bool isDark) {
    return Container(
      // width: 140, // Removed fixed width for GridView
      // margin: const EdgeInsets.only(right: 12, top: 4, bottom: 4), // GridView handles spacing
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Icon(icon, size: 16, color: Colors.grey.shade600),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected 
              ? Colors.blue.withOpacity(0.1) 
              : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue.withOpacity(0.3) : Colors.grey.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
             Icon(
              icon, 
              size: 16, 
              color: isSelected ? Colors.blue : Colors.grey.shade600
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.blue : (isDark ? Colors.white : Colors.black87),
              ),
            ),
            if (!isSelected) ...[
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey.shade500),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeCard(Map<String, dynamic> emp, bool isDark) {
    final name = emp['full_name'] ?? emp['name'] ?? 'Unknown';
    final email = emp['email'] ?? 'No Email';
    final dept = emp['department'] ?? 'General';
    final designation = emp['designation'] ?? 'Staff';
    final isActive = emp['is_active'] ?? true;
    final avatarUrl = emp['avatar_url'] as String?;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openEmployeeForm(employee: emp),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar with Status Badge
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: isDark ? Colors.blue.shade900.withOpacity(0.3) : Colors.blue.shade50,
                      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl == null 
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: TextStyle(
                              color: isDark ? Colors.blue.shade200 : Colors.blue.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          )
                        : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: isActive ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                          border: Border.all(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                
                // Employee Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        designation,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.business, size: 12, color: Colors.blue.shade400),
                          const SizedBox(width: 4),
                          Text(
                            dept,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.blue.shade400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Quick Actions
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => _openEmployeeForm(employee: emp),
                      color: Colors.grey,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _showDepartmentFilter() async {
    // Get unique departments
    final depts = _employees
        .map((e) => e['department'] as String?)
        .where((d) => d != null && d.isNotEmpty)
        .toSet()
        .toList();
    
    if (depts.isEmpty) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Department',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _selectedDepartment == null,
                  onSelected: (_) => Navigator.pop(context, null),
                ),
                ...depts.map((d) => FilterChip(
                  label: Text(d!),
                  selected: _selectedDepartment == d,
                  onSelected: (_) => Navigator.pop(context, d),
                )),
              ],
            ),
          ],
        ),
      ),
    );

    // If modal dismissed without selection, selected is null (but we want to clear if explicitly All selected)
    // Here we can check if it changed.
    setState(() {
      _selectedDepartment = selected;
      _filterEmployees();
    });
  }

  void _showStatusFilter() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _selectedStatus == null,
                  onSelected: (_) => Navigator.pop(context, null),
                ),
                FilterChip(
                  label: const Text('Active'),
                  selected: _selectedStatus == 'Active',
                  onSelected: (_) => Navigator.pop(context, 'Active'),
                ),
                FilterChip(
                  label: const Text('Inactive'),
                  selected: _selectedStatus == 'Inactive',
                  onSelected: (_) => Navigator.pop(context, 'Inactive'),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    setState(() {
      _selectedStatus = selected;
      _filterEmployees();
    });
  }
}

class EmployeeFormScreen extends StatefulWidget {
  final Map<String, dynamic>? employee;
  final Future<bool> Function(Map<String, dynamic> data) onSave;

  const EmployeeFormScreen({
    super.key,
    this.employee,
    required this.onSave,
  });

  @override
  State<EmployeeFormScreen> createState() => _EmployeeFormScreenState();
}

class _EmployeeFormScreenState extends State<EmployeeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _designationController;
  late TextEditingController _departmentController;
  late TextEditingController _empIdController;
  
  String _role = 'employee';
  bool _isActive = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final emp = widget.employee ?? {};
    _nameController = TextEditingController(text: emp['full_name'] ?? emp['name'] ?? '');
    _emailController = TextEditingController(text: emp['email'] ?? '');
    _phoneController = TextEditingController(text: emp['phone'] ?? '');
    _designationController = TextEditingController(text: emp['designation'] ?? '');
    _departmentController = TextEditingController(text: emp['department'] ?? '');
    _empIdController = TextEditingController(text: emp['employee_id'] ?? '');
    
    _role = emp['role'] ?? 'employee';
    _isActive = emp['is_active'] ?? true;

    // Auto-generate ID if empty (for new records)
    _nameController.addListener(_onNameChanged);
  }

  void _onNameChanged() {
    if (widget.employee == null && (_empIdController.text.isEmpty || _empIdController.text.startsWith('EMP-'))) {
      setState(() {
        _empIdController.text = Helpers.generateEmployeeCode(_nameController.text.trim());
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _designationController.dispose();
    _departmentController.dispose();
    _empIdController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final data = {
      'full_name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim(),
      'designation': _designationController.text.trim(),
      'department': _departmentController.text.trim(),
      'employee_id': _empIdController.text.trim(),
      'role': _role,
      'is_active': _isActive,
      // 'updated_at': DateTime.now().toIso8601String(), // Typically handled by DB trigger
    };
    
    // For new records
    if (widget.employee == null) {
      data['created_at'] = DateTime.now().toIso8601String();
    }

    final success = await widget.onSave(data);

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Employee saved successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save employee')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.employee == null ? 'Add Employee' : 'Edit Employee'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
              : const Text('SAVE', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView( // Prevents overflow
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('Personal Information'),
                const SizedBox(height: 16),
                _buildTextField('Full Name', _nameController, Icons.person, validator: (v) => v!.isEmpty ? 'Required' : null),
                const SizedBox(height: 16),
                _buildTextField('Email', _emailController, Icons.email, keyboardType: TextInputType.emailAddress, validator: (v) => v!.isEmpty ? 'Required' : null),
                const SizedBox(height: 16),
                _buildTextField('Phone', _phoneController, Icons.phone, keyboardType: TextInputType.phone),
                
                const SizedBox(height: 32),
                _buildSectionTitle('Employment Details'),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildTextField('Employee ID', _empIdController, Icons.badge),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      padding: const EdgeInsets.only(top: 10),
                      onPressed: () {
                        setState(() {
                          _empIdController.text = Helpers.generateEmployeeCode(_nameController.text.trim());
                        });
                      },
                      tooltip: 'Regenerate Code',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTextField('Department', _departmentController, Icons.business),
                const SizedBox(height: 16),
                _buildTextField('Designation', _designationController, Icons.work),
                
                const SizedBox(height: 24),
                _buildDropdown(
                  'Role', 
                  _role, 
                  ['employee', 'admin', 'manager', 'hr'], 
                  (val) => setState(() => _role = val!),
                ),
                
                const SizedBox(height: 24),
                SwitchListTile(
                  title: const Text('Active Status'),
                  subtitle: const Text('Employee can access the system'),
                  value: _isActive,
                  onChanged: (val) => setState(() => _isActive = val),
                  contentPadding: EdgeInsets.zero,
                ),
                
                const SizedBox(height: 40), // Bottom padding
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.blue.shade700,
      ),
    );
  }

  Widget _buildTextField(
    String label, 
    TextEditingController controller, 
    IconData icon, 
    {TextInputType? keyboardType, String? Function(String?)? validator}
  ) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        filled: true,
        fillColor: Theme.of(context).cardColor,
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        filled: true,
        fillColor: Theme.of(context).cardColor,
      ),
      items: items.map((item) => DropdownMenuItem(
        value: item,
        child: Text(item.toUpperCase()),
      )).toList(),
      onChanged: onChanged,
    );
  }
}

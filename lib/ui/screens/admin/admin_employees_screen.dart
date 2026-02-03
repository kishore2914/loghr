import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Assuming provider is used globally, though AdminService is instantiated directly in other screens. 
// Ideally we should use a provider for state management, but following the pattern in admin_payroll_screen.dart (StatefulWidget + Service).

import 'package:loghr_mobile/data/services/admin_service.dart';
import 'package:loghr_mobile/utils/helpers.dart';

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

  @override
  void initState() {
    super.initState();
    _loadEmployees();
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
      if (_searchQuery.isEmpty) {
        _filteredEmployees = _employees;
      } else {
        final query = _searchQuery.toLowerCase();
        _filteredEmployees = _employees.where((emp) {
          final name = (emp['full_name'] ?? emp['name'] ?? '').toString().toLowerCase();
          final email = (emp['email'] ?? '').toString().toLowerCase();
          final role = (emp['role'] ?? '').toString().toLowerCase();
          return name.contains(query) || email.contains(query) || role.contains(query);
        }).toList();
      }
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

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Employees'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEmployees,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'admin_employees_fab',
        onPressed: () => _openEmployeeForm(),
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                     BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search employees...',
                    prefixIcon: const Icon(Icons.search),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onChanged: (value) {
                    _searchQuery = value;
                    _filterEmployees();
                  },
                ),
              ),
            ),

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
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _filteredEmployees.length,
                          itemBuilder: (context, index) {
                            final emp = _filteredEmployees[index];
                            final name = emp['full_name'] ?? emp['name'] ?? 'Unknown';
                            final email = emp['email'] ?? 'No Email';
                            final role = emp['role'] ?? 'Employee';
                            final isActive = emp['is_active'] ?? true;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: CircleAvatar(
                                  backgroundColor: isActive ? Colors.blue.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                                  child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                                    style: TextStyle(
                                      color: isActive ? Colors.blue : Colors.grey,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  name,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(email),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        role.toUpperCase(),
                                        style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                                onTap: () => _openEmployeeForm(employee: emp),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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

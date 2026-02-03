import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:loghr_mobile/data/services/admin_service.dart';
import 'package:loghr_mobile/config/supabase_config.dart';

class AdminPayrollScreen extends StatefulWidget {
  const AdminPayrollScreen({super.key});

  @override
  State<AdminPayrollScreen> createState() => _AdminPayrollScreenState();
}

class _AdminPayrollScreenState extends State<AdminPayrollScreen> with SingleTickerProviderStateMixin {
  final AdminService _adminService = AdminService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _horizontalScrollController = ScrollController();
  
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  int _selectedTab = 0;
  
  List<Map<String, dynamic>> _payrollEmployees = [];
  Map<String, dynamic> _summary = {};
  Map<String, dynamic> _statutoryCompliance = {};
  bool _isLoading = true;
  String _searchQuery = '';
  int _itemsPerPage = 10;
  int _currentPage = 1;

  late TabController _tabController;

  Future<void> _processPayroll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Process Payroll'),
        content: Text('Are you sure you want to process payroll for ${DateFormat('MMMM yyyy').format(DateTime(_selectedYear, _selectedMonth))}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('PROCESS')),
        ],
      ),
    );

    if (confirmed == true) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Processing payroll...')),
        );
      }
      
      final success = await _adminService.processPayroll(month: _selectedMonth, year: _selectedYear);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success ? 'Payroll processed successfully' : 'Failed to process payroll')),
        );
        if (success) _loadPayrollData();
      }
    }
  }

  Future<void> _addSalaryComponent() async {
     await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Salary Component'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(decoration: InputDecoration(labelText: 'Component Name')),
            SizedBox(height: 8),
            TextField(decoration: InputDecoration(labelText: 'Default Amount')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(onPressed: () {
            Navigator.pop(context);
             ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Component added (Mock)')),
            );
          }, child: const Text('ADD')),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedTab = _tabController.index;
        });
      }
    });
    _loadPayrollData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPayrollData() async {
    setState(() => _isLoading = true);
    
    try {
      final results = await Future.wait([
        _adminService.getPayrollSummary(month: _selectedMonth, year: _selectedYear),
        _adminService.getPayrollEmployees(month: _selectedMonth, year: _selectedYear),
        _adminService.getStatutoryCompliance(month: _selectedMonth, year: _selectedYear),
      ]);

      setState(() {
        _summary = results[0] as Map<String, dynamic>;
        _payrollEmployees = results[1] as List<Map<String, dynamic>>;
        _statutoryCompliance = results[2] as Map<String, dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error loading payroll data: $e');
    }
  }

  List<Map<String, dynamic>> get _filteredEmployees {
    List<Map<String, dynamic>> filtered = _payrollEmployees;
    
    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((emp) {
        final name = (emp['employee_name'] as String? ?? '').toLowerCase();
        final code = (emp['employee_code'] as String? ?? '').toLowerCase();
        final pan = (emp['pan'] as String? ?? '').toLowerCase();
        return name.contains(query) || code.contains(query) || pan.contains(query);
      }).toList();
    }
    
    return filtered;
  }

  List<Map<String, dynamic>> get _paginatedEmployees {
    final filtered = _filteredEmployees;
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    return filtered.length > startIndex
        ? filtered.sublist(startIndex, endIndex > filtered.length ? filtered.length : endIndex)
        : [];
  }

  int get _totalPages {
    return (_filteredEmployees.length / _itemsPerPage).ceil();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formatCurrency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Payroll'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Fixed Header Section - No scrolling
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header Section
                      _buildHeader(),
                      const SizedBox(height: 10),
                      
                      // Pay Period Selectors
                      _buildPayPeriodSelector(),
                      const SizedBox(height: 10),
                      
                      // Summary Cards
                      _buildSummaryCards(formatCurrency),
                      const SizedBox(height: 10),
                      
                      // Tabs
                      _buildTabs(),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                // Tab Content - Takes remaining space
                Expanded(
                  child: _buildTabContent(formatCurrency, isDark),
                ),
                // Pagination Controls
                _buildPaginationControls(),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 400;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isSmallScreen)
              // Stack vertically on small screens
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'India Payroll System',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '₹',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.orange[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _processPayroll(),
                      icon: const Icon(Icons.play_arrow, size: 16),
                      label: const Text('Process Payroll', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                ],
              )
            else
              // Horizontal layout on larger screens
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            'India Payroll System',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '₹',
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.orange[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _processPayroll(),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Process Payroll'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 4),
            Text(
              'PF • ESI • TDS • Professional Tax Compliant',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPayPeriodSelector() {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    
    final currentYear = DateTime.now().year;
    final years = List.generate(5, (index) => currentYear - 2 + index);

    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<int>(
            value: _selectedMonth,
            decoration: InputDecoration(
              labelText: 'Month',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: months.asMap().entries.map((entry) {
              return DropdownMenuItem(
                value: entry.key + 1,
                child: Text(entry.value),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedMonth = value;
                  _currentPage = 1; // Reset to first page when changing month
                });
                _loadPayrollData();
              }
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<int>(
            value: _selectedYear,
            decoration: InputDecoration(
              labelText: 'Year',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: years.map((year) {
              return DropdownMenuItem(
                value: year,
                child: Text(year.toString()),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedYear = value;
                  _currentPage = 1; // Reset to first page when changing year
                });
                _loadPayrollData();
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards(NumberFormat formatCurrency) {
    final totalEmployees = _summary['total_employees'] as int? ?? 0;
    final paidCount = _summary['paid_count'] as int? ?? 0;
    final pendingCount = _summary['pending_count'] as int? ?? 0;
    final totalAmount = (_summary['total_amount'] as num?)?.toDouble() ?? 0.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildSummaryCard(
            'Total Employees',
            '$totalEmployees',
            Icons.people_alt_rounded,
            const Color(0xFF137FEC),
            const Color(0xFFE8F1FF),
          ),
          const SizedBox(width: 12),
          _buildSummaryCard(
            'Paid This Month',
            '$paidCount',
            Icons.check_circle_rounded,
            const Color(0xFF10B981),
            const Color(0xFFECFDF5),
          ),
          const SizedBox(width: 12),
          _buildSummaryCard(
            'Pending Payment',
            '$pendingCount',
            Icons.access_time_filled_rounded,
            const Color(0xFFF59E0B),
            const Color(0xFFFFFBEB),
          ),
          const SizedBox(width: 12),
          _buildSummaryCard(
            'Total Amount (₹)',
            formatCurrency.format(totalAmount).replaceAll('₹', ''),
            Icons.trending_up_rounded,
            const Color(0xFF8B5CF6),
            const Color(0xFFF5F3FF),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color, Color bgColor) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: const Color(0xFF137FEC),
        unselectedLabelColor: Colors.grey,
        indicator: UnderlineTabIndicator(
          borderSide: const BorderSide(color: Color(0xFF137FEC), width: 3),
          insets: const EdgeInsets.symmetric(horizontal: 16),
        ),
        tabs: const [
          Tab(text: 'Monthly Payroll'),
          Tab(text: 'Salary Components'),
          Tab(text: 'Bank Transfer'),
          Tab(text: 'Gratuity'),
          Tab(text: 'Statutory Compliance'),
          Tab(text: 'Parameters'),
        ],
        onTap: (index) {
          setState(() => _selectedTab = index);
        },
      ),
    );
  }

  Widget _buildTabContent(NumberFormat formatCurrency, bool isDark) {
    switch (_selectedTab) {
      case 0:
        return _buildMonthlyPayrollTab(formatCurrency, isDark);
      case 1:
        return _buildSalaryComponentsTab(formatCurrency, isDark);
      case 2:
        return _buildBankTransferTab(formatCurrency, isDark);
      case 3:
        return _buildGratuityTab(formatCurrency, isDark);
      case 4:
        return _buildStatutoryComplianceTab(formatCurrency, isDark);
      case 5:
        return _buildParametersTab(isDark);
      default:
        return _buildMonthlyPayrollTab(formatCurrency, isDark);
    }
  }


  Widget _buildParametersTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payroll Parameters',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildParameterGroup('Retirement Benefits', [
            _buildParameterRow('PF Employee Contribution', '12%'),
            _buildParameterRow('PF Employer Contribution', '13.15% (incl. admin)'),
            _buildParameterRow('Gratuity Cap', '₹20,00,000'),
          ]),
          const SizedBox(height: 24),
          _buildParameterGroup('Statutory Taxes', [
            _buildParameterRow('Professional Tax (PT)', 'Varies by State'),
            _buildParameterRow('ESI Employee Contribution', '0.75%'),
            _buildParameterRow('ESI Employer Contribution', '3.25%'),
          ]),
        ],
      ),
    );
  }

  Widget _buildParameterGroup(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.blue.shade700),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withOpacity(0.1)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildParameterRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMonthlyPayrollTab(NumberFormat formatCurrency, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Status Banner
          _buildStatusBanner(),
          const SizedBox(height: 3),
          
          // Search Bar
          _buildSearchBar(),
          const SizedBox(height: 3),
          
          // Pagination Info
          _buildPaginationInfo(),
          const SizedBox(height: 3),
          
          // Employee Table - Takes remaining space
          Expanded(
            child: _buildEmployeeTable(formatCurrency, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    final paidCount = _summary['paid_count'] as int? ?? 0;
    final totalEmployees = _summary['total_employees'] as int? ?? 0;
    final monthName = DateFormat('MMMM yyyy').format(DateTime(_selectedYear, _selectedMonth));
    final allPaid = paidCount >= totalEmployees && totalEmployees > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2FE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBAE6FD)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_outline,
              color: const Color(0xFF0369A1),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  allPaid ? 'All Employees Paid' : 'Payroll Status',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0C4A6E),
                  ),
                ),
                Text(
                  '$paidCount employee(s) have been paid for $monthName',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF0369A1),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by name, employee code, or PAN...',
          prefixIcon: const Icon(Icons.search, size: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: Theme.of(context).cardColor,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          isDense: true,
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
            _currentPage = 1; // Reset to first page when searching
          });
        },
      ),
    );
  }

  // Salary Components Tab
  Widget _buildSalaryComponentsTab(NumberFormat formatCurrency, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Salary Structure Setup',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    Text(
                      '${_summary['total_employees'] ?? 0} of ${_summary['total_employees'] ?? 0} employees have salary configured',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _addSalaryComponent(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Component', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: _payrollEmployees.length,
              itemBuilder: (context, index) {
                return _buildSalaryComponentCard(_payrollEmployees[index], formatCurrency);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalaryComponentCard(Map<String, dynamic> employee, NumberFormat formatCurrency) {
    final name = employee['employee_name'] as String? ?? 'Unknown';
    final code = employee['employee_code'] as String? ?? '';
    final basic = (employee['basic_salary'] as num?)?.toDouble() ?? 0.0;
    final da = (employee['da'] as num?)?.toDouble() ?? 0.0;
    final hra = (employee['hra'] as num?)?.toDouble() ?? 0.0;
    final conveyance = (employee['conveyance'] as num?)?.toDouble() ?? 0.0;
    final medical = (employee['medical'] as num?)?.toDouble() ?? 0.0;
    final special = (employee['special'] as num?)?.toDouble() ?? 0.0;
    final monthlyGross = basic + da + hra + conveyance + medical + special;
    final isConfigured = monthlyGross > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isConfigured ? const Color(0xFFBAE6FD) : const Color(0xFFFEF3C7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isConfigured ? const Color(0xFFDCFCE7) : const Color(0xFFFFEDD5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isConfigured ? 'CONFIGURED' : 'NOT CONFIGURED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isConfigured ? const Color(0xFF166534) : const Color(0xFF9A3412),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text('$code • PAN: ${employee['pan'] ?? 'N/A'}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ],
                  ),
                ),
                if (isConfigured) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('TOTAL MONTHLY SALARY', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                      Text(formatCurrency.format(monthlyGross), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    ],
                  ),
                ] else
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      minimumSize: const Size(80, 28),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      elevation: 0,
                    ),
                    child: const Text('Set Up Salary', style: TextStyle(fontSize: 11)),
                  ),
              ],
            ),
          ),
          // Component Grid (only if configured)
          if (isConfigured)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
              ),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                childAspectRatio: 2.2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                children: [
                  _buildSalaryField('BASIC SALARY', formatCurrency.format(basic)),
                  _buildSalaryField('DA', formatCurrency.format(da)),
                  _buildSalaryField('HRA', formatCurrency.format(hra)),
                  _buildSalaryField('CONVEYANCE', formatCurrency.format(conveyance)),
                  _buildSalaryField('MEDICAL', formatCurrency.format(medical)),
                  _buildSalaryField('SPECIAL', formatCurrency.format(special)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSalaryField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.start,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.start,
        ),
      ],
    );
  }

  // Statutory Compliance Tab
  Widget _buildStatutoryComplianceTab(NumberFormat formatCurrency, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Statutory Compliance',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 16),
          _buildComplianceSection(
            'Provident Fund (PF)',
            'Applicable for employees with Basic + DA ≤ ₹15,000 (voluntary if higher).',
            [
              ['Employee Contribution', '12% of Basic + DA'],
              ['Employer Contribution', '13% (12% EPF + 0.5% EDLI + 0.5% Admin)'],
            ],
            const Color(0xFF7C3AED),
            const Color(0xFFF5F3FF),
          ),
          const SizedBox(height: 16),
          _buildComplianceSection(
            'Employee State Insurance (ESI)',
            'Applicable for employees with Gross Salary ≤ ₹21,000.',
            [
              ['Employee Contribution', '0.75% of Gross Salary'],
              ['Employer Contribution', '3.25% of Gross Salary'],
            ],
            const Color(0xFF2563EB),
            const Color(0xFFEFF6FF),
          ),
          const SizedBox(height: 24),
          const Text(
            'Example Calculation (PF)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildExampleTable([
            ['Description', 'Value'],
            ['Monthly Basic + DA', '₹15,000'],
            ['Employee PF (12%)', '₹1,800'],
            ['Employer PF (13%)', '₹1,950'],
            ['Total PF Deposit', '₹3,750'],
          ]),
        ],
      ),
    );
  }

  Widget _buildComplianceSection(String title, String subtitle, List<List<String>> contributions, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 11, color: color.withOpacity(0.8))),
          const SizedBox(height: 12),
          ...contributions.map((c) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(c[0], style: const TextStyle(fontSize: 12)),
                Text(c[1], style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildDueDateChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _getColorShade(color, 700),
        ),
      ),
    );
  }

  Widget _buildComplianceCard(
    String title,
    String subtitle,
    String employeeAmount,
    String employerAmount,
    String totalAmount,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.start,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _getColorShade(color, 700),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          _buildComplianceRow('Employee', employeeAmount),
          _buildComplianceRow('Employer', employerAmount),
          const Divider(height: 24),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    'Total Deposit',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _getColorShade(color, 700),
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.start,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  totalAmount,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _getColorShade(color, 700),
                  ),
                  textAlign: TextAlign.end,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComplianceRow(String label, String amount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.start,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            amount,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.end,
          ),
        ],
      ),
    );
  }

  Widget _buildDeadlineRow(String title, String deadline) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            deadline,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // Gratuity Tab
  Widget _buildGratuityTab(NumberFormat formatCurrency, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gratuity Management',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 16),
          _buildInfoBox(
            'Eligibility Criteria',
            'An employee is eligible for gratuity if they meet any of the following conditions:',
            [
              'Completion of 5 years of continuous service.',
              'Retirement or resignation.',
              'Death or disablement due to accident or disease (5-year rule doesn\'t apply).',
            ],
            const Color(0xFF0369A1),
            const Color(0xFFF0F9FF),
          ),
          const SizedBox(height: 16),
          _buildInfoBox(
            'Calculation Formula',
            'Gratuity is calculated as per the Payment of Gratuity Act, 1972:',
            [
              'Formula: (15 / 26) * Last Drawn Salary * Tenure',
              'Last Drawn Salary = Basic + DA',
              'Tenure = Number of years of service (rounded to nearest year if > 6 months).',
            ],
            const Color(0xFF0D9488),
            const Color(0xFFF0FDFA),
          ),
          const SizedBox(height: 24),
          const Text(
            'Example Calculation',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildExampleTable([
            ['Description', 'Value'],
            ['Last Drawn Salary (Basic + DA)', '₹50,000'],
            ['Tenure (Years of Service)', '10 Years'],
            ['Calculation', '(15/26) * 50,000 * 10'],
            ['Gratuity Amount', '₹2,88,461'],
          ]),
        ],
      ),
    );
  }

  Widget _buildInfoBox(String title, String subtitle, List<String> points, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 12, color: color.withOpacity(0.8))),
          const SizedBox(height: 8),
          ...points.map((point) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                Expanded(child: Text(point, style: TextStyle(fontSize: 12, color: color.withOpacity(0.9)))),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildExampleTable(List<List<String>> rows) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        children: rows.asMap().entries.map((entry) {
          final index = entry.key;
          final row = entry.value;
          final isHeader = index == 0;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isHeader ? const Color(0xFFF8FAFC) : Colors.transparent,
              border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.05))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(row[0], style: TextStyle(fontSize: 12, fontWeight: isHeader ? FontWeight.bold : FontWeight.normal)),
                Text(row[1], style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isHeader ? Colors.black : const Color(0xFF0369A1))),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // Bank Transfer Tab
  Widget _buildBankTransferTab(NumberFormat formatCurrency, bool isDark) {
    final paginated = _paginatedEmployees;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Bank Transfer Details',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildExportButton('CSV', Icons.description_outlined, const Color(0xFF0369A1)),
                  const SizedBox(width: 8),
                  _buildExportButton('PDF', Icons.picture_as_pdf_outlined, const Color(0xFFBE123C)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  // Table Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                      border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.1))),
                    ),
                    child: Row(
                      children: [
                        SizedBox(width: 150, child: _buildTableHeader('EMPLOYEE')),
                        SizedBox(width: 120, child: _buildTableHeader('BANK NAME')),
                        SizedBox(width: 150, child: _buildTableHeader('ACCOUNT NO')),
                        SizedBox(width: 100, child: _buildTableHeader('IFSC CODE')),
                        SizedBox(width: 100, child: _buildTableHeader('NET SALARY')),
                      ],
                    ),
                  ),
                  // Table Body
                  Expanded(
                    child: ListView.builder(
                      itemCount: paginated.length,
                      itemBuilder: (context, index) {
                        final employee = paginated[index];
                        return _buildBankRow(employee, formatCurrency);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportButton(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildBankRow(Map<String, dynamic> employee, NumberFormat formatCurrency) {
    final name = employee['employee_name'] as String? ?? 'Unknown';
    final bank = employee['bank_name'] as String? ?? 'SBI';
    final accNo = employee['account_no'] as String? ?? 'XXXXXX1234';
    final ifsc = employee['ifsc_code'] as String? ?? 'SBIN0001234';
    final netSalary = (employee['net_salary'] as num?)?.toDouble() ?? 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          SizedBox(width: 150, child: Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
          SizedBox(width: 120, child: Text(bank, style: const TextStyle(fontSize: 12))),
          SizedBox(width: 150, child: Text(accNo, style: const TextStyle(fontSize: 12, color: Color(0xFF475569)))),
          SizedBox(width: 100, child: Text(ifsc, style: const TextStyle(fontSize: 12, color: Color(0xFF475569)))),
          SizedBox(width: 100, child: Text(formatCurrency.format(netSalary).replaceAll('₹', ''), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildFormatChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _getColorShade(color, 700),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationInfo() {
    final filtered = _filteredEmployees;
    final total = filtered.length;
    final start = total == 0 ? 0 : ((_currentPage - 1) * _itemsPerPage) + 1;
    final end = total == 0 ? 0 : (start + _paginatedEmployees.length - 1);

    return SizedBox(
      height: 28,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              total == 0 
                ? 'No employees found'
                : 'Showing $start to $end of $total',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Show: ',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
              ),
              DropdownButton<int>(
                value: _itemsPerPage,
                underline: const SizedBox(),
                isDense: true,
                style: const TextStyle(fontSize: 10),
                items: [10, 25, 50, 100].map((value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text('$value', style: const TextStyle(fontSize: 10)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _itemsPerPage = value;
                      _currentPage = 1; // Reset to first page
                    });
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationControls() {
    final totalPages = _totalPages;
    if (totalPages <= 1) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(color: Colors.grey.withOpacity(0.2)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentPage > 1
                ? () {
                    setState(() => _currentPage--);
                  }
                : null,
          ),
          Text(
            'Page $_currentPage of $totalPages',
            style: const TextStyle(fontSize: 14),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage < totalPages
                ? () {
                    setState(() => _currentPage++);
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeTable(NumberFormat formatCurrency, bool isDark) {
    final paginated = _paginatedEmployees;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.1))),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: _horizontalScrollController,
              child: Row(
                children: [
                  SizedBox(width: 180, child: _buildTableHeader('EMPLOYEE')),
                  SizedBox(width: 100, child: _buildTableHeader('BASIC')),
                  SizedBox(width: 100, child: _buildTableHeader('ALLOWANCES')),
                  SizedBox(width: 100, child: _buildTableHeader('OVERTIME')),
                  SizedBox(width: 80, child: _buildTableHeader('PF')),
                  SizedBox(width: 80, child: _buildTableHeader('ESI')),
                  SizedBox(width: 100, child: _buildTableHeader('NET SALARY')),
                  SizedBox(width: 100, child: _buildTableHeader('STATUS')),
                  SizedBox(width: 100, child: _buildTableHeader('ACTIONS')),
                ],
              ),
            ),
          ),
          // Table Body
          Expanded(
            child: paginated.isEmpty
                ? Center(
                    child: Text(
                      'No employees found',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      controller: _horizontalScrollController,
                      child: Column(
                        children: paginated.map((employee) => _buildEmployeeRow(employee, formatCurrency)).toList(),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: Colors.grey,
      ),
    );
  }

  Color _getColorShade(Color color, int shade) {
    if (color is MaterialColor) {
      switch (shade) {
        case 700:
          return color.shade700;
        default:
          return color;
      }
    }
    return color;
  }

  Widget _buildEmployeeRow(Map<String, dynamic> employee, NumberFormat formatCurrency) {
    final name = employee['employee_name'] as String? ?? 'Unknown';
    final code = employee['employee_code'] as String? ?? '';
    final basic = (employee['basic_salary'] as num?)?.toDouble() ?? 0.0;
    final allowances = (employee['hra'] as num? ?? 0.0) + (employee['special'] as num? ?? 0.0);
    final overtime = (employee['overtime'] as num?)?.toDouble() ?? 0.0;
    final pf = (employee['pf'] as num?)?.toDouble() ?? 0.0;
    final esi = (employee['esi'] as num?)?.toDouble() ?? 0.0;
    final netSalary = (employee['net_salary'] as num?)?.toDouble() ?? 0.0;
    final status = employee['status'] as String? ?? 'pending';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 180,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                Text(code, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ),
          ),
          SizedBox(width: 100, child: Text(formatCurrency.format(basic).replaceAll('₹', ''), style: const TextStyle(fontSize: 12))),
          SizedBox(width: 100, child: Text(formatCurrency.format(allowances).replaceAll('₹', ''), style: const TextStyle(fontSize: 12))),
          SizedBox(width: 100, child: Text(formatCurrency.format(overtime).replaceAll('₹', ''), style: const TextStyle(fontSize: 12))),
          SizedBox(width: 80, child: Text(formatCurrency.format(pf).replaceAll('₹', ''), style: const TextStyle(fontSize: 12, color: Color(0xFFEA580C)))),
          SizedBox(width: 80, child: Text(formatCurrency.format(esi).replaceAll('₹', ''), style: const TextStyle(fontSize: 12, color: Color(0xFFEA580C)))),
          SizedBox(width: 100, child: Text(formatCurrency.format(netSalary).replaceAll('₹', ''), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0D9488)))),
          SizedBox(
            width: 100,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: status.toLowerCase().contains('paid') ? const Color(0xFFDCFCE7) : const Color(0xFFDBEAFE),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: status.toLowerCase().contains('paid') ? const Color(0xFF166534) : const Color(0xFF1E40AF),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          SizedBox(
            width: 100,
            child: Row(
              children: [
                const SizedBox(width: 4),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    minimumSize: const Size(60, 24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    elevation: 0,
                  ),
                  child: const Text('Payslip', style: TextStyle(fontSize: 10)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


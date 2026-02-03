import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:loghr_mobile/logic/auth_provider.dart';
import 'package:loghr_mobile/data/services/payroll_service.dart';
import 'package:loghr_mobile/ui/screens/employee/payslip_detail_screen.dart';
import 'package:loghr_mobile/data/services/pdf_service.dart';

class MyPayrollScreen extends StatefulWidget {
  final VoidCallback? onNavigateToDashboard;
  
  const MyPayrollScreen({super.key, this.onNavigateToDashboard});

  @override
  State<MyPayrollScreen> createState() => _MyPayrollScreenState();
}

class _MyPayrollScreenState extends State<MyPayrollScreen> {
  final PayrollService _payrollService = PayrollService();
  final PdfService _pdfService = PdfService();
  List<Map<String, dynamic>> _payslips = [];
  bool _isLoading = true;
  String? _error;
  int? _selectedMonth;
  int? _selectedYear;

  @override
  void initState() {
    super.initState();
    _loadPayrollData();
  }

  Future<void> _loadPayrollData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final user = authProvider.user;
      
      if (user == null) {
        if (mounted) {
          setState(() {
            _error = 'User not logged in';
            _isLoading = false;
          });
        }
        return;
      }

      final payslips = await _payrollService.getEmployeePayrollHistory(
        userId: user.id,
        month: _selectedMonth,
        year: _selectedYear,
      );

      if (mounted) {
        setState(() {
          _payslips = payslips;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load payroll data: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F1724);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade300;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () {
            if (widget.onNavigateToDashboard != null) {
              widget.onNavigateToDashboard!();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          'Payroll History',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
        ),
      ),
      body: SafeArea(
          child: Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                const Text('View and download your payslips',
                    style: TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 24),

                // Filters
                Row(
                  children: [
                    _buildDropdownFilter(
                      _selectedMonth != null
                          ? DateFormat('MMMM').format(DateTime(2024, _selectedMonth!))
                          : 'All Months',
                      isDark,
                      _showMonthPicker,
                    ),
                    const SizedBox(width: 12),
                    _buildDropdownFilter(
                      _selectedYear != null ? _selectedYear.toString() : 'All Years',
                      isDark,
                      _showYearPicker,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Quick Info Card (Premium)
                if (_payslips.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [const Color(0xFF137FEC), Colors.blue.shade600],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF137FEC).withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Latest Net Salary',
                          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _payslips.first['net'] ?? '₹0.00',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 20),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Payment status: ${_payslips.first['status'] ?? 'N/A'}',
                          style: const TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),

                // Loading or Error State
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_error != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Column(
                        children: [
                          Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            style: TextStyle(color: Colors.red.shade300),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadPayrollData,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_payslips.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'No payroll records found',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  // Payslip List
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _payslips.length,
                    itemBuilder: (context, index) {
                      final payslip = _payslips[index];
                      return _buildPayslipCard(payslip, isDark, textColor, cardColor);
                    },
                  ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }



  Widget _buildStatusBadge(String? status) {
    final s = status?.toUpperCase() ?? 'PENDING';
    final isPaid = s == 'PAID' || s == 'APPROVED';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isPaid ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        s,
        style: TextStyle(
          color: isPaid ? const Color(0xFF166534) : const Color(0xFF92400E),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDropdownFilter(String label, bool isDark, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                ),
              ),
              const Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  void _showMonthPicker() {
    showDialog(
      context: context,
      builder: (context) {
        final months = List.generate(12, (index) => index + 1);
        return AlertDialog(
          title: const Text('Select Month'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('All Months'),
                  onTap: () {
                    setState(() => _selectedMonth = null);
                    Navigator.pop(context);
                    _loadPayrollData();
                  },
                ),
                ...months.map((month) {
                  final monthName = DateFormat('MMMM').format(DateTime(2024, month));
                  return ListTile(
                    title: Text(monthName),
                    onTap: () {
                      setState(() => _selectedMonth = month);
                      Navigator.pop(context);
                      _loadPayrollData();
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showYearPicker() {
    final currentYear = DateTime.now().year;
    final years = List.generate(5, (index) => currentYear - index);
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Year'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('All Years'),
                  onTap: () {
                    setState(() => _selectedYear = null);
                    Navigator.pop(context);
                    _loadPayrollData();
                  },
                ),
                ...years.map((year) {
                  return ListTile(
                    title: Text(year.toString()),
                    onTap: () {
                      setState(() => _selectedYear = year);
                      Navigator.pop(context);
                      _loadPayrollData();
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _viewPayslip(Map<String, dynamic> payslip) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Get detailed payslip data to ensure we have all fields for the detail screen
      final details = await _payrollService.getPayslipDetails(payslip['id']);
      
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (details != null) {
        // Merge in the display strings from the summary if needed
        final fullData = {
          ...details,
          'display_month': payslip['month'],
          'display_net': payslip['net'],
          'display_gross': payslip['gross'],
          'display_deductions': payslip['deductions'],
        };

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PayslipDetailScreen(payslip: fullData),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load payslip details')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading details: $e')),
        );
      }
    }
  }

  Future<void> _downloadPayslip(Map<String, dynamic> payslip) async {
    try {
      final authProvider = context.read<AuthProvider>();
      final user = authProvider.user;
      
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not logged in')),
        );
        return;
      }

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Get detailed payslip data
      final details = await _payrollService.getPayslipDetails(payslip['id']);
      if (details == null && payslip['raw_data'] != null) {
        // Use raw_data if available
        final rawData = payslip['raw_data'] as Map<String, dynamic>;
        await _pdfService.generatePayslipPdf(
          payslipData: {
            'basic_salary': (rawData['basic_salary'] as num?)?.toDouble() ?? 0.0,
            'da': (rawData['da'] as num?)?.toDouble() ?? 0.0,
            'hra': (rawData['hra'] as num?)?.toDouble() ?? 0.0,
            'special': (rawData['special'] as num?)?.toDouble() ?? 0.0,
            'gross_salary': (rawData['gross_salary'] as num?)?.toDouble() ?? 0.0,
            'pf': (rawData['pf'] as num?)?.toDouble() ?? 0.0,
            'esi': (rawData['esi'] as num?)?.toDouble() ?? 0.0,
            'tds': (rawData['tds'] as num?)?.toDouble() ?? 0.0,
            'professional_tax': (rawData['professional_tax'] as num?)?.toDouble() ?? 0.0,
            'net_salary': (rawData['net_salary'] as num?)?.toDouble() ?? 0.0,
            'status': rawData['status'] as String? ?? 'pending',
            'currency': rawData['currency'] as String? ?? 'INR',
            'pay_period_start': rawData['pay_period_start'],
            'pay_period_end': rawData['pay_period_end'],
            'working_days': rawData['working_days'] as int? ?? 0,
            'total_working_days': rawData['total_working_days'] as int? ?? 0,
          },
          employeeName: user.fullName,
          employeeCode: user.employeeId ?? 'N/A',
          payPeriod: payslip['month'] ?? 'Unknown',
          payPeriodStart: rawData['pay_period_start'],
          payPeriodEnd: rawData['pay_period_end'],
          userId: user.id, // Pass userId to fetch name if needed
        );
      } else if (details != null) {
        await _pdfService.generatePayslipPdf(
          payslipData: details,
          employeeName: user.fullName,
          employeeCode: user.employeeId ?? 'N/A',
          payPeriod: payslip['month'] ?? 'Unknown',
          payPeriodStart: details['pay_period_start'],
          payPeriodEnd: details['pay_period_end'],
          userId: user.id, // Pass userId to fetch name if needed
        );
      } else {
        throw Exception('Payslip data not available');
      }

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payslip downloaded successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download payslip: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildDetailItem(String label, String value, Color textColor, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: valueColor ?? textColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPayslipCard(Map<String, dynamic> payslip, bool isDark, Color textColor, Color cardColor) {
    final sectionColor = isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
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
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE8F1FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF137FEC), size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payslip['month'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: textColor,
                        ),
                      ),
                      Text(
                        'Standard Monthly Payslip',
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(payslip['status']),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: sectionColor,
              border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.05))),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: _buildCompactData('GROSS SALARY', payslip['gross'], isDark: isDark)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildCompactData('DEDUCTIONS', payslip['deductions'], isDark: isDark)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildCompactData('NET SALARY', payslip['net'], isBold: true, color: const Color(0xFF36C5F0), isDark: isDark)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => _viewPayslip(payslip),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: const Size(0, 32),
                      ),
                      child: const Text('View Details', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _downloadPayslip(payslip),
                      icon: const Icon(Icons.download, size: 14),
                      label: const Text('Download PDF', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: const Size(0, 32),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactData(String label, String value, {bool isBold = false, Color? color, bool isDark = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: TextStyle(
            fontSize: 13, 
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color ?? (isDark ? Colors.white : const Color(0xFF1E293B)),
          )),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        color: Colors.grey.shade500,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

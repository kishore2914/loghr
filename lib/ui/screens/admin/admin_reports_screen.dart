import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String _selectedReportType = 'Attendance';
  bool _isGenerating = false;

  final List<String> _reportTypes = [
    'Attendance',
    'Leave',
    // 'Payroll', // Removed
    'Employee Master',
    'Expense',
  ];

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _generateReport() async {
    setState(() => _isGenerating = true);
    
    // Simulate generation delay
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() => _isGenerating = false);
      
      // Mock success action - in real app, this would download/open PDF
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Report Generated'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Type: $_selectedReportType', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Period: ${DateFormat('MMM dd').format(_startDate)} - ${DateFormat('MMM dd, yyyy').format(_endDate)}'),
              const SizedBox(height: 16),
              const Row(
                children: [
                   Icon(Icons.file_download, color: Colors.green),
                   SizedBox(width: 8),
                   Expanded(child: Text('report_2024.pdf downloaded')),
                ],
              )
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OPEN'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CLOSE'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A237E);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey.shade50,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reports Center',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Generate and analyze organization data',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.blue.shade900.withOpacity(0.3) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        if (!isDark)
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                      ],
                    ),
                    child: Icon(Icons.analytics_outlined, color: Colors.blue.shade700),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              Text(
                'Report Category',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1,
                ),
                itemCount: _reportTypes.length,
                itemBuilder: (context, index) {
                  final type = _reportTypes[index];
                  final isSelected = _selectedReportType == type;
                  return _buildReportTypeCard(type, isSelected, isDark);
                },
              ),

              const SizedBox(height: 32),
              Text(
                'Date Range',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1)),
                ),
                child: Column(
                  children: [
                    _buildDateRow('Start Date', _startDate, () => _selectDate(context, true), Icons.calendar_today, Colors.blue, isDark),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(height: 1),
                    ),
                    _buildDateRow('End Date', _endDate, () => _selectDate(context, false), Icons.event_available, Colors.teal, isDark),
                  ],
                ),
              ),

              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isGenerating ? null : _generateReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isGenerating
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.auto_awesome, size: 20),
                            SizedBox(width: 12),
                            Text(
                              'Generate Insights',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Reports will be generated in PDF & Excel formats',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportTypeCard(String type, bool isSelected, bool isDark) {
    IconData icon;
    Color color;
    switch (type) {
      case 'Attendance': icon = Icons.access_time_rounded; color = Colors.orange; break;
      case 'Leave': icon = Icons.event_note_rounded; color = Colors.teal; break;
      case 'Employee Master': icon = Icons.badge_rounded; color = Colors.blue; break;
      case 'Expense': icon = Icons.payments_rounded; color = Colors.purple; break;
      default: icon = Icons.description_rounded; color = Colors.grey;
    }

    return InkWell(
      onTap: () => setState(() => _selectedReportType = type),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected 
              ? color.withOpacity(0.1) 
              : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1)),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey, size: 28),
            const SizedBox(height: 12),
            Text(
              type,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 15,
                color: isSelected ? (isDark ? Colors.white : color) : (isDark ? Colors.grey : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRow(String label, DateTime date, VoidCallback onTap, IconData icon, Color color, bool isDark) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                Text(
                  DateFormat('dd MMMM, yyyy').format(date),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey.shade400),
        ],
      ),
    );
  }
}

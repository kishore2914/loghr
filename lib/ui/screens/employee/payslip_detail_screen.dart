import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PayslipDetailScreen extends StatelessWidget {
  final Map<String, dynamic> payslip;

  const PayslipDetailScreen({
    super.key,
    required this.payslip,
  });

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
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Payslip Details',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Payslip Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [const Color(0xFF137FEC), Colors.blue.shade600],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payslip['month'] ?? 'Payslip',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Payment Status: ${payslip['status'] ?? 'N/A'}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Earnings Section
              _buildSectionHeader('Earnings', textColor),
              const SizedBox(height: 12),
              _buildDetailCard([
                _buildDetailRow('Basic Salary', _formatAmount(payslip['basic_salary']), textColor),
                _buildDivider(),
                _buildDetailRow('DA', _formatAmount(payslip['da']), textColor),
                _buildDivider(),
                _buildDetailRow('HRA', _formatAmount(payslip['hra']), textColor),
                _buildDivider(),
                if ((payslip['conveyance_allowance'] ?? 0) > 0) ...[
                  _buildDetailRow('Conveyance Allowance', _formatAmount(payslip['conveyance_allowance']), textColor),
                  _buildDivider(),
                ],
                if ((payslip['medical_allowance'] ?? 0) > 0) ...[
                  _buildDetailRow('Medical Allowance', _formatAmount(payslip['medical_allowance']), textColor),
                  _buildDivider(),
                ],
                if ((payslip['other_allowance'] ?? 0) > 0) ...[
                  _buildDetailRow('Other Allowance', _formatAmount(payslip['other_allowance']), textColor),
                  _buildDivider(),
                ],
                _buildDetailRow('Special Allowance', _formatAmount(payslip['special_allowance']), textColor),
                _buildDivider(),
                if ((payslip['bonus'] ?? 0) > 0) ...[
                  _buildDetailRow('Bonus', _formatAmount(payslip['bonus']), textColor),
                  _buildDivider(),
                ],
                if ((payslip['incentive'] ?? 0) > 0) ...[
                  _buildDetailRow('Incentive', _formatAmount(payslip['incentive']), textColor),
                  _buildDivider(),
                ],
                if ((payslip['overtime_pay'] ?? 0) > 0) ...[
                  _buildDetailRow('Overtime Pay', _formatAmount(payslip['overtime_pay']), textColor),
                  _buildDivider(),
                ],
                _buildDetailRow('Gross Salary', _formatAmount(payslip['gross_salary']), textColor, isBold: true),
              ], cardColor, borderColor),
              const SizedBox(height: 24),

              // Deductions Section
              _buildSectionHeader('Deductions', textColor),
              const SizedBox(height: 12),
              _buildDetailCard([
                _buildDetailRow('PF', _formatAmount(payslip['pf']), textColor),
                _buildDivider(),
                _buildDetailRow('ESI', _formatAmount(payslip['esi']), textColor),
                _buildDivider(),
                _buildDetailRow('TDS', _formatAmount(payslip['tds']), textColor),
                _buildDivider(),
                _buildDetailRow('Professional Tax', _formatAmount(payslip['professional_tax']), textColor),
                _buildDivider(),
                if ((payslip['advance_salary'] ?? 0) > 0) ...[
                  _buildDetailRow('Advance Salary', _formatAmount(payslip['advance_salary']), textColor),
                  _buildDivider(),
                ],
                if ((payslip['loan_repayment'] ?? 0) > 0) ...[
                  _buildDetailRow('Loan Repayment', _formatAmount(payslip['loan_repayment']), textColor),
                  _buildDivider(),
                ],
                if ((payslip['absence_deduction'] ?? 0) > 0) ...[
                  _buildDetailRow('Absence Deduction', _formatAmount(payslip['absence_deduction']), textColor),
                  _buildDivider(),
                ],
                _buildDetailRow('Total Deductions', _formatAmount(payslip['deductions']), textColor, isBold: true),
              ], cardColor, borderColor),
              const SizedBox(height: 24),

              // Net Salary
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE8F1FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF137FEC).withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Net Salary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    Text(
                      _formatAmount(payslip['net_salary']),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0369A1),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color textColor) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
    );
  }

  Widget _buildDetailCard(List<Widget> children, Color cardColor, Color borderColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, Color textColor, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: textColor,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, thickness: 1);
  }

  String _formatAmount(dynamic amount) {
    if (amount == null) return '₹0.00';
    if (amount is String) return amount; // Already formatted
    final double value = (amount is num) ? amount.toDouble() : 0.0;
    return '₹${NumberFormat('#,##,##0').format(value)}';
  }
}

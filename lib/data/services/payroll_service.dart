import 'package:loghr_mobile/config/api_client.dart';
import 'package:intl/intl.dart';

class PayrollService {
  // Get employee's payroll history
  Future<List<Map<String, dynamic>>> getEmployeePayrollHistory({
    String? userId,
    int? month,
    int? year,
  }) async {
    try {
      if (userId == null) return [];

      final response = await api.get('/misc/payroll/records');
      if (response == null) return [];

      List<dynamic> list = response as List;

      // Filter locally
      if (month != null) {
        list = list.where((r) => r['pay_period_month'] == month).toList();
      }
      if (year != null) {
        list = list.where((r) => r['pay_period_year'] == year).toList();
      }

      return list.map((record) {
        final gross = _toDouble(record['gross_salary']) ?? 0.0;
        final deductions = _toDouble(record['total_deductions']) ?? 0.0;
        final net = _toDouble(record['net_salary']) ?? 0.0;
        
        final pMonth = record['pay_period_month'] as int?;
        final pYear = record['pay_period_year'] as int?;
        String monthYear = 'Unknown';
        if (pMonth != null && pYear != null) {
          final date = DateTime(pYear, pMonth);
          monthYear = DateFormat('MMMM yyyy').format(date);
        }

        final workingDays = record['working_days'] as int? ?? 0;
        final status = (record['status'] as String? ?? 'Pending');

        return {
          'id': record['id'],
          'month': monthYear,
          'status': status.toUpperCase(),
          'gross': '₹${_formatCurrency(gross)}',
          'deductions': '-₹${_formatCurrency(deductions)}',
          'net': '₹${_formatCurrency(net)}',
          'workingDays': '$workingDays days',
          'pay_period_month': pMonth,
          'pay_period_year': pYear,
          'raw_data': record,
        };
      }).toList();
    } catch (e) {
      print('Error fetching payroll history: $e');
      return [];
    }
  }

  // Get detailed payslip data by ID
  Future<Map<String, dynamic>?> getPayslipDetails(String payslipId) async {
    try {
      final response = await api.get('/misc/payroll/records/$payslipId');
      if (response == null) return null;

      final data = response as Map<String, dynamic>;
      final basic = _toDouble(data['basic_salary']) ?? 0.0;
      final da = _toDouble(data['dearness_allowance']) ?? _toDouble(data['da']) ?? 0.0;
      final hra = _toDouble(data['house_rent_allowance']) ?? _toDouble(data['hra']) ?? 0.0;
      final conveyance = _toDouble(data['conveyance_allowance']) ?? _toDouble(data['conveyance']) ?? 0.0;
      final medical = _toDouble(data['medical_allowance']) ?? _toDouble(data['medical']) ?? 0.0;
      final other = _toDouble(data['other_allowance']) ?? _toDouble(data['other_allowances']) ?? 0.0;
      final special = _toDouble(data['special_allowance']) ?? _toDouble(data['special']) ?? 0.0;
      final bonus = _toDouble(data['bonus']) ?? 0.0;
      final incentive = _toDouble(data['incentive']) ?? 0.0;
      final overtime = _toDouble(data['overtime_pay']) ?? _toDouble(data['overtime']) ?? 0.0;
      final gross = _toDouble(data['gross_salary']) ?? 0.0;
      
      final pf = _toDouble(data['pf_employee']) ?? _toDouble(data['pf']) ?? 0.0;
      final esi = _toDouble(data['esi_employee']) ?? _toDouble(data['esi']) ?? 0.0;
      final tds = _toDouble(data['tds']) ?? 0.0;
      final pt = _toDouble(data['professional_tax']) ?? 0.0;
      final advance = _toDouble(data['advance_salary']) ?? 0.0;
      final loan = _toDouble(data['loan_repayment']) ?? _toDouble(data['loan_emi']) ?? 0.0;
      final deductions = _toDouble(data['total_deductions']) ?? 0.0;
      final net = _toDouble(data['net_salary']) ?? 0.0;
      
      final absenceDeduction = _toDouble(data['absence_deduction']) ?? 
                               _toDouble(data['lop_deduction']) ?? 
                               _toDouble(data['loss_of_pay']) ?? 0.0;
      
      final companyName = data['company_name'] as String? ?? 'LogHR';

      final pMonth = data['pay_period_month'] as int?;
      final pYear = data['pay_period_year'] as int?;

      String? startDate;
      String? endDate;
      if (pMonth != null && pYear != null) {
        final start = DateTime(pYear, pMonth, 1);
        final end = DateTime(pYear, pMonth + 1, 0);
        startDate = start.toIso8601String();
        endDate = end.toIso8601String();
      }

      return {
        'id': data['id'],
        'basic_salary': basic,
        'da': da,
        'hra': hra,
        'conveyance_allowance': conveyance,
        'medical_allowance': medical,
        'other_allowance': other,
        'special_allowance': special,
        'bonus': bonus,
        'incentive': incentive,
        'overtime_pay': overtime,
        'gross_salary': gross,
        'pf': pf,
        'esi': esi,
        'tds': tds,
        'professional_tax': pt,
        'advance_salary': advance,
        'loan_repayment': loan,
        'deductions': deductions,
        'net_salary': net,
        'absence_deduction': absenceDeduction,
        'status': data['status'] as String? ?? 'pending',
        'currency': data['currency'] as String? ?? 'INR',
        'pay_period_start': startDate,
        'pay_period_end': endDate,
        'working_days': data['working_days'] as int? ?? 0,
        'total_working_days': data['total_working_days'] as int? ?? data['working_days'] as int? ?? 30,
        'pay_period_month': pMonth,
        'pay_period_year': pYear,
        'user_id': data['user_id'],
        'employee_id': data['employee_id'],
        'payment_date': data['payment_date'],
        'company_name': companyName,
      };
    } catch (e) {
      print('Error fetching payslip details: $e');
      return null;
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

  String _formatCurrency(double amount) {
    return NumberFormat('#,##0').format(amount);
  }
}

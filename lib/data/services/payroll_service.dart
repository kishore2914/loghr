import 'package:loghr_mobile/config/supabase_config.dart';
import 'package:intl/intl.dart';

class PayrollService {
  // Helper method to get employee_id from user_id
  Future<String?> _getEmployeeId(String userId) async {
    try {
      // Get employee_id from user_profiles table
      final profileData = await supabase
          .from('user_profiles')
          .select('employee_id')
          .eq('user_id', userId)
          .maybeSingle();
      
      if (profileData != null && profileData['employee_id'] != null) {
        return profileData['employee_id'] as String;
      }
      return null;
    } catch (e) {
      print('Error getting employee_id: $e');
      return null;
    }
  }

  // Get employee's payroll history
  Future<List<Map<String, dynamic>>> getEmployeePayrollHistory({
    String? userId,
    int? month,
    int? year,
  }) async {
    try {
      if (userId == null) return [];

      // 1. Get employee_id (Required for this table)
      final employeeId = await _getEmployeeId(userId);
      if (employeeId == null) {
        print('No employee_id found for user: $userId');
        return [];
      }

      // 2. Build Query on india_payroll_records
      // Start with the base filter builder
      var query = supabase
          .from('india_payroll_records')
          .select('*')
          .eq('employee_id', employeeId);

      // Apply optional filters
      if (month != null) {
        query = query.eq('pay_period_month', month);
      }
      if (year != null) {
        query = query.eq('pay_period_year', year);
      }

      // Apply ordering and limit at the end to get the final result
      final List<dynamic> data = await query
          .order('pay_period_year', ascending: false)
          .order('pay_period_month', ascending: false)
          .limit(100);

      print('Fetched ${data.length} records for employee: $employeeId');

      if (data.isEmpty) return [];

      // 3. Transform data
      return data.map((record) {
        final gross = _toDouble(record['gross_salary']) ?? 0.0;
        final deductions = _toDouble(record['total_deductions']) ?? 0.0;
        final net = _toDouble(record['net_salary']) ?? 0.0;
        
        // Construct readable month
        final pMonth = record['pay_period_month'] as int?;
        final pYear = record['pay_period_year'] as int?;
        String monthYear = 'Unknown';
        if (pMonth != null && pYear != null) {
          final date = DateTime(pYear, pMonth);
          monthYear = DateFormat('MMMM yyyy').format(date);
        }

        final workingDays = record['working_days'] as int? ?? 0;
        // status might be lower case in DB
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
      final data = await supabase
          .from('india_payroll_records')
          .select('*')
          .eq('id', payslipId)
          .maybeSingle();

      if (data == null) return null;

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
      // Use exact net_salary from database - DO NOT RECALCULATE
      final net = _toDouble(data['net_salary']) ?? 0.0;
      
      // Check for absence deduction in database - try multiple field names
      final absenceDeduction = _toDouble(data['absence_deduction']) ?? 
                               _toDouble(data['lop_deduction']) ?? 
                               _toDouble(data['loss_of_pay']) ??
                               _toDouble(data['lop_amount']) ??
                               _toDouble(data['absence_amount']) ?? 0.0;
      
      // Get company name from payroll record if available
      final companyName = data['company_name'] as String? ?? 
                         data['organization_name'] as String?;

      final pMonth = data['pay_period_month'] as int?;
      final pYear = data['pay_period_year'] as int?;

      // Construct dates for PDF if needed (First and Last day of month)
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
        'net_salary': net, // Use exact value from database - DO NOT RECALCULATE
        'absence_deduction': absenceDeduction, // Use value from database if available
        'status': data['status'] as String? ?? 'pending',
        'currency': data['currency'] as String? ?? 'INR',
        'pay_period_start': startDate, // Computed
        'pay_period_end': endDate,     // Computed
        'working_days': data['working_days'] as int? ?? 0,
        'total_working_days': data['total_working_days'] as int? ?? data['working_days'] as int? ?? 30,
        'pay_period_month': pMonth,
        'pay_period_year': pYear,
        'user_id': data['user_id'],
        'employee_id': data['employee_id'],
        'payment_date': data['payment_date'], // Use payment_date from database if available
        'company_name': companyName, // Include company name from payroll record
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






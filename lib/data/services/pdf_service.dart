import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:loghr_mobile/config/api_client.dart';
import 'package:loghr_mobile/utils/helpers.dart';

class PdfService {
  // Cache for loaded font
  pw.Font? _unicodeFont;
  bool _fontLoadAttempted = false;

  // Load a Unicode-compatible font that supports Rupee symbol
  Future<pw.Font?> _loadUnicodeFont() async {
    if (_fontLoadAttempted) return _unicodeFont;
    _fontLoadAttempted = true;

    try {
      // Try to load Noto Sans or another Unicode font from assets
      // You need to download Noto Sans from https://fonts.google.com/noto
      // and place it in assets/fonts/NotoSans-Regular.ttf
      final fontData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
      _unicodeFont = pw.Font.ttf(fontData);
      print('Unicode font loaded successfully');
      return _unicodeFont;
    } catch (e) {
      print('Could not load Unicode font from assets: $e');
      print('Using default font - Rupee symbol may not render correctly');
      print('To fix: Download Noto Sans from https://fonts.google.com/noto and place in assets/fonts/');
      return null;
    }
  }

  Future<void> generatePayslipPdf({
    required Map<String, dynamic> payslipData,
    required String employeeName,
    required String employeeCode,
    required String payPeriod,
    String? payPeriodStart,
    String? payPeriodEnd,
    String? organizationName,
    String location = 'Qatar',
    String? userId, // Add userId to fetch name if needed
  }) async {
    // Get organization name from payslip data if not provided
    String finalOrganizationName = organizationName ?? 
                                   payslipData['company_name'] as String? ??
                                   'LogHR';
    final pdf = pw.Document();
    final currency = payslipData['currency'] as String? ?? 'INR';
    
    // Try to load Unicode font for Rupee symbol
    final unicodeFont = await _loadUnicodeFont();
    
    // Use Rupee symbol (₹) for INR currency if font is available, otherwise use "Rs."
    // To get ₹ symbol working: Download Noto Sans from https://fonts.google.com/noto
    // and place NotoSans-Regular.ttf in assets/fonts/
    String finalEmployeeName = employeeName;
    String finalEmployeeCode = employeeCode;
    String? companyLogoUrl;
    String designation = 'N/A';
    String dateOfJoining = 'N/A';

    final currencySymbol = currency == 'INR' 
        ? (unicodeFont != null ? '₹' : 'Rs.') 
        : (currency == 'QAR' ? 'QAR' : currency);

    // Fetch profile details from backend REST API
    try {
      final profile = await api.get('/profile');
      if (profile != null) {
        finalEmployeeName = profile['full_name'] as String? ?? employeeName;
        finalEmployeeCode = profile['employee_code'] as String? ?? employeeCode;
        finalOrganizationName = profile['organization_name'] as String? ?? finalOrganizationName;
        companyLogoUrl = profile['organization_logo'] as String?;
        designation = profile['designation'] as String? ?? 'N/A';
        final doj = profile['date_of_joining'] as String?;
        if (doj != null && doj.isNotEmpty) {
          try {
            dateOfJoining = DateFormat('dd/MM/yyyy').format(DateTime.parse(doj));
          } catch (_) {
            dateOfJoining = doj;
          }
        }
      }
    } catch (e) {
      print('PDF Service: Error fetching profile for PDF: $e');
    }
    
    print('PDF Service: Final values - Company: $finalOrganizationName, Designation: $designation, DOJ: $dateOfJoining');
    
    // Load logo image if available
    pw.ImageProvider? logoImage;
    if (companyLogoUrl != null && companyLogoUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(companyLogoUrl));
        if (response.statusCode == 200) {
          final imageBytes = response.bodyBytes;
          logoImage = pw.MemoryImage(imageBytes);
          print('Company logo loaded successfully');
        }
      } catch (e) {
        print('Error loading company logo: $e');
      }
    }
    
    // Use exact values from database - DO NOT RECALCULATE
    final basic = _toDouble(payslipData['basic_salary']) ?? 0.0;
    final medical = _toDouble(payslipData['medical_allowance']) ?? 
                    _toDouble(payslipData['medical']) ?? 0.0;
    
    // Sum up all OTHER earnings that aren't Basic or Medical into "Other Allowances"
    // This ensures the individual items sum up to Gross Salary in the PDF
    final da = _toDouble(payslipData['da']) ?? _toDouble(payslipData['dearness_allowance']) ?? 0.0;
    final hra = _toDouble(payslipData['hra']) ?? _toDouble(payslipData['house_rent_allowance']) ?? 0.0;
    final special = _toDouble(payslipData['special_allowance']) ?? _toDouble(payslipData['special']) ?? 0.0;
    final conveyance = _toDouble(payslipData['conveyance_allowance']) ?? _toDouble(payslipData['conveyance']) ?? 0.0;
    final bonus = _toDouble(payslipData['bonus']) ?? 0.0;
    final incentive = _toDouble(payslipData['incentive']) ?? 0.0;
    final overtime = _toDouble(payslipData['overtime_pay']) ?? _toDouble(payslipData['overtime']) ?? 0.0;
    final otherField = _toDouble(payslipData['other_allowance']) ?? _toDouble(payslipData['other_allowances']) ?? 0.0;
    
    final otherAllowance = da + hra + special + conveyance + bonus + incentive + overtime + otherField;
    
    final gross = _toDouble(payslipData['gross_salary']) ?? (basic + medical + otherAllowance);
    
    final pf = _toDouble(payslipData['pf']) ?? _toDouble(payslipData['pf_employee']) ?? 0.0;
    final esi = _toDouble(payslipData['esi']) ?? _toDouble(payslipData['esi_employee']) ?? 0.0;
    final professionalTax = _toDouble(payslipData['professional_tax']) ?? 0.0;
    final tds = _toDouble(payslipData['tds']) ?? 0.0;
    
    // Get working days and LOP from database
    final workingDays = payslipData['working_days'] as int? ?? 0;
    final totalWorkingDays = payslipData['total_working_days'] as int? ?? 30;
    final lopDays = totalWorkingDays - workingDays;
    
    // Use absence deduction from database if available, otherwise calculate
    final absenceDeduction = _toDouble(payslipData['absence_deduction']) ?? 0.0;
    
    // Total deductions: prefer database value, otherwise sum components
    final totalDeductions = _toDouble(payslipData['total_deductions']) ??
        (pf + esi + professionalTax + tds + absenceDeduction);
    
    // Use exact net_salary from database - DO NOT RECALCULATE
    final net = _toDouble(payslipData['net_salary']) ?? (gross - totalDeductions - absenceDeduction);
    
    // For YTD, use provided fields if available, else current month values
    double _ytd(String key, double fallback) {
      final candidates = [
        '${key}_ytd',
        'ytd_$key',
        '${key}Ytd',
        'year_to_date_$key',
      ];
      for (final c in candidates) {
        final v = payslipData[c];
        if (v is num) return v.toDouble();
      }
      return fallback;
    }

    final basicYtd = _ytd('basic_salary', basic);
    final medicalYtd = _ytd('medical_allowance', medical);
    final otherYtd = _ytd('other_allowance', otherAllowance);
    final grossYtd = _ytd('gross_salary', gross);
    final pfYtd = _ytd('pf', pf);
    final esiYtd = _ytd('esi', esi);
    final professionalTaxYtd = _ytd('professional_tax', professionalTax);
    final tdsYtd = _ytd('tds', tds);
    final absenceYtd = _ytd('absence_deduction', absenceDeduction);
    final totalDeductionsYtd = _ytd('total_deductions', totalDeductions);
    
    // Parse dates - use payment_date from database if available
    DateTime? paymentDate;
    
    // First try to use payment_date from database
    if (payslipData['payment_date'] != null) {
      try {
        paymentDate = DateTime.parse(payslipData['payment_date'] as String);
      } catch (e) {
        print('Error parsing payment_date: $e');
      }
    }
    
    // If not in database, calculate from pay_period_end
    if (paymentDate == null && payPeriodEnd != null) {
      try {
        final periodEnd = DateTime.parse(payPeriodEnd);
        paymentDate = periodEnd.add(const Duration(days: 1));
      } catch (e) {
        paymentDate = DateTime.now();
      }
    } else if (paymentDate == null) {
      paymentDate = DateTime.now();
    }
    
    // Format payment date
    final paymentDateStr = DateFormat('dd/MM/yyyy').format(paymentDate);
    
    // Generate filename
    final fileName = 'Payslip_${finalEmployeeCode}_${DateFormat('yyyyMMdd').format(paymentDate)}_${payPeriod.replaceAll(' ', '_')}.pdf';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(16),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header - Company Logo, Name and Payslip Title
              pw.Center(
                child: pw.Column(
                  children: [
                    // Company Logo (if available)
                    if (logoImage != null) ...[
                      pw.Image(
                        logoImage!,
                        width: 80,
                        height: 80,
                        fit: pw.BoxFit.contain,
                      ),
                      pw.SizedBox(height: 12),
                    ],
                    pw.Text(
                      finalOrganizationName,
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                        decoration: pw.TextDecoration.underline,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'PAYSLIP FOR THE MONTH OF ${payPeriod.toUpperCase()}',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                        letterSpacing: 0.5,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 24),
              
              // Employee Pay Summary Section (Boxed)
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300, width: 1),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Left Column
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildSummaryRow('Employee Name:', finalEmployeeName),
                          pw.SizedBox(height: 8),
                          _buildSummaryRow('Designation:', designation),
                          pw.SizedBox(height: 8),
                          _buildSummaryRow('Date of Joining:', dateOfJoining),
                          pw.SizedBox(height: 8),
                          _buildSummaryRow('Pay Period:', payPeriod),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 24),
                    // Right Column
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildSummaryRow('Pay Date:', paymentDateStr),
                          pw.SizedBox(height: 12),
                          pw.Text(
                            'Employee Net Pay',
                            style: pw.TextStyle(
                              fontSize: 12,
                              color: PdfColors.grey700,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            '$currencySymbol${_formatCurrency(net)}',
                            style: pw.TextStyle(
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.black,
                              font: unicodeFont,
                            ),
                          ),
                          pw.SizedBox(height: 12),
                          pw.Text(
                            'Paid Days: $workingDays | LOP Days: $lopDays',
                            style: const pw.TextStyle(
                              fontSize: 12,
                              color: PdfColors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 24),
              
              // Earnings and Deductions Section
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Earnings Section (Boxed)
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(16),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey700, width: 1.5),
                        borderRadius: pw.BorderRadius.circular(4),
                        color: PdfColors.white,
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'EARNINGS',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.black,
                            ),
                          ),
                          pw.SizedBox(height: 12),
                          _buildTableHeader(['AMOUNT', 'YTD']),
                          pw.SizedBox(height: 8),
                          _buildTableRow('Basic', basic, basicYtd, currencySymbol, font: unicodeFont),
                          pw.SizedBox(height: 8),
                          _buildTableRow('Medical Allowance', medical, medicalYtd, currencySymbol, font: unicodeFont),
                          pw.SizedBox(height: 8),
                          _buildTableRow('Other Allowances', otherAllowance, otherYtd, currencySymbol, font: unicodeFont),
                          pw.SizedBox(height: 8),
                          _buildTableRow('Gross Earnings', gross, grossYtd, currencySymbol, isBold: true, font: unicodeFont),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 24),
                  // Deductions Section (Boxed)
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(16),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey700, width: 1.5),
                        borderRadius: pw.BorderRadius.circular(4),
                        color: PdfColors.white,
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'DEDUCTIONS',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.black,
                            ),
                          ),
                          pw.SizedBox(height: 12),
                          _buildTableHeader(['AMOUNT', 'YTD']),
                          pw.SizedBox(height: 8),
                          if (professionalTax > 0) ...[
                            _buildTableRow('Professional Tax', professionalTax, professionalTaxYtd, currencySymbol, font: unicodeFont),
                            pw.SizedBox(height: 8),
                          ],
                          if (pf > 0) ...[
                            _buildTableRow('Provident Fund', pf, pfYtd, currencySymbol, font: unicodeFont),
                            pw.SizedBox(height: 8),
                          ],
                          if (esi > 0) ...[
                            _buildTableRow('ESI', esi, esiYtd, currencySymbol, font: unicodeFont),
                            pw.SizedBox(height: 8),
                          ],
                          if (tds > 0) ...[
                            _buildTableRow('TDS', tds, tdsYtd, currencySymbol, font: unicodeFont),
                            pw.SizedBox(height: 8),
                          ],
                          if (absenceDeduction > 0) ...[
                            _buildTableRow('Absence Deduction', absenceDeduction, absenceYtd, currencySymbol, font: unicodeFont),
                            pw.SizedBox(height: 8),
                          ],
                          _buildTableRow('Total Deductions', totalDeductions, totalDeductionsYtd, currencySymbol, isBold: true, font: unicodeFont),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              pw.SizedBox(height: 24),
              
              // Net Pay Section
              pw.Text(
                'NET PAY',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
              pw.SizedBox(height: 12),
              _buildNetPayRow('Gross Earnings:', '$currencySymbol${_formatCurrency(gross)}', font: unicodeFont),
              pw.SizedBox(height: 8),
              _buildNetPayRow('Total Deductions:', '(-) $currencySymbol${_formatCurrency(totalDeductions)}', font: unicodeFont),
              pw.SizedBox(height: 8),
              _buildNetPayRow('Total Net Payable:', '$currencySymbol${_formatCurrency(net)}', isBold: true, font: unicodeFont),
              
              pw.SizedBox(height: 24),
              
              // Net Pay in Words
              pw.Text(
                'Total Net Payable $currencySymbol${_formatCurrency(net)} (${_numberToWords(net, currency)})',
                style: const pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.black,
                ),
              ),
              
              pw.SizedBox(height: 24),
              
              // Footer
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '**Total Net Payable = Gross Earnings - Total Deductions',
                    style: pw.TextStyle(
                      fontSize: 11,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'This is a computer-generated payslip and does not require a signature.',
                    style: pw.TextStyle(
                      fontSize: 11,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    // Save PDF to file
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Desktop platforms
      final directory = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(await pdf.save());
      await OpenFilex.open(file.path);
    } else {
      // Mobile platforms - use printing package
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    }
  }

  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 120,
          child: pw.Text(
            label,
            style: const pw.TextStyle(
              fontSize: 13,
              color: PdfColors.grey700,
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
            textAlign: pw.TextAlign.right,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildSummaryRow(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 100,
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 12,
              color: PdfColors.grey700,
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildTableHeader(List<String> headers) {
    return pw.Row(
      children: [
        // Label column
        pw.Expanded(
          flex: 2,
          child: pw.Text(
            '',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
        ),
        pw.SizedBox(width: 8),
        // Amount column – wider so values like "Rs.35,000.00" stay on one line
        pw.Expanded(
          flex: 3,
          child: pw.Text(
            headers[0],
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
            textAlign: pw.TextAlign.right,
          ),
        ),
        pw.SizedBox(width: 8),
        // YTD column – same width as Amount
        pw.Expanded(
          flex: 3,
          child: pw.Text(
            headers[1],
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
            textAlign: pw.TextAlign.right,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildTableRow(String label, double amount, double ytd, String currencySymbol, {bool isBold = false, pw.Font? font}) {
    return pw.Row(
      children: [
        // Label column
        pw.Expanded(
          flex: 2,
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: PdfColors.black,
            ),
          ),
        ),
        pw.SizedBox(width: 8),
        // Amount column
        pw.Expanded(
          flex: 3,
          child: pw.Text(
            '$currencySymbol${_formatCurrency(amount)}',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: PdfColors.black,
              font: font,
            ),
            textAlign: pw.TextAlign.right,
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
          ),
        ),
        pw.SizedBox(width: 8),
        // YTD column
        pw.Expanded(
          flex: 3,
          child: pw.Text(
            '$currencySymbol${_formatCurrency(ytd)}',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: PdfColors.black,
              font: font,
            ),
            textAlign: pw.TextAlign.right,
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildNetPayRow(String label, String value, {bool isBold = false, pw.Font? font}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: PdfColors.black,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.bold,
            color: PdfColors.black,
            font: font,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildAmountRow(String label, double amount, String currencySymbol, {bool isTotal = false, pw.Font? font}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: isTotal ? 14 : 13,
              fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: PdfColors.black,
            ),
          ),
        ),
        pw.SizedBox(width: 16),
        pw.Text(
          '$currencySymbol${_formatCurrency(amount)}',
          style: pw.TextStyle(
            fontSize: isTotal ? 14 : 13,
            fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: PdfColors.black,
            font: font, // Use Unicode font if available
          ),
          textAlign: pw.TextAlign.right,
        ),
      ],
    );
  }

  String _formatCurrency(double amount) {
    return NumberFormat('#,##0.00').format(amount);
  }

  String _numberToWords(double amount, String currency) {
    final wholePart = amount.toInt();
    
    String currencyName = 'Indian Rupee';
    if (currency == 'QAR') {
      currencyName = 'Qatari Riyals';
    } else if (currency == 'USD') {
      currencyName = 'Dollars';
    }
    
    String words = _convertNumberToWords(wholePart);
    words += ' $currencyName Only';
    
    return words;
  }

  String _convertNumberToWords(int number) {
    if (number == 0) return 'Zero';
    
    final ones = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 
                  'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 
                  'Seventeen', 'Eighteen', 'Nineteen'];
    final tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];
    
    if (number < 20) {
      return ones[number];
    } else if (number < 100) {
      return '${tens[number ~/ 10]} ${ones[number % 10]}'.trim();
    } else if (number < 1000) {
      return '${ones[number ~/ 100]} Hundred ${_convertNumberToWords(number % 100)}'.trim();
    } else if (number < 100000) {
      return '${_convertNumberToWords(number ~/ 1000)} Thousand ${_convertNumberToWords(number % 1000)}'.trim();
    } else if (number < 10000000) {
      return '${_convertNumberToWords(number ~/ 100000)} Lakh ${_convertNumberToWords(number % 100000)}'.trim();
    } else {
      return '${_convertNumberToWords(number ~/ 10000000)} Crore ${_convertNumberToWords(number % 10000000)}'.trim();
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
}







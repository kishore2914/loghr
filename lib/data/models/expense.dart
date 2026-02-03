enum ExpenseStatus {
  draft,
  pending,
  approved,
  rejected,
  acknowledged,
  settled,
  reimbursed,
  deducted,
}

enum ReimbursementType {
  cash,
  payroll,
  bankTransfer,
  notReimbursed,
}

class ExpenseClaim {
  final String id;
  final String expenseNumber;
  final String userId;
  final String employeeId;
  final String employeeName;
  final String? claimantName;
  final DateTime expenseDate;
  final String category;
  final String? categoryId;
  final String merchantName;
  final double amount;
  final String currency;
  final ExpenseStatus status;
  final ReimbursementType? reimbursementMethod;
  final DateTime createdAt;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectionReason;
  final DateTime? reimbursedAt;
  final String? reimbursementReference;
  final String? receiptUrl;
  final String? proofDocumentUrl;
  final String? description;
  final String? formattedEmployeeId;

  ExpenseClaim({
    required this.id,
    required this.expenseNumber,
    required this.userId,
    required this.employeeId,
    required this.employeeName,
    this.claimantName,
    required this.expenseDate,
    required this.category,
    this.categoryId,
    required this.merchantName,
    required this.amount,
    this.currency = 'INR',
    required this.status,
    this.reimbursementMethod,
    required this.createdAt,
    this.approvedBy,
    this.approvedAt,
    this.rejectionReason,
    this.reimbursedAt,
    this.reimbursementReference,
    this.receiptUrl,
    this.proofDocumentUrl,
    this.description,
    this.formattedEmployeeId,
  });
  
  // Getter for backward compatibility
  String get expenseId => expenseNumber;
  DateTime get date => expenseDate;
  String get merchant => merchantName;
  ReimbursementType? get reimbursementType => reimbursementMethod;

  factory ExpenseClaim.fromJson(Map<String, dynamic> json) {
    // Parse status
    final statusString = (json['status'] as String? ?? 'pending').toLowerCase();
    ExpenseStatus parsedStatus;
    switch (statusString) {
      case 'draft':
        parsedStatus = ExpenseStatus.draft;
        break;
      case 'approved':
        parsedStatus = ExpenseStatus.approved;
        break;
      case 'rejected':
        parsedStatus = ExpenseStatus.rejected;
        break;
      case 'acknowledged':
        parsedStatus = ExpenseStatus.acknowledged;
        break;
      case 'settled':
        parsedStatus = ExpenseStatus.settled;
        break;
      case 'reimbursed':
        parsedStatus = ExpenseStatus.reimbursed;
        break;
      case 'deducted':
        parsedStatus = ExpenseStatus.deducted;
        break;
      default:
        parsedStatus = ExpenseStatus.pending;
    }

    // Parse reimbursement method
    ReimbursementType? reimbursementMethod;
    final reimbursementMethodStr = json['reimbursement_method'] as String?;
    if (reimbursementMethodStr != null) {
      final methodLower = reimbursementMethodStr.toLowerCase();
      switch (methodLower) {
        case 'cash':
          reimbursementMethod = ReimbursementType.cash;
          break;
        case 'payroll':
          reimbursementMethod = ReimbursementType.payroll;
          break;
        case 'bank_transfer':
          reimbursementMethod = ReimbursementType.bankTransfer;
          break;
        default:
          reimbursementMethod = ReimbursementType.notReimbursed;
      }
    }

    // Extract employee name - ALWAYS prioritize employees table
    String employeeName = 'Unknown';
    String? formattedEmployeeId;
    String categoryName = 'Other';
    
    // Try to get category name from nested expense_categories (prioritized)
    if (json['expense_categories'] is Map<String, dynamic>) {
      categoryName = json['expense_categories']['name'] as String? ?? 'Other';
    }
    // Fallback: try direct category field if it's a string (not just "Other")
    else if (json['category'] is String && (json['category'] as String).isNotEmpty && (json['category'] as String).toLowerCase() != 'other') {
      categoryName = json['category'] as String;
    }
    
    // ALWAYS try to get employee name from nested employees table first
    if (json['employees'] != null && json['employees'] is Map<String, dynamic>) {
      final empData = json['employees'] as Map<String, dynamic>;
      employeeName = empData['full_name'] as String? ?? 
                    empData['name'] as String? ??
                    empData['first_name'] as String? ??
                    empData['employee_name'] as String? ??
                    'Unknown';
      
      if (employeeName != 'Unknown') {
        print('ExpenseClaim.fromJson: Using employee name from employees table: $employeeName');
      } else {
        print('ExpenseClaim.fromJson: Warning - employees data exists but no valid name field found: $empData');
      }
    }
    // Fallback to user_profiles only if employees table doesn't have it
    else if (json['user_profiles'] != null && json['user_profiles'] is Map<String, dynamic>) {
      final profileData = json['user_profiles'] as Map<String, dynamic>;
      employeeName = profileData['full_name'] as String? ?? 
                     json['employee_name'] as String? ?? 
                     'Unknown';
      formattedEmployeeId = profileData['employee_id'] as String?;
      print('ExpenseClaim.fromJson: Using employee name from user_profiles: $employeeName');
    } else if (json['employee_name'] != null) {
      employeeName = json['employee_name'] as String;
      print('ExpenseClaim.fromJson: Using employee_name directly from json: $employeeName');
    } else {
      // Last resort
      final empId = json['employee_id'] as String?;
      print('ExpenseClaim.fromJson: Warning - No employee name found in any source. employee_id: $empId');
      employeeName = 'Unknown';
    }

    // Get employee_id (primary identifier)
    final employeeIdFromJson = json['employee_id'] as String? ?? '';
    
    // Try to get user_id from nested user_profiles if available, otherwise use employee_id
    String userIdValue = employeeIdFromJson;
    if (json['user_profiles'] is Map<String, dynamic>) {
      userIdValue = json['user_profiles']['user_id'] as String? ?? employeeIdFromJson;
    }

    // Robust amount parsing - support multiple possible column names and formats
    double parsedAmount = 0.0;
    double? _tryParseAmount(dynamic value) {
      if (value == null) {
        print('ExpenseClaim.fromJson: Amount value is null');
        return null;
      }
      
      // Handle numeric types (including 0)
      if (value is num) {
        final doubleValue = value.toDouble();
        // Allow 0 values (they might be valid, or indicate missing data)
        if (doubleValue == 0.0) {
          print('ExpenseClaim.fromJson: Amount is 0.0 - this might indicate missing data');
          return 0.0; // Return 0.0 instead of null so we can track it
        }
        // Validate reasonable amount (not astronomically large - max 1 billion)
        if (doubleValue > 0 && doubleValue <= 1000000000) {
          return doubleValue;
        } else if (doubleValue > 1000000000) {
          // If amount is too large, it might be stored in smallest currency unit (paise/cents)
          // Convert from paise to rupees (divide by 100)
          final converted = doubleValue / 100.0;
          if (converted > 0 && converted <= 1000000000) {
            print('ExpenseClaim.fromJson: Amount $doubleValue seems too large, converting from smallest currency unit to $converted');
            return converted;
          }
        }
        print('ExpenseClaim.fromJson: Amount $doubleValue is invalid (negative or too large)');
        return null;
      }
      
      // Handle string types
      if (value is String) {
        final cleaned = value.replaceAll(RegExp(r'[^\d\.\-]'), '');
        if (cleaned.isEmpty) return null;
        final parsed = double.tryParse(cleaned);
        if (parsed != null && parsed > 0 && parsed <= 1000000000) {
          print('ExpenseClaim.fromJson: Parsed amount from string "$value" -> $parsed');
          return parsed;
        } else if (parsed != null && parsed > 1000000000) {
          // Try converting from smallest currency unit
          final converted = parsed / 100.0;
          if (converted > 0 && converted <= 1000000000) {
            print('ExpenseClaim.fromJson: Amount $parsed seems too large, converting from smallest currency unit to $converted');
            return converted;
          }
        }
        return null;
      }
      return null;
    }

    // Priority: Use 'amount' field first (most common)
    print('\n💰 PARSING AMOUNT FOR EXPENSE: ${json['expense_number'] ?? json['id']}');
    print('💰 JSON keys available: ${json.keys.toList()}');
    
    if (json.containsKey('amount')) {
      final rawValue = json['amount'];
      print('💰 Found "amount" key! Value: $rawValue (type: ${rawValue.runtimeType}, isNull: ${rawValue == null})');
      final v = _tryParseAmount(rawValue);
      if (v != null) {
        parsedAmount = v;
        if (v > 0) {
          print('💰 ✅ SUCCESS: Parsed amount = $parsedAmount');
        } else {
          print('💰 ⚠️  WARNING: Amount parsed as 0.0 from "amount" key');
        }
      } else {
        print('💰 ❌ FAILED: Could not parse amount from "amount" key: $rawValue');
      }
    } else {
      print('💰 ❌ "amount" key NOT FOUND in JSON!');
      print('💰 Available keys: ${json.keys.toList()}');
    }
    

    // Fallback to other amount keys only if primary amount is 0 or invalid
    if (parsedAmount == 0.0) {
      const amountKeys = [
        'claimed_amount',
        'claim_amount',
        'expense_amount',
        'total_amount',
        'reimbursed_amount',
        'net_amount',
        'approved_amount',
        'value',
        'cost',
        'price',
        'sum',
      ];

      for (final key in amountKeys) {
        if (json.containsKey(key)) {
          final rawValue = json[key];
          print('ExpenseClaim.fromJson: Checking key "$key" = $rawValue (type: ${rawValue.runtimeType})');
          final v = _tryParseAmount(rawValue);
          if (v != null && v > 0) {
            parsedAmount = v;
            print('ExpenseClaim.fromJson: ✓ Found amount $parsedAmount from key "$key"');
            break;
          }
        }
      }
    }

    // Last resort: look for any key containing "amount", "value", "cost", "price" (but skip if we already found one)
    if (parsedAmount == 0.0) {
      print('ExpenseClaim.fromJson: Amount still 0, searching all keys for amount-related fields...');
      for (final entry in json.entries) {
        final key = entry.key.toLowerCase();
        if ((key.contains('amount') || key.contains('value') || key.contains('cost') || key.contains('price') || key.contains('sum')) 
            && key != 'amount') {
          print('ExpenseClaim.fromJson: Found potential amount field "${entry.key}" = ${entry.value} (type: ${entry.value.runtimeType})');
          final v = _tryParseAmount(entry.value);
          if (v != null && v > 0) {
            parsedAmount = v;
            print('ExpenseClaim.fromJson: ✓ Found amount $parsedAmount from key "${entry.key}"');
            break;
          }
        }
      }
    }
    
    // Even more last resort: check ALL numeric fields if amount is still 0
    if (parsedAmount == 0.0) {
      print('ExpenseClaim.fromJson: Amount still 0, checking ALL numeric fields...');
      for (final entry in json.entries) {
        if (entry.value is num && entry.key != 'id' && !entry.key.contains('date') && !entry.key.contains('time')) {
          final numValue = (entry.value as num).toDouble();
          if (numValue > 0 && numValue <= 1000000000) {
            print('ExpenseClaim.fromJson: Found positive numeric field "${entry.key}" = $numValue - using as amount');
            parsedAmount = numValue;
            break;
          }
        }
      }
    }

    if (parsedAmount == 0.0) {
      print('ExpenseClaim.fromJson: ⚠ WARNING - Amount is 0.0 after all parsing attempts.');
      print('ExpenseClaim.fromJson: Available keys: ${json.keys.toList()}');
      // Log all numeric fields that might be amounts
      for (var entry in json.entries) {
        if (entry.value is num) {
          print('ExpenseClaim.fromJson: Numeric field "${entry.key}": ${entry.value}');
        }
      }
      print('ExpenseClaim.fromJson: Full JSON: $json');
    } else if (parsedAmount > 1000000000) {
      print('ExpenseClaim.fromJson: ⚠ WARNING - Amount seems unreasonably large: $parsedAmount. This might indicate a data issue.');
    }

    return ExpenseClaim(
      id: json['id'] as String,
      expenseNumber: json['expense_number'] as String? ?? json['id'] as String,
      userId: userIdValue,
      employeeId: employeeIdFromJson,
      employeeName: employeeName,
      claimantName: json['claimant_name'] as String?,
      expenseDate: json['expense_date'] != null 
          ? DateTime.parse(json['expense_date'] as String)
          : json['created_at'] != null
              ? DateTime.parse(json['created_at'] as String)
              : DateTime.now(),
      category: categoryName,
      categoryId: json['category_id'] as String?,
      merchantName: json['merchant_name'] as String? ?? 'N/A',
      amount: parsedAmount,
      currency: json['currency'] as String? ?? 'INR',
      status: parsedStatus,
      reimbursementMethod: reimbursementMethod,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      approvedBy: json['approved_by'] as String?,
      approvedAt: json['approved_at'] != null 
          ? DateTime.parse(json['approved_at'] as String)
          : null,
      rejectionReason: json['rejection_reason'] as String?,
      reimbursedAt: json['reimbursed_at'] != null
          ? DateTime.parse(json['reimbursed_at'] as String)
          : null,
      reimbursementReference: json['reimbursement_reference'] as String?,
      receiptUrl: json['receipt_url'] as String?,
      proofDocumentUrl: json['proof_document_url'] as String?,
      description: json['description'] as String?,
      formattedEmployeeId: formattedEmployeeId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'expense_id': expenseId,
      'user_id': userId,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'claimant_name': claimantName,
      'date': date.toIso8601String(),
      'category': category,
      'merchant': merchant,
      'amount': amount,
      'status': status.toString().split('.').last,
      'reimbursement_status': reimbursementType?.toString().split('.').last ?? 'not_reimbursed',
      'created_at': createdAt.toIso8601String(),
      'approved_by': approvedBy,
      'approved_at': approvedAt?.toIso8601String(),
      'rejection_reason': rejectionReason,
    };
  }

  String get reimbursementStatusDisplay {
    if (reimbursementMethod == null || status != ExpenseStatus.reimbursed) {
      return 'NOT REIMBURSED';
    }
    switch (reimbursementMethod!) {
      case ReimbursementType.cash:
        return 'REIMBURSED (CASH)';
      case ReimbursementType.payroll:
        return 'REIMBURSED (PAYROLL)';
      case ReimbursementType.bankTransfer:
        return 'REIMBURSED (BANK TRANSFER)';
      case ReimbursementType.notReimbursed:
        return 'NOT REIMBURSED';
    }
  }
}

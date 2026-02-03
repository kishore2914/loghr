import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:loghr_mobile/data/models/leave.dart';
import 'package:loghr_mobile/logic/auth_provider.dart';
import 'package:loghr_mobile/logic/leave_provider.dart';
import 'package:loghr_mobile/logic/attendance_provider.dart';
import 'package:loghr_mobile/utils/helpers.dart';

class ApplyLeaveSheet extends StatefulWidget {
  const ApplyLeaveSheet({super.key});

  @override
  State<ApplyLeaveSheet> createState() => _ApplyLeaveSheetState();
}

class _ApplyLeaveSheetState extends State<ApplyLeaveSheet> {
  final _formKey = GlobalKey<FormState>();
  
  String? _selectedLeaveTypeId;
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _isHalfDay = false;
  final _contactController = TextEditingController();
  final _reasonController = TextEditingController();
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Ensure types, balances, and today's attendance are loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        context.read<LeaveProvider>().loadLeaveTypes();
        context.read<LeaveProvider>().loadLeaveBalances(user.id);
        context.read<AttendanceProvider>().loadTodayAttendance(user.id);
      }
    });
  }

  @override
  void dispose() {
    _contactController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFF00A76F),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isFromDate) {
          // Normalize the picked date to local midnight to avoid timezone issues
          _fromDate = DateTime(picked.year, picked.month, picked.day);
          if (_toDate != null && _toDate!.isBefore(_fromDate!)) {
            _toDate = null;
          }
          
          // Check if user has checked in today and selected today as from date
          final attendanceProvider = context.read<AttendanceProvider>();
          final todayAttendance = attendanceProvider.todayAttendance;
          final isCheckedIn = todayAttendance != null && 
                             todayAttendance.checkInTime != null && 
                             todayAttendance.checkOutTime == null;
          
          final now = DateTime.now();
          final todayOnly = DateTime(now.year, now.month, now.day);
          
          // Compare dates by year, month, and day only
          final daysDiff = _fromDate!.difference(todayOnly).inDays;
          final isToday = daysDiff == 0;
          
          print('Date selected: picked=${picked.toString().split(' ')[0]}, normalized=${_fromDate!.toString().split(' ')[0]}, today=${todayOnly.toString().split(' ')[0]}, daysDiff=$daysDiff, isToday=$isToday, isCheckedIn=$isCheckedIn');
          
          // If checked in and selected today, automatically set half-day
          if (isCheckedIn && isToday && !_isHalfDay) {
            _isHalfDay = true;
            _toDate = null; // Clear to date for half-day
            print('Auto-set half-day: User checked in today and selected today as from date');
          }
        } else {
          // Normalize to date as well
          _toDate = DateTime(picked.year, picked.month, picked.day);
        }
      });
    }
  }

  // Helper to check if two dates are the same day
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }
  
  // Helper to normalize a date to midnight (local time)
  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool _shouldShowWarning(AttendanceProvider attendanceProvider) {
    final todayAttendance = attendanceProvider.todayAttendance;
    final isCheckedIn = todayAttendance != null && 
                       todayAttendance.checkInTime != null && 
                       todayAttendance.checkOutTime == null;
    
    if (!isCheckedIn) {
      print('Warning: User not checked in. todayAttendance=${todayAttendance?.checkInTime}, checkOut=${todayAttendance?.checkOutTime}');
      return false;
    }
    
    if (_fromDate == null) {
      return false;
    }
    
    // Get today's date (normalized to local midnight)
    final now = DateTime.now();
    final today = _normalizeDate(now);
    
    // Normalize selected date to ensure consistent comparison
    final selected = _normalizeDate(_fromDate!);
    
    // Check if selected date is today
    final isToday = _isSameDay(selected, today);
    
    final shouldShow = isToday && !_isHalfDay;
    
    // Debug logging - always log when date is selected
    print('=== Warning Check ===');
    print('isCheckedIn: $isCheckedIn');
    print('selected date (raw): ${_fromDate.toString()}');
    print('selected date (normalized): ${selected.toString()}');
    print('today (normalized): ${today.toString()}');
    print('isToday: $isToday');
    print('isHalfDay: $_isHalfDay');
    print('shouldShow: $shouldShow');
    print('====================');
    
    return shouldShow;
  }

  double _calculateDays() {
    if (_isHalfDay) return 0.5;
    if (_fromDate == null) return 0.0;
    
    final end = _toDate ?? _fromDate!; 
    final diff = end.difference(_fromDate!).inDays + 1;
    return diff.toDouble();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedLeaveTypeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a leave type')),
      );
      return;
    }

    if (_fromDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select From Date')),
      );
      return;
    }
    
    // Check if user has checked in today and trying to apply full-day leave for today
    final attendanceProvider = context.read<AttendanceProvider>();
    final todayAttendance = attendanceProvider.todayAttendance;
    final isCheckedIn = todayAttendance != null && 
                       todayAttendance.checkInTime != null && 
                       todayAttendance.checkOutTime == null;
    
    final today = DateTime.now();
    final fromDateOnly = DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
    final todayOnly = DateTime(today.year, today.month, today.day);
    
    if (isCheckedIn && fromDateOnly.isAtSameMomentAs(todayOnly) && !_isHalfDay) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot apply full-day leave for today as you have already checked in. Please select half-day leave.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    if (_toDate == null && !_isHalfDay) { 
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select To Date')),
      );
      return;
    }

    // Check leave balance
    final leaveProvider = context.read<LeaveProvider>();
    final balance = leaveProvider.leaveBalances.firstWhere(
      (b) => b.leaveTypeId == _selectedLeaveTypeId,
      orElse: () => LeaveBalance(
        leaveTypeId: _selectedLeaveTypeId!, 
        leaveName: '', 
        leaveCode: '', 
        total: 0, 
        used: 0, 
        available: 0,
      ),
    );
    
    final daysRequested = _calculateDays();
    if (balance.available <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You do not have any available balance for this leave type.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (daysRequested > balance.available) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Requested days ($daysRequested) exceeds your available balance (${balance.available}).'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final user = context.read<AuthProvider>().user;
    if (user != null) {
      final days = _calculateDays();
      
      final success = await context.read<LeaveProvider>().applyLeave(
        userId: user.id,
        leaveTypeId: _selectedLeaveTypeId!,
        startDate: _fromDate!,
        endDate: _isHalfDay ? _fromDate! : _toDate!,
        reason: _reasonController.text,
        days: days,
        contactNumber: _contactController.text.trim().isNotEmpty 
            ? _contactController.text.trim() 
            : null,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          Navigator.pop(context);
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Leave application submitted successfully'),
              backgroundColor: Color(0xFF00A76F),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to submit application')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F1724);
    final borderColor = isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300;
    
    final leaveProvider = context.watch<LeaveProvider>();
    final attendanceProvider = context.watch<AttendanceProvider>();
    final leaveTypes = leaveProvider.leaveTypes;
    final leaveBalances = leaveProvider.leaveBalances;
    
    // Create a map of leave type ID to balance for quick lookup
    final balanceMap = <String, LeaveBalance>{};
    for (var balance in leaveBalances) {
      balanceMap[balance.leaveTypeId] = balance;
    }
    
    // Calculate warning visibility
    final shouldShowWarning = _shouldShowWarning(attendanceProvider);
    
    // Debug: Log the final result
    if (_fromDate != null) {
      print('Build: shouldShowWarning=$shouldShowWarning, fromDate=${_fromDate.toString().split(' ')[0]}, isHalfDay=$_isHalfDay');
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFF00A76F),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                const Text(
                  'Apply for Leave',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Form Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Leave Type
                    _buildLabel('Leave Type', textColor, isRequired: true),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: borderColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedLeaveTypeId,
                          dropdownColor: bgColor,
                          hint: const Text('Select leave type', style: TextStyle(color: Colors.grey)),
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down),
                          style: TextStyle(color: textColor, fontSize: 16),
                          items: leaveTypes.map((type) {
                            final balance = balanceMap[type.id];
                            final available = balance?.available ?? 0.0;
                            final availableText = available > 0 
                                ? '${available.toInt()} available' 
                                : '0 available';
                            
                            return DropdownMenuItem(
                              value: type.id,
                              child: Text('${type.name} ($availableText)'),
                            );
                          }).toList(),
                          onChanged: (value) => setState(() => _selectedLeaveTypeId = value),
                        ),
                      ),
                    ),
                    if (_selectedLeaveTypeId != null) 
                      Builder(builder: (context) {
                        final balance = balanceMap[_selectedLeaveTypeId];
                        final available = balance?.available ?? 0.0;
                        if (available <= 0) {
                          return const Padding(
                            padding: EdgeInsets.only(top: 8, left: 4),
                            child: Text(
                              'No available balance for this leave type.',
                              style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      }),
                    const SizedBox(height: 20),

                    // Dates
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('From Date', textColor, isRequired: true),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () => _selectDate(true),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: borderColor),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _fromDate != null 
                                            ? DateFormat('dd-MM-yyyy').format(_fromDate!) 
                                            : 'dd-mm-yyyy',
                                        style: TextStyle(
                                          color: _fromDate != null ? textColor : Colors.grey,
                                        ),
                                      ),
                                      const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                                    ],
                                  ),
                                ),
                              ),
                              // Warning message if checked in today and from date is today
                              if (shouldShowWarning)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.orange.shade300, width: 1),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.warning_amber_rounded, 
                                          color: Colors.orange.shade700, 
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Cannot apply full-day leave for today as you have already checked in. You can apply half-day leave for today.',
                                            style: TextStyle(
                                              color: Colors.orange.shade700,
                                              fontSize: 12,
                                              height: 1.4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('To Date', textColor, isRequired: true),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: _isHalfDay ? null : () => _selectDate(false),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _isHalfDay 
                                        ? (isDark ? Colors.grey.shade900 : Colors.grey.shade100) 
                                        : bgColor,
                                    border: Border.all(color: borderColor),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _toDate != null 
                                            ? DateFormat('dd-MM-yyyy').format(_toDate!) 
                                            : 'dd-mm-yyyy',
                                        style: TextStyle(
                                          color: _toDate != null ? textColor : Colors.grey,
                                        ),
                                      ),
                                      const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                                    ],
                                  ),
                                ),
                              ),
                              // Spacer to match warning height when it appears
                              if (shouldShowWarning)
                                const SizedBox(height: 60), // Approximate height of warning message
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Half Day Checkbox
                    Row(
                      children: [
                        SizedBox(
                          height: 24,
                          width: 24,
                          child: Checkbox(
                            value: _isHalfDay,
                            activeColor: const Color(0xFF00A76F),
                            side: BorderSide(color: isDark ? Colors.grey.shade400 : Colors.black54, width: 2),
                            onChanged: (value) {
                              setState(() {
                                _isHalfDay = value ?? false;
                                if (_isHalfDay) {
                                  _toDate = null; // Clear to date
                                }
                              });
                            },
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('Half Day Leave', style: TextStyle(fontSize: 14, color: textColor)),
                        
                        const Spacer(),
                        if (_fromDate != null && (_toDate != null || _isHalfDay))
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${_calculateDays()} Days',
                              style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Contact Number
                    _buildLabel('Contact Number (During Leave)', textColor),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _contactController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: 'Optional',
                        hintStyle: const TextStyle(color: Colors.grey),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF00A76F)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Reason
                    _buildLabel('Reason for Leave', textColor, isRequired: true),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _reasonController,
                      maxLines: 4,
                      style: TextStyle(color: textColor),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please provide a reason';
                        }
                        if (value.length < 10) {
                          return 'Reason must be at least 10 characters';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        hintText: 'Please provide a detailed reason (minimum 10 characters)',
                        hintStyle: const TextStyle(color: Colors.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF00A76F)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: borderColor),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              foregroundColor: textColor,
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _submit,
                            icon: _isLoading 
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.check, size: 18),
                            label: Text(
                              _isLoading ? 'Submitting...' : 'Submit Application',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00A76F),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String label, Color textColor, {bool isRequired = false}) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        if (isRequired)
          const Text(
            ' *',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
      ],
    );
  }
}

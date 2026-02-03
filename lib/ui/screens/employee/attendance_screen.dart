import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:loghr_mobile/logic/auth_provider.dart';
import 'package:loghr_mobile/logic/attendance_provider.dart';
import 'package:loghr_mobile/logic/leave_provider.dart';
import 'package:loghr_mobile/data/models/attendance.dart';
import 'package:loghr_mobile/data/models/leave.dart';
import 'package:loghr_mobile/utils/helpers.dart';
import 'package:loghr_mobile/config/supabase_config.dart';

class AttendanceScreen extends StatefulWidget {
  final VoidCallback? onNavigateToDashboard;
  
  const AttendanceScreen({
    super.key,
    this.onNavigateToDashboard,
  });

  @override
  State<AttendanceScreen> createState() => AttendanceScreenState();
}

class AttendanceScreenState extends State<AttendanceScreen> with SingleTickerProviderStateMixin {
  Position? _currentPosition;
  bool _isLoadingLocation = false;
  bool _gpsEnabled = false;
  bool _locationPermissionDenied = false;
  DateTime _currentTime = DateTime.now();
  Timer? _timeTimer;
  late TabController _tabController;
  int _selectedTabIndex = 0;
  DateTime _selectedMonth = DateTime.now();
  DateTime _selectedStartDate = DateTime.now();
  DateTime _selectedEndDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedTabIndex = _tabController.index;
      });
    });
    _updateTime();
    _selectedStartDate = DateTime(_selectedStartDate.year, _selectedStartDate.month, 1);
    _selectedEndDate = DateTime(_selectedStartDate.year, _selectedStartDate.month + 1, 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      _checkGPSStatus();
    });
  }

  @override
  void dispose() {
    _timeTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _updateTime() {
    if (!mounted) return;
    setState(() {
      _currentTime = DateTime.now();
    });
    if (mounted) {
      _timeTimer = Timer(const Duration(seconds: 1), _updateTime);
    }
  }

  void _loadData() {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;
    if (user != null) {
      context.read<AttendanceProvider>().loadTodayAttendance(user.id);
      context.read<AttendanceProvider>().loadHistory(user.id);
      context.read<LeaveProvider>().loadUserLeaves(user.id);
    }
  }

  Future<void> _checkGPSStatus() async {
    setState(() {
      _isLoadingLocation = true;
      _locationPermissionDenied = false;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      final isEnabled = serviceEnabled &&
            permission != LocationPermission.denied &&
            permission != LocationPermission.deniedForever;

      setState(() {
        _gpsEnabled = isEnabled;
        _locationPermissionDenied = !isEnabled && (permission == LocationPermission.denied || permission == LocationPermission.deniedForever);
        _isLoadingLocation = false;
      });

      if (_gpsEnabled) {
        await _getCurrentLocation();
      }
    } catch (e) {
      setState(() {
        _isLoadingLocation = false;
        _locationPermissionDenied = true;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      setState(() {
        _locationPermissionDenied = true;
      });
    }
  }

  Future<void> _handleCheckIn() async {
    if (!_gpsEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enable location access for check-in.'),
        ),
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final attendanceProvider = context.read<AttendanceProvider>();
    final user = authProvider.user;

    if (user == null) return;

    if (_currentPosition == null) {
      await _getCurrentLocation();
      if (_currentPosition == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to get location. Please enable location services and try again.'),
            ),
          );
        }
        return;
      }
    }

    final success = await attendanceProvider.checkIn(
      userId: user.id,
      latitude: _currentPosition!.latitude,
      longitude: _currentPosition!.longitude,
      address: 'Current Location',
    );

    if (mounted) {
      if (success) {
        _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(attendanceProvider.error ?? 'Check-in failed')),
        );
      }
    }
  }

  Future<void> _handleCheckOut({Attendance? attendanceRecord}) async {
    print('DEBUG: _handleCheckOut called');
    if (!_gpsEnabled) {
      print('DEBUG: GPS not enabled');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enable location access for check-out.'),
        ),
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final attendanceProvider = context.read<AttendanceProvider>();
    final user = authProvider.user;
    final attendance = attendanceRecord ?? attendanceProvider.todayAttendance;

    if (user == null) {
      print('DEBUG: User is null');
      return;
    }
    if (attendance == null) {
      print('DEBUG: Attendance record is null');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active attendance record found')),
      );
      return;
    }

    try {
      if (_currentPosition == null) {
        print('DEBUG: Current position is null, fetching...');
        await _getCurrentLocation();
        if (_currentPosition == null) {
          print('DEBUG: Failed to get location');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Unable to get location. Please enable location services and try again.'),
              ),
            );
          }
          return;
        }
      }
      print('DEBUG: Location obtained: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');

      String? reason;
      if (attendance.checkInTime != null) {
        final workDuration = DateTime.now().difference(attendance.checkInTime!);
        print('DEBUG: Work duration: ${workDuration.inHours} hours');
        if (workDuration.inHours < 8) {
          print('DEBUG: Showing early checkout dialog');
          reason = await _showEarlyCheckoutDialog(context);
          if (reason == null) {
            print('DEBUG: Early checkout dialog cancelled');
            return; // User cancelled
          }
        }
      }

      print('DEBUG: Calling attendanceProvider.checkOut');
      final success = await attendanceProvider.checkOut(
        userId: user.id,
        attendanceId: attendance.id,
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        address: 'Current Location',
        earlyCheckoutReason: reason,
      );
      print('DEBUG: attendanceProvider.checkOut result: $success');

      if (mounted) {
        if (success) {
          print('DEBUG: Checkout successful, reloading data');
          _loadData();
        } else {
          print('DEBUG: Checkout failed: ${attendanceProvider.error}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(attendanceProvider.error ?? 'Check-out failed (Unknown error)')),
          );
        }
      }
    } catch (e, stackTrace) {
      print('DEBUG: Exception in _handleCheckOut: $e\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error during checkout: $e')),
        );
      }
    }
  }

  Future<String?> _showEarlyCheckoutDialog(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Early Checkout'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('You have worked for less than 8 hours.'),
            const SizedBox(height: 16),
            const Text('Please provide a reason for checking out early:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Enter reason...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a reason')),
                );
              }
            },
            child: const Text('SUBMIT'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final attendanceProvider = context.watch<AttendanceProvider>();
    final todayAttendance = attendanceProvider.todayAttendance;
    final isCheckedIn = attendanceProvider.isCheckedIn;
    final history = attendanceProvider.history;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  const Text(
                    'My Attendance',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Track your work hours and manage leave requests.',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            
            // Tabs
            TabBar(
              controller: _tabController,
              labelColor: Colors.blue.shade700,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.blue.shade700,
              indicatorWeight: 2,
              tabs: const [
                Tab(text: 'Check In/Out'),
                Tab(text: 'My Calendar'),
                Tab(text: 'My History'),
              ],
            ),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                  children: [
                  _buildCheckInOutTab(context, attendanceProvider, todayAttendance, isCheckedIn, cardColor, textColor, isDark),
                  _buildCalendarTab(context, history, cardColor, textColor, isDark),
                  _buildHistoryTab(context, history, cardColor, textColor, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckInOutTab(BuildContext context, AttendanceProvider attendanceProvider, 
      Attendance? todayAttendance, bool isCheckedIn, Color cardColor, Color textColor, bool isDark) {
    final dayFormat = DateFormat('EEEE, MMMM d').format(_currentTime).toUpperCase();
    final timeFormat = DateFormat('HH:mm:ss').format(_currentTime);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          // Main Check In/Out Card
          Card(
            elevation: 0,
            color: cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // Date and Time Display
                  Text(
                    dayFormat,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    timeFormat,
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                      fontFeatures: [const FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Location Error Message
                  if (_locationPermissionDenied) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Location Error',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade700,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Location permission denied. Please allow location access.',
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontSize: 11,
                                  ),
                                  softWrap: true,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Incomplete Checkout Warning
                  if (attendanceProvider.incompleteCheckoutFromPreviousDay != null && !isCheckedIn) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 24),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Incomplete Checkout',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange.shade700,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'You have an incomplete checkout from ${DateFormat('MMM dd, yyyy').format(attendanceProvider.incompleteCheckoutFromPreviousDay!.date)}. Please complete the checkout before checking in again.',
                                      style: TextStyle(
                                        color: Colors.orange.shade700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: attendanceProvider.isLoading ? null : () => _handleCheckOut(
                                attendanceRecord: attendanceProvider.incompleteCheckoutFromPreviousDay,
                              ),
                              icon: const Icon(Icons.logout, size: 20),
                              label: Text(
                                'Check Out for ${DateFormat('MMM dd').format(attendanceProvider.incompleteCheckoutFromPreviousDay!.date)}',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  // Check In/Out Button
                  if (todayAttendance?.checkOutTime != null)
                    Container(
                      padding: const EdgeInsets.all(20),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green.shade700, size: 48),
                          const SizedBox(height: 8),
                          Text(
                            'Completed',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (todayAttendance!.checkInTime != null) ...[
                            Text(
                              'First Check In: ${DateFormat('HH:mm').format(todayAttendance.checkInTime!)}',
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                            ),
                          ],
                          if (todayAttendance.checkOutTime != null) ...[
                            Text(
                              'Last Check Out: ${DateFormat('HH:mm').format(todayAttendance.checkOutTime!)}',
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Builder(builder: (context) {
                              final duration = todayAttendance.checkOutTime!.difference(todayAttendance.checkInTime!);
                              final hours = duration.inHours;
                              final minutes = duration.inMinutes % 60;
                              return Text(
                                'Total Duration: ${hours}h ${minutes}m',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade800,
                                  fontSize: 14,
                                ),
                              );
                            }),
                          ],
                          const SizedBox(height: 20),
                          const Divider(),
                          const SizedBox(height: 12),
                          Text(
                            'Need to work more?',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: attendanceProvider.isLoading ? null : _handleCheckIn,
                              icon: const Icon(Icons.login, size: 18),
                              label: const Text('RE-CHECK IN'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade700,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (isCheckedIn)
                    SizedBox(
                      width: double.infinity,
                      height: 120,
                      child: ElevatedButton(
                        onPressed: attendanceProvider.isLoading ? null : _handleCheckOut,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          shape: const CircleBorder(),
                          elevation: 4,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.logout, size: 32),
                            const SizedBox(height: 8),
                            const Text(
                              'Check Out',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'End Day',
                              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8)),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 120,
                      child: ElevatedButton(
                        onPressed: (attendanceProvider.isLoading || attendanceProvider.incompleteCheckoutFromPreviousDay != null) 
                            ? null 
                            : _handleCheckIn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: attendanceProvider.incompleteCheckoutFromPreviousDay != null
                              ? Colors.grey.shade400
                              : Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          shape: const CircleBorder(),
                          elevation: 4,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.location_on, size: 32),
                            const SizedBox(height: 8),
                            const Text(
                              'Check In',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              attendanceProvider.incompleteCheckoutFromPreviousDay != null
                                  ? 'Complete Previous Checkout First'
                                  : 'Start Day',
                              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8)),
                            ),
                          ],
                        ),
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

  Widget _buildCalendarTab(BuildContext context, List<Attendance> history, Color cardColor, Color textColor, bool isDark) {
    final attendanceProvider = context.watch<AttendanceProvider>();
    final leaveProvider = context.watch<LeaveProvider>();
    final userLeaves = leaveProvider.userLeaves;
    final now = DateTime.now();
    final monthStart = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final monthEnd = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    final firstDayOfWeek = monthStart.weekday % 7;
    final daysInMonth = monthEnd.day;
    final days = List.generate(daysInMonth, (i) => i + 1);
    final previousMonthDays = List.generate(firstDayOfWeek, (i) => 
        DateTime(monthStart.year, monthStart.month, 0).day - firstDayOfWeek + i + 1);

    // Calculate monthly leaves from leave_applications (approved leaves in the month)
    final monthlyLeaves = userLeaves.where((leave) {
      // Check if leave is approved
      final isApproved = leave.status.toString().toLowerCase() == 'approved' ||
                        leave.status.toString().toLowerCase().contains('approved');
      
      if (!isApproved) return false;
      
      // Check if leave falls within the selected month
      final startDate = leave.startDate;
      final endDate = leave.endDate;
      
      if (startDate == null || endDate == null) return false;
      
      // Check if there's any overlap between leave period and selected month
      return (startDate.year == _selectedMonth.year && startDate.month == _selectedMonth.month) ||
             (endDate.year == _selectedMonth.year && endDate.month == _selectedMonth.month) ||
             (startDate.isBefore(monthEnd) && endDate.isAfter(monthStart));
    }).fold<int>(0, (sum, leave) {
      // Calculate days within the month
      if (leave.startDate == null || leave.endDate == null) return sum;
      
      final overlapStart = leave.startDate!.isAfter(monthStart) ? leave.startDate! : monthStart;
      final overlapEnd = leave.endDate!.isBefore(monthEnd) ? leave.endDate! : monthEnd;
      
      if (overlapStart.isAfter(overlapEnd)) return sum;
      
      // Count days in overlap (including start and end)
      final daysInOverlap = overlapEnd.difference(overlapStart).inDays + 1;
      return sum + daysInOverlap;
    });

    // Calculate work from home from attendance_records (work_type = 'Remote' for the month)
    // Count both actual check-ins and calendar entries synced from approved Remote/WFH leaves
    final workFromHome = history.where((attendance) {
      // Use date field if checkInTime is null (calendar entries synced from leaves)
      final attendanceDate = attendance.checkInTime ?? attendance.date;
      if (attendanceDate == null) return false;
      
      // Check if date is within selected month
      final dateMatches = attendanceDate.year == _selectedMonth.year && 
                         attendanceDate.month == _selectedMonth.month;
      
      if (!dateMatches) return false;
      
      // Check if work_type is Remote (this includes both actual check-ins and synced calendar entries)
      final workType = attendance.workType?.toLowerCase();
      return workType == 'remote';
    }).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Month Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today, size: 24, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        DateFormat('MMMM yyyy').format(_selectedMonth),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
                          });
                          _loadData();
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('<'),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedMonth = DateTime.now();
                          });
                          _loadData();
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Today'),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
                          });
                          _loadData();
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('>'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _showHolidaysDialog(context),
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: const Text('View Holidays'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

                // Stats Cards
          Row(
                  children: [
              Expanded(
                child: Card(
                  elevation: 0,
                  color: cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today, color: Colors.blue.shade700, size: 24),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'MONTHLY LEAVES',
                                style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              Text(
                                '$monthlyLeaves',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Card(
                  elevation: 0,
                  color: cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.home, color: Colors.purple.shade700, size: 24),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'WORK FROM HOME',
                                style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              Text(
                                '$workFromHome',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

          // Live Legend
          Card(
            elevation: 0,
            color: cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                const Text(
                    'LIVE LEGEND',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                  _buildLegendItem(Colors.green, 'ACTIVE IN-OFFICE'),
                  const SizedBox(height: 8),
                  _buildLegendItem(Colors.orange, 'PLANNED LEAVE'),
                  const SizedBox(height: 8),
                  _buildLegendItem(Colors.purple, 'REMOTE WFH'),
                  const SizedBox(height: 8),
                  _buildLegendItem(Colors.amber, 'BORROWED DAY'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Calendar Grid
          Card(
            elevation: 0,
            color: cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Day Headers
                  Row(
                    children: ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT']
                        .map((day) => Expanded(
                              child: Center(
                                child: Text(
                                  day,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  // Calendar Days
                  ...List.generate(
                    ((previousMonthDays.length + days.length) / 7).ceil(),
                    (weekIndex) {
                      return Row(
                        children: List.generate(7, (dayIndex) {
                          final cellIndex = weekIndex * 7 + dayIndex;
                          if (cellIndex < previousMonthDays.length) {
                            // Previous month days
                            final day = previousMonthDays[cellIndex];
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      '$day',
                                      maxLines: 1,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade400,
                                        height: 1.2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          } else {
                            final dayIndexInMonth = cellIndex - previousMonthDays.length;
                            if (dayIndexInMonth < days.length) {
                              final day = days[dayIndexInMonth];
                              final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
                              final isToday = date.year == now.year && 
                                            date.month == now.month && 
                                            date.day == now.day;
                              
                              // Check if there's attendance for this day (only approved statuses)
                              final dayAttendance = history.where((attendance) {
                                final checkInDate = attendance.checkInTime;
                                final attendanceDate = attendance.date;
                                // Check both checkInTime and date field
                                bool dateMatches = false;
                                if (checkInDate != null) {
                                  dateMatches = checkInDate.year == date.year &&
                                               checkInDate.month == date.month &&
                                               checkInDate.day == date.day;
                                } else if (attendanceDate != null) {
                                  dateMatches = attendanceDate.year == date.year &&
                                               attendanceDate.month == date.month &&
                                               attendanceDate.day == date.day;
                                }
                                
                                if (!dateMatches) return false;
                                
                                // Only show approved statuses or actual check-in records
                                // If there's a checkInTime, it's an actual attendance record
                                if (checkInDate != null) return true;
                                
                                // For calendar status without check-in, only show if approved
                                // Check if status_approval is 'approved' or null (legacy records)
                                // This will be handled in the model/database
                                return true; // For now, show all - we'll filter by approval status in the service
                              }).toList();
                              
                              // Check if there's a leave application for this day
                              final dayLeaves = userLeaves.where((leave) {
                                if (leave.startDate == null || leave.endDate == null) return false;
                                
                                final isApproved = leave.status.toString().toLowerCase() == 'approved' ||
                                                  leave.status.toString().toLowerCase().contains('approved');
                                if (!isApproved) return false;
                                
                                return !date.isBefore(leave.startDate!) && 
                                       !date.isAfter(leave.endDate!);
                              }).toList();
                              
                              // Determine status based on attendance and leaves
                              String? status;
                              Color? statusColor;
                              IconData? statusIcon;
                              
                              if (dayLeaves.isNotEmpty) {
                                status = 'planned_leave';
                                statusColor = Colors.orange;
                                statusIcon = Icons.event_busy;
                              } else if (dayAttendance.isNotEmpty) {
                                final attendance = dayAttendance.first;
                                if (attendance.workType?.toLowerCase() == 'remote') {
                                  status = 'remote_wfh';
                                  statusColor = Colors.purple;
                                  statusIcon = Icons.home;
                                } else if (attendance.workType?.toLowerCase() == 'in office' || 
                                          attendance.workType?.toLowerCase() == 'hybrid') {
                                  status = 'active_in_office';
                                  statusColor = Colors.green;
                                  statusIcon = Icons.business;
                                } else if (attendance.status?.toLowerCase() == 'on leave') {
                                  status = 'planned_leave';
                                  statusColor = Colors.orange;
                                  statusIcon = Icons.event_busy;
                                }
                              }

                              return Expanded(
                                child: InkWell(
                                  onTap: () {
                                    // Removed - calendar now syncs with leave applications
                                    // No direct date clicking for status changes
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.all(2),
                                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                                    decoration: BoxDecoration(
                                      color: isToday ? Colors.blue.shade100 : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      border: isToday ? Border.all(color: Colors.blue.shade700, width: 2) : null,
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (statusIcon != null && dayAttendance.isNotEmpty)
                                          Container(
                                            margin: const EdgeInsets.only(bottom: 2),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (dayAttendance.length > 1)
                                                  Text(
                                                    '${dayAttendance.length}',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.bold,
                                                      color: statusColor ?? Colors.purple.shade700,
                                                    ),
                                                  ),
                                                Icon(
                                                  statusIcon!,
                                                  size: 12,
                                                  color: statusColor ?? Colors.purple.shade700,
                                                ),
                                              ],
                                            ),
                                          ),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            '$day',
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                              color: isToday ? Colors.blue.shade700 : textColor,
                                              height: 1.2,
                                            ),
                                          ),
                                        ),
                                        if (statusIcon != null && dayAttendance.isEmpty && dayLeaves.isNotEmpty)
                                          Container(
                                            margin: const EdgeInsets.only(top: 2),
                                            child: Icon(
                                              statusIcon!,
                                              size: 12,
                                              color: statusColor ?? Colors.orange,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            } else {
                              // Next month days
                              final day = cellIndex - previousMonthDays.length - days.length + 1;
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(2),
                                  child: Center(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        '$day',
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade400,
                                          height: 1.2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }
                          }
                        }),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildHistoryTab(BuildContext context, List<Attendance> history, Color cardColor, Color textColor, bool isDark) {
    // Filter history by date range
    final filteredHistory = history.where((attendance) {
      // Use date field if checkInTime is null (for planned/future dates)
      final attendanceDate = attendance.checkInTime ?? attendance.date;
      if (attendanceDate == null) return false;
      
      final startDate = DateTime(_selectedStartDate.year, _selectedStartDate.month, _selectedStartDate.day);
      final endDate = DateTime(_selectedEndDate.year, _selectedEndDate.month, _selectedEndDate.day, 23, 59, 59);
      
      return !attendanceDate.isBefore(startDate) && !attendanceDate.isAfter(endDate);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            'Attendance Log',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Date Range Picker
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedStartDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedStartDate = DateTime(picked.year, picked.month, picked.day);
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(DateFormat('dd-MM-yyyy').format(_selectedStartDate)),
                        const Icon(Icons.calendar_today, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('to', style: TextStyle(color: Colors.grey.shade600)),
              ),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedEndDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedEndDate = DateTime(picked.year, picked.month, picked.day);
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(DateFormat('dd-MM-yyyy').format(_selectedEndDate)),
                        const Icon(Icons.calendar_today, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Attendance List
          if (filteredHistory.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  children: [
                    Icon(Icons.history, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'No attendance records found',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            )
          else
            ...filteredHistory.reversed.map((attendance) {
              // Use date field if checkInTime is null
              final checkInDate = attendance.checkInTime ?? attendance.date;
              if (checkInDate == null) return const SizedBox.shrink();
              
              // Check work_type from attendance record
              final workType = attendance.workType?.toLowerCase();
              final isRemote = workType == 'remote' || workType == 'hybrid';
              final isInOffice = workType == 'in office';
              final status = attendance.status ?? 
                            (attendance.checkOutTime != null ? 'Present' : 
                             (attendance.checkInTime != null ? 'Incomplete' : 'Absent'));
              final checkInTime = attendance.checkInTime;
              final checkOutTime = attendance.checkOutTime;
              final workedHours = checkOutTime != null && checkInTime != null
                  ? checkOutTime.difference(checkInTime).inHours + 
                    (checkOutTime.difference(checkInTime).inMinutes % 60) / 60.0
                  : null;

                    return Card(
                margin: const EdgeInsets.only(bottom: 12),
                      elevation: 0,
                      color: cardColor,
                      shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1)),
                      ),
                      child: Padding(
                  padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                          Text(
                            DateFormat('MMM dd').format(checkInDate).toUpperCase(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                              color: status == 'Present' ? Colors.green.shade50 : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                              status,
                                    style: TextStyle(
                                fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                color: status == 'Present' ? Colors.green.shade700 : Colors.orange.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                      const SizedBox(height: 8),
                          Row(
                            children: [
                              if (isRemote)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Remote',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.purple.shade700,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              if (isInOffice) ...[
                                if (isRemote) const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'In Office',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                              if (attendance.status?.toLowerCase().contains('leave') == true) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Leave Conflict',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.orange.shade700,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                              const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Check In',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  checkInTime != null ? DateFormat('HH:mm').format(checkInTime) : '--:--',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Check Out',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  checkOutTime != null ? DateFormat('HH:mm').format(checkOutTime) : '--:--',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (workedHours != null)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Hours',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${workedHours.toStringAsFixed(2)} hrs',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
        ],
                      ),
                    );
                  }

  Future<void> _showHolidaysDialog(BuildContext context) async {
    try {
      final authProvider = context.read<AuthProvider>();
      final user = authProvider.user;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please login to view holidays'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Get user profile to fetch organization_id
      final userProfile = await supabase
          .from('user_profiles')
          .select('organization_id')
          .eq('user_id', user.id)
          .maybeSingle();

      final organizationId = userProfile?['organization_id'] as String?;
      if (organizationId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Organization not found'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final currentYear = DateTime.now().year;

      // Fetch holiday calendar documents from Supabase
      final holidayDocs = await supabase
          .from('holiday_calendar_documents')
          .select()
          .eq('organization_id', organizationId)
          .order('year', ascending: false);

      final documents = (holidayDocs as List).map((doc) => {
        'id': doc['id'] as String?,
        'year': doc['year'] as int? ?? currentYear,
        'file_path': doc['file_path'] as String? ?? '',
        'file_type': doc['file_type'] as String? ?? 'image',
        'created_at': doc['created_at'] as String?,
      }).toList();

      if (!mounted) return;

      if (documents.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No holiday calendar uploaded for this organization'),
          ),
        );
        return;
      }

      // Prefer current year document, otherwise use most recent
      Map<String, dynamic> doc = documents.first;
      for (final d in documents) {
        if ((d['year'] as int?) == currentYear) {
          doc = d;
          break;
        }
      }

      final year = doc['year'] as int? ?? currentYear;
      final filePath = doc['file_path'] as String? ?? '';
      final fileType = doc['file_type'] as String? ?? 'image';

      // Show the holiday calendar image dialog
      await _showHolidayImageDialog(context, filePath, fileType, year);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load holidays: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showHolidayImageDialog(BuildContext context, String filePath, String fileType, int year) async {
    try {
      // Get public URL from Supabase storage
      String imageUrl = '';
      String? signedUrl;
      
      // If file_path is already a full URL, use it directly
      if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
        imageUrl = filePath;
      } else {
        // Extract bucket and file path from the stored path
        // Path format: organization_id/year/filename.jpg
        final parts = filePath.split('/');
        
        // Try different bucket names - common ones for holiday calendars
        final possibleBuckets = ['holiday-calendars', 'holidays', 'documents', 'holiday_calendars'];
        
        bool urlFound = false;
        
        for (final bucket in possibleBuckets) {
          try {
            // Try with full path
            final url1 = supabase.storage.from(bucket).getPublicUrl(filePath);
            
            // Also try with path without first part (if first part is organization_id)
            String url2 = '';
            if (parts.length > 1) {
              final filePathInBucket = parts.sublist(1).join('/');
              url2 = supabase.storage.from(bucket).getPublicUrl(filePathInBucket);
            }
            
            // Use the first valid URL
            if (url1.isNotEmpty && url1.startsWith('http')) {
              imageUrl = url1;
              urlFound = true;
              print('Found URL with bucket $bucket and full path: $imageUrl');
              break;
            } else if (url2.isNotEmpty && url2.startsWith('http')) {
              imageUrl = url2;
              urlFound = true;
              print('Found URL with bucket $bucket and partial path: $imageUrl');
              break;
            }
          } catch (e) {
            print('Error trying bucket $bucket: $e');
            continue;
          }
        }
        
        // If still not found, try using first part as bucket name
        if (!urlFound && parts.length > 1) {
          try {
            final bucketName = parts[0];
            final filePathInBucket = parts.sublist(1).join('/');
            imageUrl = supabase.storage.from(bucketName).getPublicUrl(filePathInBucket);
            print('Trying first part as bucket: $bucketName, path: $filePathInBucket, URL: $imageUrl');
          } catch (e) {
            print('Error with first part as bucket: $e');
            // Last fallback: use full path with most common bucket
            imageUrl = supabase.storage.from('holiday-calendars').getPublicUrl(filePath);
          }
        } else if (!urlFound) {
          // Single part path - use with default bucket
          imageUrl = supabase.storage.from('holiday-calendars').getPublicUrl(filePath);
        }
        
        // Try to get signed URL as fallback (for private buckets)
        try {
          if (parts.length > 1) {
            final possibleBucketsForSigned = ['holiday-calendars', 'holidays', 'documents'];
            for (final bucket in possibleBucketsForSigned) {
              try {
                final filePathInBucket = parts.sublist(1).join('/');
                signedUrl = await supabase.storage.from(bucket).createSignedUrl(filePathInBucket, 3600);
                print('Created signed URL for bucket $bucket: $signedUrl');
                break;
              } catch (e) {
                continue;
              }
            }
          }
        } catch (e) {
          print('Error creating signed URL: $e');
        }
      }
      
      print('Holiday image URL: $imageUrl');
      print('File path: $filePath');
      print('File type: $fileType');
      if (signedUrl != null) {
        print('Signed URL: $signedUrl');
      }

      if (!mounted) return;
      
      if (imageUrl.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to construct image URL for: $filePath'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Show full screen image dialog
      showDialog(
        context: context,
        barrierColor: Colors.black87,
        builder: (context) => Scaffold(
          backgroundColor: Colors.black87,
          body: SafeArea(
            child: Column(
       children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
         Text(
                        'Holiday Calendar $year',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                // Image
                Expanded(
                  child: Center(
                    child: fileType.toLowerCase() == 'pdf'
                      ? Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.picture_as_pdf, size: 64, color: Colors.red.shade700),
                              const SizedBox(height: 16),
                              const Text('PDF files cannot be displayed inline'),
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: () {
                                  // Open PDF in external app
                                  // You can use url_launcher here
                                  Navigator.pop(context); // Close dialog first
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Opening PDF: $imageUrl'),
                                    ),
                                  );
                                },
                                child: const Text('Open PDF'),
                              ),
                            ],
                          ),
                        )
                      : _HolidayImageViewer(
                          imageUrl: imageUrl,
                          signedUrl: signedUrl,
                          filePath: filePath,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      // Don't show snackbar here - the error will be displayed in the image error builder
      // Using context after async operations can cause issues if widget is disposed
      print('Error showing holiday image dialog: $e');
      if (mounted) {
        // Only show snackbar if widget is still mounted and we have a valid context
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load image: $e'),
              backgroundColor: Colors.red,
            ),
          );
        } catch (contextError) {
          // Context is invalid, just log the error
          print('Cannot show snackbar - context invalid: $contextError');
        }
      }
    }
  }
}

// Widget to handle image loading with fallback to signed URL
class _HolidayImageViewer extends StatefulWidget {
  final String imageUrl;
  final String? signedUrl;
  final String filePath;

  const _HolidayImageViewer({
    required this.imageUrl,
    this.signedUrl,
    required this.filePath,
  });

  @override
  State<_HolidayImageViewer> createState() => _HolidayImageViewerState();
}

class _HolidayImageViewerState extends State<_HolidayImageViewer> {
  String? _currentUrl;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.imageUrl;
  }

  void _trySignedUrl() {
    if (widget.signedUrl != null && _currentUrl != widget.signedUrl) {
      setState(() {
        _currentUrl = widget.signedUrl;
        _hasError = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      child: Image.network(
        _currentUrl!,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          // Try signed URL if available
          if (!_hasError && widget.signedUrl != null && _currentUrl == widget.imageUrl) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _trySignedUrl();
            });
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // Mark that we've already handled the error, but do it after this frame
          if (!_hasError) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _hasError = true;
                });
              }
            });
          }

          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red.shade700),
                const SizedBox(height: 16),
                const Text('Failed to load image'),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    widget.filePath,
                    style: const TextStyle(fontSize: 10),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'URL: ${_currentUrl?.substring(0, _currentUrl!.length > 50 ? 50 : _currentUrl!.length)}...',
                  style: const TextStyle(fontSize: 10),
                  textAlign: TextAlign.center,
                ),
                if (widget.signedUrl != null && _currentUrl == widget.imageUrl) ...[
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _trySignedUrl,
                    child: const Text('Try Alternative URL'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
     );
  }
}

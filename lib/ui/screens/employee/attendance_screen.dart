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
import 'package:loghr_mobile/config/api_client.dart';

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
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        leading: widget.onNavigateToDashboard != null
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: textColor),
                onPressed: widget.onNavigateToDashboard,
              )
            : null,
        title: Text(
          'Attendance',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: cardColor,
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.blue.shade700,
              unselectedLabelColor: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
              indicatorColor: Colors.blue.shade700,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
              tabs: const [
                Tab(text: 'Check In/Out'),
                Tab(text: 'My Calendar'),
                Tab(text: 'My History'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCheckInOutTab(context, attendanceProvider, todayAttendance, isCheckedIn, cardColor, textColor, isDark),
          _buildCalendarTab(context, history, cardColor, textColor, isDark),
          _buildHistoryTab(context, history, cardColor, textColor, isDark),
        ],
      ),
    );
  }

  Widget _buildCheckInOutTab(BuildContext context, AttendanceProvider attendanceProvider, 
      Attendance? todayAttendance, bool isCheckedIn, Color cardColor, Color textColor, bool isDark) {
    final dayFormat = DateFormat('EEEE, MMMM d').format(_currentTime).toUpperCase();
    
    // Get working duration for the clock
    Duration workingDuration = Duration.zero;
    if (todayAttendance != null && todayAttendance.checkInTime != null) {
      final endTime = todayAttendance.checkOutTime ?? DateTime.now();
      workingDuration = endTime.difference(todayAttendance.checkInTime!);
    }
    
    // Format workingDuration as HH:mm:ss
    String hours = workingDuration.inHours.toString().padLeft(2, '0');
    String minutes = (workingDuration.inMinutes % 60).toString().padLeft(2, '0');
    String seconds = (workingDuration.inSeconds % 60).toString().padLeft(2, '0');
    final timeFormat = "$hours:$minutes:$seconds";
    
    // Calculate progress (8 hours baseline)
    double progress = 0;
    int workedMinutes = 0;
    if (todayAttendance != null && todayAttendance.checkInTime != null) {
      final endTime = todayAttendance.checkOutTime ?? DateTime.now();
      workedMinutes = endTime.difference(todayAttendance.checkInTime!).inMinutes;
      progress = (workedMinutes / (8 * 60)).clamp(0.0, 1.0);
    }
    final int percentage = (progress * 100).toInt();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          // Header Section: Date and Time
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            width: double.infinity,
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.01),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  dayFormat,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.grey.shade400 : const Color(0xFF666666),
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timeFormat,
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: Colors.blue.shade700,
                    letterSpacing: -1.2,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Circular Progress Button Section
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Progress Arc
                    SizedBox(
                      width: 130,
                      height: 130,
                      child: CustomPaint(
                        painter: ProgressArc(
                          progress: progress,
                          arcColor: Colors.blue.shade600,
                          unfilledColor: isDark ? Colors.blue.shade900.withOpacity(0.3) : Colors.blue.shade50,
                        ),
                      ),
                    ),
                    
                    // Main Action Button
                    InkWell(
                      onTap: attendanceProvider.isLoading ? null : (isCheckedIn ? _handleCheckOut : _handleCheckIn),
                      borderRadius: BorderRadius.circular(100),
                      child: Container(
                        width: 105,
                        height: 105,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Colors.orange.shade400, Colors.orange.shade600],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.shade300.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isCheckedIn ? Icons.logout_rounded : Icons.login_rounded,
                              size: 28,
                              color: Colors.white,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isCheckedIn ? 'Check Out' : 'Check In',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              isCheckedIn ? 'End Day' : 'Start Day',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$percentage%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$percentage% of today done',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Overtime Button Section
          if (isCheckedIn && todayAttendance != null && todayAttendance.checkInTime != null) ...[
            Builder(builder: (context) {
              final workedHours = DateTime.now().difference(todayAttendance.checkInTime!).inHours;
              final workedMins = DateTime.now().difference(todayAttendance.checkInTime!).inMinutes;
              final hasCompleted8 = workedHours >= 8;
              final isOT = attendanceProvider.isOvertimeActive;

              if (hasCompleted8 && !isOT) {
                // Show "Start Overtime" button
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        attendanceProvider.activateOvertime();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Overtime activated! You can work for up to 4 more hours.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.orange.shade500, Colors.deepOrange.shade400],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.more_time_rounded, color: Colors.white, size: 22),
                            const SizedBox(width: 10),
                            const Text(
                              'Start Overtime',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '(max 4 hrs)',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              } else if (isOT) {
                // Show "Overtime Active" indicator with remaining time
                final maxEnd = todayAttendance.checkInTime!.add(const Duration(hours: 12));
                final remainingMins = maxEnd.difference(DateTime.now()).inMinutes.clamp(0, 240);
                final remainH = remainingMins ~/ 60;
                final remainM = remainingMins % 60;

                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green.shade300, width: 1.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.timer_outlined, color: Colors.green.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Overtime Active',
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${remainH}h ${remainM}m left',
                          style: TextStyle(
                            color: Colors.green.shade900,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return const SizedBox.shrink();
            }),
          ],
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Today's Summary",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSummaryItem(
                            icon: Icons.check_circle_outline,
                            label: 'Check in:',
                            value: todayAttendance?.checkInTime != null 
                                ? DateFormat('h:mm a').format(todayAttendance!.checkInTime!) 
                                : '--:--',
                            isDark: isDark,
                          ),
                          const SizedBox(height: 4),
                          _buildSummaryItem(
                            icon: Icons.task_alt,
                            label: 'Status:',
                            value: isCheckedIn ? 'On Time' : (todayAttendance?.checkOutTime != null ? 'Done' : 'N/A'),
                            valueColor: isCheckedIn ? Colors.green.shade600 : (isDark ? Colors.grey.shade400 : Colors.grey),
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSummaryItem(
                            icon: Icons.access_time,
                            label: 'Worked:',
                            value: Helpers.formatDuration(Duration(minutes: workedMinutes)),
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Weekly Progress Section
          Container(
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Weekly Progress",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 24),
                _buildWeeklyBarChart(attendanceProvider.history, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 16,
            child: Icon(icon, size: 13, color: Colors.blue.shade600),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11, 
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade700, 
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: valueColor ?? (isDark ? Colors.white : const Color(0xFF333333)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyBarChart(List<Attendance> history, bool isDark) {
    final List<String> weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    
    // Extract hours worked for each day of the current week
    final Map<int, double> dailyHours = {};
    for (int i = 0; i < 7; i++) {
        final day = DateTime(monday.year, monday.month, monday.day).add(Duration(days: i));
        final attendance = history.firstWhere(
            (a) => a.checkInTime != null && 
                  a.checkInTime!.year == day.year && 
                  a.checkInTime!.month == day.month && 
                  a.checkInTime!.day == day.day,
            orElse: () => Attendance(id: '', employeeId: '', date: day),
        );
        
        double hours = 0;
        if (attendance.checkInTime != null && attendance.checkOutTime != null) {
            hours = attendance.checkOutTime!.difference(attendance.checkInTime!).inMinutes / 60.0;
        } else if (attendance.checkInTime != null && day.day == now.day) {
            hours = DateTime.now().difference(attendance.checkInTime!).inMinutes / 60.0;
        }
        dailyHours[i] = hours;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (index) {
          final double hours = dailyHours[index] ?? 0;
          final bool isToday = index == (now.weekday - 1);
          final double barHeight = (hours / 12).clamp(0.0, 1.0) * 100 + 40; // Max 12 hours visual baseline
          
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: barHeight,
                  decoration: BoxDecoration(
                    color: isToday ? Colors.blue.shade400 : (isDark ? Colors.blue.shade900.withOpacity(0.2) : Colors.blue.shade100.withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(8),
                    border: isToday ? Border.all(color: Colors.blue.shade700, width: 2) : null,
                  ),
                  child: Center(
                    child: Text(
                      "${hours.toStringAsFixed(1)}h",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isToday ? Colors.white : Colors.blue.shade800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  weekDays[index],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                    color: isToday ? Colors.blue.shade700 : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          );
        }),
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
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
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
                                style: TextStyle(fontSize: 9, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
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
                                style: TextStyle(fontSize: 9, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
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
                Text(
                    'LIVE LEGEND',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
                ),
                const SizedBox(height: 12),
                  _buildLegendItem(Colors.green, 'ACTIVE IN-OFFICE', isDark),
                  const SizedBox(height: 8),
                  _buildLegendItem(Colors.orange, 'PLANNED LEAVE', isDark),
                  const SizedBox(height: 8),
                  _buildLegendItem(Colors.purple, 'REMOTE WFH', isDark),
                  const SizedBox(height: 8),
                  _buildLegendItem(Colors.amber, 'BORROWED DAY', isDark),
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
                                      color: isToday ? (isDark ? Colors.blue.shade900.withOpacity(0.3) : Colors.blue.shade100) : Colors.transparent,
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

  Widget _buildLegendItem(Color color, String label, bool isDark) {
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
          style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.black87),
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
          Text(
            'Attendance Log',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
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
              final isRemote = workType == 'remote';
              final isHybrid = workType == 'hybrid';
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
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: status == 'Present' ? (isDark ? Colors.green.shade900.withOpacity(0.2) : Colors.green.shade50) : (isDark ? Colors.orange.shade900.withOpacity(0.2) : Colors.orange.shade50),
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
                                    color: isDark ? Colors.purple.shade900.withOpacity(0.3) : Colors.purple.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Remote',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark ? Colors.purple.shade300 : Colors.purple.shade700,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              if (isHybrid) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.indigo.shade900.withOpacity(0.3) : Colors.indigo.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Hybrid',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark ? Colors.indigo.shade300 : Colors.indigo.shade700,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                              if (isInOffice) ...[
                                if (isRemote || isHybrid) const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.green.shade900.withOpacity(0.3) : Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'In Office',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark ? Colors.green.shade300 : Colors.green.shade700,
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

      // Fetch holiday calendar documents from custom API
      final holidayDocs = await api.get('/misc/holiday-calendar');
      
      final currentYear = DateTime.now().year;
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
      String imageUrl = filePath;
      
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
                      : InteractiveViewer(
                          child: Image.network(
                            imageUrl,
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
                                    const Text('Failed to load image', style: TextStyle(color: Colors.black)),
                                    const SizedBox(height: 8),
                                    Text(
                                      filePath,
                                      style: const TextStyle(fontSize: 10, color: Colors.black54),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      print('Error showing holiday image dialog: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class ProgressArc extends CustomPainter {
  final double progress;
  final Color arcColor;
  final Color unfilledColor;

  ProgressArc({
    required this.progress,
    required this.arcColor,
    required this.unfilledColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = 12.0;

    final basePaint = Paint()
      ..color = unfilledColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = arcColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Draw background arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      0.8 * 3.14159, // Start angle
      1.4 * 3.14159, // Sweep angle
      false,
      basePaint,
    );

    // Draw progress arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      0.8 * 3.14159,
      progress * 1.4 * 3.14159,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

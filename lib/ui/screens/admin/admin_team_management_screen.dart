import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:loghr_mobile/logic/admin_provider.dart';
import 'package:loghr_mobile/data/services/admin_service.dart';

class AdminTeamManagementScreen extends StatefulWidget {
  const AdminTeamManagementScreen({super.key});

  @override
  State<AdminTeamManagementScreen> createState() => _AdminTeamManagementScreenState();
}

class _AdminTeamManagementScreenState extends State<AdminTeamManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AdminService _adminService = AdminService();
  DateTime _selectedDate = DateTime.now();
  late ScrollController _calendarController;
  List<Map<String, dynamic>> _attendanceRecords = [];
  bool _isAttendanceLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _calendarController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().loadLeaveDashboardData();
      _loadAttendance();
    });
  }

  Future<void> _loadAttendance() async {
    setState(() => _isAttendanceLoading = true);
    try {
      final records = await _adminService.getAllAttendance(date: _selectedDate);
      if (mounted) {
        setState(() {
          _attendanceRecords = records;
          _isAttendanceLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAttendanceLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _calendarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<AdminProvider>();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey.shade50,
      appBar: _buildAppBar(isDark),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCalendarSection(isDark),
          const SizedBox(height: 24),
          _buildTabSwitcher(isDark),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAttendanceList(isDark),
                _buildRequestsList('pending', provider, isDark),
                _buildRequestsList('approved', provider, isDark),
                _buildRequestsList('history', provider, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.calendar_month, color: Color(0xFF1565C0), size: 24),
          ),
          const SizedBox(width: 12),
          Text(
            'LogHR',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () {},
          icon: Icon(Icons.search, color: isDark ? Colors.white : Colors.black87),
        ),
        Stack(
          children: [
            IconButton(
              onPressed: () {},
              icon: Icon(Icons.notifications_outlined, color: isDark ? Colors.white : Colors.black87),
            ),
            Positioned(
              right: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                child: const Text('2', style: TextStyle(color: Colors.white, fontSize: 8)),
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildCalendarSection(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Team Attendance',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                DateFormat('MMMM yyyy').format(_selectedDate),
                style: const TextStyle(color: Color(0xFF1565C0), fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 90,
            child: ListView.builder(
              controller: _calendarController,
              scrollDirection: Axis.horizontal,
              itemCount: 30, // Mock days
              itemBuilder: (context, index) {
                final date = DateTime.now().add(Duration(days: index - 2));
                final isSelected = date.day == _selectedDate.day && 
                                  date.month == _selectedDate.month && 
                                  date.year == _selectedDate.year;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedDate = date);
                    _loadAttendance();
                  },
                  child: _buildCalendarDay(date, isSelected, isDark),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          _buildDepartmentLegend(isDark),
        ],
      ),
    );
  }

  Widget _buildCalendarDay(DateTime date, bool isSelected, bool isDark) {
    return Container(
      width: 55,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF1565C0) : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
        borderRadius: BorderRadius.circular(16),
        boxShadow: isSelected ? [
          BoxShadow(
            color: const Color(0xFF1565C0).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ] : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            DateFormat('E').format(date).toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              color: isSelected ? Colors.white70 : Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            date.day.toString(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
            ),
          ),
          const SizedBox(height: 6),
          _buildStatusDots(isSelected),
        ],
      ),
    );
  }

  Widget _buildStatusDots(bool isSelected) {
    if (isSelected) {
      return Container(
        height: 4,
        width: 4,
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(height: 4, width: 4, decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle)),
        const SizedBox(width: 2),
        Container(height: 4, width: 4, decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle)),
        const SizedBox(width: 2),
        Container(height: 4, width: 4, decoration: const BoxDecoration(color: Colors.purple, shape: BoxShape.circle)),
      ],
    );
  }

  Widget _buildDepartmentLegend(bool isDark) {
    final provider = context.watch<AdminProvider>();
    final designations = provider.designations;
    
    // Fallback if no designations are loaded yet
    if (designations.isEmpty) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLegendItem('All Teams', Colors.blue),
        ],
      );
    }

    final colors = [
      Colors.blue, 
      Colors.green, 
      Colors.orange, 
      Colors.purple, 
      Colors.red, 
      Colors.teal,
      Colors.indigo,
      Colors.amber,
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(designations.length, (index) {
          return Padding(
            padding: EdgeInsets.only(
              left: index == 0 ? 0 : 12,
              right: index == designations.length - 1 ? 0 : 0,
            ),
            child: _buildLegendItem(designations[index], colors[index % colors.length]),
          );
        }),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(height: 6, width: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildTabSwitcher(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 45,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          labelColor: const Color(0xFF1565C0),
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'Attendance'),
            Tab(text: 'Pending (3)'),
            Tab(text: 'Approved'),
            Tab(text: 'History'),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsList(String type, AdminProvider provider, bool isDark) {
    // Mock data for demo since loadLeaveDashboardData might be async and loading
    final requests = [
      {
        'name': 'Alex Rivera',
        'type': 'Annual Leave',
        'date': 'Oct 14 - Oct 16',
        'note': 'Attending a family wedding.',
        'dept': 'TECH',
        'avatar': 'AR',
      },
      {
        'name': 'Sarah Jenkins',
        'type': 'Sick Leave',
        'date': 'Today, Oct 13',
        'duration': '1 Day',
        'note': 'Sudden viral fever since morning.',
        'dept': 'MARKETING',
        'avatar': 'SJ',
      },
      {
        'name': 'Michael Chen',
        'type': 'Personal Time',
        'date': 'Oct 18 - Oct 19',
        'duration': '2 Days',
        'note': 'No note provided',
        'dept': 'DESIGN',
        'avatar': 'MC',
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        return _buildSwipableCard(requests[index], isDark);
      },
    );
  }

  Widget _buildSwipableCard(Map<String, dynamic> request, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Dismissible(
            key: Key(request['name']),
            background: _buildSwipeAction(true),
            secondaryBackground: _buildSwipeAction(false),
            onDismissed: (direction) {
              // Handle approve/reject
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.blue.shade100,
                        child: Text(request['avatar'], style: const TextStyle(color: Color(0xFF1565C0))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              request['name'],
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87),
                            ),
                            Text(
                              request['type'],
                              style: const TextStyle(color: Color(0xFF1565C0), fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      if (request['dept'] != null)
                        Text(
                          request['dept'],
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade400, letterSpacing: 1),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          request['date'],
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (request['duration'] != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(8)),
                          child: Text(request['duration'], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '"${request['note']}"',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (request['name'] == 'Michael Chen') // Mocking the swipe tutorial at the bottom
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    const Icon(Icons.swipe, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Swipe cards to Approve or Reject',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.close, color: Colors.white70, size: 12),
                    const SizedBox(width: 8),
                    const Icon(Icons.check, color: Colors.greenAccent, size: 16),
                    const Text(' Approve', style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSwipeAction(bool isApprove) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: isApprove ? Alignment.centerLeft : Alignment.centerRight,
      color: isApprove ? Colors.teal : Colors.redAccent,
      child: Icon(isApprove ? Icons.check : Icons.close, color: Colors.white, size: 32),
    );
  }

  Widget _buildAttendanceList(bool isDark) {
    if (_isAttendanceLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_attendanceRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No records for ${DateFormat('EEE, MMM d').format(_selectedDate)}',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _attendanceRecords.length,
      itemBuilder: (context, index) {
        final record = _attendanceRecords[index];
        return _buildAttendanceCard(record, isDark);
      },
    );
  }

  Widget _buildAttendanceCard(Map<String, dynamic> record, bool isDark) {
    final profile = record['user_profiles'] as Map<String, dynamic>?;
    final name = profile?['full_name'] ?? 'Unknown Employee';
    final avatarText = name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();
    
    final checkIn = record['check_in_time'] != null 
        ? DateFormat('hh:mm a').format(DateTime.parse(record['check_in_time'])) 
        : '--:--';
    final checkOut = record['check_out_time'] != null 
        ? DateFormat('hh:mm a').format(DateTime.parse(record['check_out_time'])) 
        : 'Still In';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue.shade50,
            child: Text(avatarText, style: const TextStyle(color: Color(0xFF1565C0), fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.login, size: 12, color: Colors.green.shade400),
                    const SizedBox(width: 4),
                    Text(checkIn, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(width: 12),
                    Icon(Icons.logout, size: 12, color: Colors.orange.shade400),
                    const SizedBox(width: 4),
                    Text(checkOut, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ],
            ),
          ),
          if (record['status'] != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (record['status'] == 'PRESENT') ? Colors.green.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                record['status'],
                style: TextStyle(
                  color: (record['status'] == 'PRESENT') ? Colors.green.shade700 : Colors.orange.shade700,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

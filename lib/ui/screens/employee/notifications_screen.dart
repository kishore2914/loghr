import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:loghr_mobile/data/models/notification.dart' as models;
import 'package:loghr_mobile/logic/notification_provider.dart';
import 'package:loghr_mobile/logic/auth_provider.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';
  String _selectedType = 'All Types';
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNotifications();
    });
  }

  void _loadNotifications() {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;
    if (user != null) {
      context.read<NotificationProvider>().loadNotifications(user.id);
    }
  }

  List<models.AppNotification> get _filteredNotifications {
    final notificationProvider = context.watch<NotificationProvider>();
    var filtered = notificationProvider.notifications;

    // Filter by search
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((notification) {
        return notification.title.toLowerCase().contains(query) ||
            notification.message.toLowerCase().contains(query);
      }).toList();
    }

    // Filter by type
    if (_selectedType != 'All Types') {
      filtered = filtered.where((notification) {
        return notification.type == _selectedType;
      }).toList();
    }

    // Filter by date range
    if (_fromDate != null) {
      filtered = filtered.where((notification) {
        return notification.date.isAfter(_fromDate!.subtract(const Duration(days: 1))) ||
            notification.date.isAtSameMomentAs(_fromDate!);
      }).toList();
    }

    if (_toDate != null) {
      filtered = filtered.where((notification) {
        return notification.date.isBefore(_toDate!.add(const Duration(days: 1))) ||
            notification.date.isAtSameMomentAs(_toDate!);
      }).toList();
    }

    // Filter by read status
    if (_selectedFilter == 'Unread') {
      filtered = filtered.where((notification) => !notification.isRead).toList();
    } else if (_selectedFilter == 'Read') {
      filtered = filtered.where((notification) => notification.isRead).toList();
    }

    return filtered;
  }

  int get _unreadCount {
    final notificationProvider = context.watch<NotificationProvider>();
    return notificationProvider.unreadCount;
  }

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFromDate ? (_fromDate ?? DateTime.now()) : (_toDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.blue,
            colorScheme: ColorScheme.light(primary: Colors.blue.shade700),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isFromDate) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F1724);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header Section
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notifications',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Stay on top of updates',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      if (_unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.red.shade100),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.notifications_active, size: 14, color: Colors.red.shade700),
                              const SizedBox(width: 4),
                              Text(
                                '$_unreadCount',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Filters
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 600;
                      if (isMobile) {
                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(child: _buildDropdown(_selectedFilter, ['All', 'Unread', 'Read'], (val) => setState(() => _selectedFilter = val!), isDark)),
                                const SizedBox(width: 12),
                                Expanded(flex: 2, child: _buildSearchField(isDark)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(child: _buildDropdown(_selectedType, [
                                  'All Types', 'SYSTEM', 'HR', 'LEAVE', 'ATTENDANCE', 'ANNOUNCEMENT', 'TASK'
                                ], (val) => setState(() => _selectedType = val!), isDark)),
                              ],
                            ),
                             const SizedBox(height: 12),
                             Row(
                               children: [
                                  Expanded(child: _buildDateButton('From: ', _fromDate, () => _selectDate(context, true), isDark)),
                                  const SizedBox(width: 12),
                                  Expanded(child: _buildDateButton('To: ', _toDate, () => _selectDate(context, false), isDark)),
                               ],
                             )
                          ],
                        );
                      } else {
                         return Row(
                           children: [
                              Expanded(flex: 2, child: _buildSearchField(isDark)),
                              const SizedBox(width: 12),
                              Expanded(child: _buildDropdown(_selectedFilter, ['All', 'Unread', 'Read'], (val) => setState(() => _selectedFilter = val!), isDark)),
                           ],
                         );
                      }
                    },
                  ),
                ],
              ),
            ),

            // Notifications List
            Expanded(
              child: Consumer<NotificationProvider>(
                builder: (context, notificationProvider, child) {
                  if (notificationProvider.isLoading && _filteredNotifications.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (_filteredNotifications.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_none, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text(
                            'No notifications',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      _loadNotifications();
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _filteredNotifications.length,
                      itemBuilder: (context, index) {
                        final notification = _filteredNotifications[index];
                        return _buildNotificationCard(notification, isDark);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200),
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black),
        decoration: InputDecoration(
          hintText: 'Search',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade400, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildDropdown(String value, List<String> items, ValueChanged<String?> onChanged, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade400, size: 20),
          style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F1724)),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildDateButton(String label, DateTime? date, VoidCallback onTap, bool isDark) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade400),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  date != null ? DateFormat('dd/MM').format(date) : label,
                   style: TextStyle(
                    fontSize: 13,
                     color: date != null ? (isDark ? Colors.white : const Color(0xFF0F1724)) : Colors.grey.shade400,
                   ),
                   overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
  }

  Widget _buildNotificationCard(models.AppNotification notification, bool isDark) {
    final notificationProvider = context.read<NotificationProvider>();
    
    return InkWell(
      onTap: () {
        if (!notification.isRead) {
          notificationProvider.markAsRead(notification.id);
        }
      },
      child: _buildNotificationCardContent(notification, isDark),
    );
  }

  Widget _buildNotificationCardContent(models.AppNotification notification, bool isDark) {
    final dateFormat = DateFormat('MMM dd • hh:mm a');
    final formattedDate = dateFormat.format(notification.date);

    Color typeColor;
    IconData typeIcon;
    switch (notification.type.toUpperCase()) {
      case 'SYSTEM':
        typeColor = Colors.grey.shade700;
        typeIcon = Icons.settings;
        break;
      case 'HR':
        typeColor = Colors.purple.shade700;
        typeIcon = Icons.person;
        break;
      case 'LEAVE':
        typeColor = Colors.green.shade700;
        typeIcon = Icons.event_available;
        break;
      case 'ATTENDANCE':
        typeColor = Colors.orange.shade700;
        typeIcon = Icons.access_time;
        break;
      case 'ANNOUNCEMENT':
        typeColor = Colors.blue.shade700;
        typeIcon = Icons.campaign;
        break;
      case 'TASK':
        typeColor = Colors.indigo.shade700;
        typeIcon = Icons.assignment;
        break;
      default:
        typeColor = Colors.blue.shade700;
        typeIcon = Icons.notifications;
    }

    final cardColor = notification.isRead 
        ? (isDark ? const Color(0xFF1E1E1E) : Colors.white)
        : (isDark ? Colors.blue.withOpacity(0.1) : Colors.blue.shade50.withOpacity(0.3));

    final borderColor = notification.isRead
        ? (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200)
        : Colors.blue.shade100;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
       shadowColor: Colors.black.withOpacity(0.05),
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: borderColor,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: typeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(typeIcon, color: typeColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F1724),
                          ),
                        ),
                      ),
                      if (!notification.isRead)
                         Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

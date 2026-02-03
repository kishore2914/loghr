import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CalendarScreen extends StatefulWidget {
  final VoidCallback? onNavigateToDashboard;
  
  const CalendarScreen({super.key, this.onNavigateToDashboard});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _selectedDate = DateTime.now();
  DateTime _currentMonth = DateTime.now();

  // Mock data - replace with actual data from provider
  final List<CalendarEvent> _events = [
    CalendarEvent(
      id: '1',
      title: 'Christmas',
      date: DateTime(2025, 12, 25),
      type: EventType.govtHoliday,
    ),
    CalendarEvent(
       id: '2',
       title: 'Team Meeting',
       date: DateTime.now(),
       type: EventType.deptEvent,
    )
    // Add more events as needed
  ];

  List<CalendarEvent> _getEventsForDate(DateTime date) {
    return _events.where((event) {
      return event.date.year == date.year &&
          event.date.month == date.month &&
          event.date.day == date.day;
    }).toList();
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  void _goToToday() {
    setState(() {
      _currentMonth = DateTime.now();
      _selectedDate = DateTime.now();
    });
  }

  List<DateTime> _getDaysInMonth() {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final daysInMonth = lastDay.day;
    final firstWeekday = firstDay.weekday;

    final List<DateTime> days = [];

    // Add empty days for the first week
    for (int i = 1; i < firstWeekday; i++) {
      days.add(DateTime(firstDay.year, firstDay.month, 0 - (firstWeekday - i - 1)));
    }

    // Add all days in the month
    for (int i = 1; i <= daysInMonth; i++) {
      days.add(DateTime(_currentMonth.year, _currentMonth.month, i));
    }

    return days;
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool _isSelected(DateTime date) {
    return date.year == _selectedDate.year &&
        date.month == _selectedDate.month &&
        date.day == _selectedDate.day;
  }

  Color _getEventTypeColor(EventType type) {
    switch (type) {
      case EventType.govtHoliday:
        return Colors.red;
      case EventType.orgEvent:
        return Colors.blue;
      case EventType.deptEvent:
        return Colors.orange;
      case EventType.taskDeadline:
        return Colors.green;
    }
  }

  // Get text color for a date based on weekday (for 2026)
  Color? _getDateTextColor(DateTime date, bool isSelected, bool isToday, bool isCurrentMonth, bool isDark) {
    // If selected, always white
    if (isSelected) return Colors.white;
    
    // If today, use blue
    if (isToday) return Colors.blue.shade700;
    
    // For 2026, color Saturdays orange and Sundays red
    if (date.year == 2026 && isCurrentMonth) {
      // Check by day name using DateTime constants, not numeric values
      if (date.weekday == DateTime.saturday) {
        return Colors.orange;
      }
      if (date.weekday == DateTime.sunday) {
        return Colors.red;
      }
    }
    
    // Default colors for current month vs other months
    return isCurrentMonth
        ? (isDark ? Colors.white : const Color(0xFF0F1724))
        : (isDark ? Colors.grey.shade700 : Colors.grey.shade300);
  }

  @override
  Widget build(BuildContext context) {
    final days = _getDaysInMonth();
    final monthName = DateFormat('MMMM yyyy').format(_currentMonth);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F1724);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () {
            if (widget.onNavigateToDashboard != null) {
              widget.onNavigateToDashboard!();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          'Calendar',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Text(
                'Holidays & Events',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              // Header Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _goToToday,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue.shade700,
                      backgroundColor: isDark ? Colors.blue.shade900.withOpacity(0.3) : Colors.blue.shade50,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Text('Today'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Calendar Card
              Card(
                elevation: 0,
                color: cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: borderColor),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Navigation
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: _previousMonth,
                            icon: const Icon(Icons.chevron_left),
                            color: Colors.grey.shade600,
                          ),
                          Text(
                            monthName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          IconButton(
                            onPressed: _nextMonth,
                            icon: const Icon(Icons.chevron_right),
                            color: Colors.grey.shade600,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Weekday Headers
                      Row(
                        children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                            .map((day) => Expanded(
                                  child: Center(
                                    child: Text(
                                      day,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 12),
                      // Days Grid
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          childAspectRatio: 1.0,
                          crossAxisSpacing: 4,
                          mainAxisSpacing: 4,
                        ),
                        itemCount: days.length,
                        itemBuilder: (context, index) {
                          // Handle offset for first week
                           // This logic in original file was a bit manual with generating list.
                           // Reusing the list `days` generated in `_getDaysInMonth`
                          
                          if (index >= days.length) return const SizedBox();

                          final date = days[index];
                          final isCurrentMonth = date.month == _currentMonth.month;
                          final events = _getEventsForDate(date);
                          final isToday = _isToday(date);
                          final isSelected = _isSelected(date);

                          return GestureDetector(
                            onTap: () {
                              if (isCurrentMonth) {
                                setState(() {
                                  _selectedDate = date;
                                });
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.blue.shade600
                                    : isToday
                                        ? (isDark ? Colors.blue.shade900.withOpacity(0.3) : Colors.blue.shade50)
                                        : Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                              child: Stack(
                                children: [
                                  Center(
                                    child: Text(
                                      '${date.day}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                                        color: _getDateTextColor(date, isSelected, isToday, isCurrentMonth, isDark),
                                      ),
                                    ),
                                  ),
                                  if (events.isNotEmpty)
                                    Positioned(
                                      bottom: 6,
                                      left: 0,
                                      right: 0,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: events.take(3).map((event) {
                                          return Container(
                                            width: 4,
                                            height: 4,
                                            margin: const EdgeInsets.symmetric(horizontal: 1),
                                            decoration: BoxDecoration(
                                              color: isSelected ? Colors.white : _getEventTypeColor(event.type),
                                              shape: BoxShape.circle,
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Legend (simplified)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                   _buildLegendItem(Colors.red, 'Holiday'),
                   _buildLegendItem(Colors.blue, 'Org'),
                   _buildLegendItem(Colors.orange, 'Dept'),
                   _buildLegendItem(Colors.green, 'Task'),
                ],
              ),
              const SizedBox(height: 24),

              // Selected Date Events List
              if (_getEventsForDate(_selectedDate).isNotEmpty) ...[
                Text(
                  'Events on ${DateFormat('MMMM d, yyyy').format(_selectedDate)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F1724),
                  ),
                ),
                const SizedBox(height: 12),
                ..._getEventsForDate(_selectedDate).map((event) {
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 12),
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _getEventTypeColor(event.type),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              event.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F1724),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ] else ...[
                 Center(
                   child: Padding(
                     padding: const EdgeInsets.all(20.0),
                     child: Text(
                      'No events on this day',
                      style: TextStyle(color: Colors.grey.shade400),
                     ),
                   ),
                 ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

enum EventType {
  govtHoliday,
  orgEvent,
  deptEvent,
  taskDeadline,
}

class CalendarEvent {
  final String id;
  final String title;
  final DateTime date;
  final EventType type;

  CalendarEvent({
    required this.id,
    required this.title,
    required this.date,
    required this.type,
  });
}

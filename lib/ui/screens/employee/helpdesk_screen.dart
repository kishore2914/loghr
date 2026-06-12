import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:loghr_mobile/data/models/ticket.dart';
import 'package:loghr_mobile/ui/widgets/dashboard_widgets.dart';
import 'package:intl/intl.dart';

class HelpdeskScreen extends StatefulWidget {
  const HelpdeskScreen({super.key});

  @override
  State<HelpdeskScreen> createState() => _HelpdeskScreenState();
}

class _HelpdeskScreenState extends State<HelpdeskScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatus = 'All Status';
  String _selectedPriority = 'All Priority';
  String _selectedCategory = 'All Categories';

  // New Ticket Form Controllers
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String? _selectedTicketCategory;
  String _selectedTicketPriority = 'Medium';
  final List<String> _attachments = [];

  // Mock data - replace with actual data from provider
  final List<Ticket> _tickets = [
    Ticket(
      id: '1',
      ticketId: 'TKT-2500003',
      subject: 'Verify my leave',
      category: 'Admin/Facility',
      priority: 'High',
      status: 'Closed',
      created: DateTime.now().subtract(const Duration(days: 1)),
      lastUpdate: DateTime.now().subtract(const Duration(days: 1)),
    ),
    Ticket(
      id: '2',
      ticketId: 'TKT-2500002',
      subject: 'Testing',
      category: 'Technical/IT Support',
      priority: 'Medium',
      status: 'Closed',
      created: DateTime.now().subtract(const Duration(days: 4)),
      lastUpdate: DateTime.now().subtract(const Duration(days: 4)),
    ),
  ];

  List<Ticket> get _filteredTickets {
    var filtered = _tickets;

    // Filter by search
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((ticket) {
        return ticket.subject.toLowerCase().contains(query) ||
            ticket.ticketId.toLowerCase().contains(query) ||
            ticket.category.toLowerCase().contains(query);
      }).toList();
    }

    // Filter by status
    if (_selectedStatus != 'All Status') {
      filtered = filtered.where((ticket) {
        return ticket.status == _selectedStatus;
      }).toList();
    }

    // Filter by priority
    if (_selectedPriority != 'All Priority') {
      filtered = filtered.where((ticket) {
        return ticket.priority == _selectedPriority;
      }).toList();
    }

    // Filter by category
    if (_selectedCategory != 'All Categories') {
      filtered = filtered.where((ticket) {
        return ticket.category == _selectedCategory;
      }).toList();
    }

    return filtered;
  }

  int get _totalTickets => _tickets.length;
  int get _openTickets => _tickets.where((t) => t.status == 'Open').length;
  int get _inProgressTickets => _tickets.where((t) => t.status == 'In Progress').length;
  int get _resolvedTickets => _tickets.where((t) => t.status == 'Resolved' || t.status == 'Closed').length;
  int get _overdueTickets => _tickets.where((t) => t.status == 'Overdue').length;

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.orange.shade700;
      case 'critical':
        return Colors.red.shade700;
      case 'medium':
        return Colors.blue.shade700;
      case 'low':
        return Colors.green.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  Color _getPriorityBgColor(String priority) {
     switch (priority.toLowerCase()) {
      case 'high':
        return Colors.orange.shade50;
      case 'critical':
        return Colors.red.shade50;
      case 'medium':
        return Colors.blue.shade50;
      case 'low':
        return Colors.green.shade50;
      default:
        return Colors.grey.shade50;
    }
  }


  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return Colors.blue.shade700;
      case 'in progress':
        return Colors.orange.shade700;
      case 'resolved':
      case 'closed':
        return Colors.grey.shade700;
      case 'overdue':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

    Color _getStatusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return Colors.blue.shade50;
      case 'in progress':
        return Colors.orange.shade50;
      case 'resolved':
      case 'closed':
        return Colors.grey.shade100;
      case 'overdue':
        return Colors.red.shade50;
      default:
        return Colors.grey.shade100;
    }
  }

  IconData _getCategoryIcon(String category) {
    if (category.contains('Technical') || category.contains('IT')) {
      return Icons.computer;
    } else if (category.contains('Admin') || category.contains('Facility')) {
      return Icons.business;
    } else {
      return Icons.category;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _showCreateTicketDialog() {
    showDialog(
      context: context,
      builder: (context) => _buildCreateTicketDialog(),
    );
  }

  Widget _buildCreateTicketDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F1724);
    final borderColor = isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300;

    return Dialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Create New Ticket',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: isDark ? Colors.grey : Colors.black),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Category *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildCategoryChip('Technical/IT Support', Icons.computer, isDark),
                  _buildCategoryChip('HR Related', Icons.people, isDark),
                  _buildCategoryChip('Admin/Facility', Icons.business, isDark),
                  // _buildCategoryChip('Payroll Issue', Icons.account_balance_wallet, isDark), // Removed
                  _buildCategoryChip('Other', Icons.help_outline, isDark),
                ],
              ),
              const SizedBox(height: 16),
              Text('Priority *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildPriorityButton('Low', isDark)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildPriorityButton('Medium', isDark)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildPriorityButton('High', isDark)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildPriorityButton('Critical', isDark)),
                ],
              ),
              const SizedBox(height: 16),
              Text('Subject *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
              const SizedBox(height: 8),
              TextField(
                controller: _subjectController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: 'Brief summary of the issue',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.blue.shade600)),
                  filled: true,
                  fillColor: isDark ? Colors.grey.shade900 : Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text('Description *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                maxLines: 4,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: 'Provide detailed information...',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.blue.shade600)),
                  filled: true,
                  fillColor: isDark ? Colors.grey.shade900 : Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                          // TODO: Implement create ticket logic
                          Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Create Ticket'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label, IconData icon, bool isDark) {
    final isSelected = _selectedTicketCategory == label;
    final bgColor = isSelected 
        ? Colors.blue.shade600 
        : (isDark ? Colors.grey.shade800 : Colors.grey.shade100);
    final fgColor = isSelected 
        ? Colors.white 
        : (isDark ? Colors.grey.shade300 : Colors.grey.shade700);

    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fgColor),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (bool selected) {
        setState(() {
          _selectedTicketCategory = selected ? label : null;
        });
      },
      selectedColor: Colors.blue.shade600,
      labelStyle: TextStyle(color: fgColor),
      backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
      side: BorderSide(color: isSelected ? Colors.transparent : (isDark ? Colors.grey.shade700 : Colors.grey.shade300)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildPriorityButton(String priority, bool isDark) {
    final isSelected = _selectedTicketPriority == priority;
    Color color;
    switch (priority) {
      case 'Critical': color = Colors.red; break;
      case 'High': color = Colors.orange; break;
      case 'Low': color = Colors.green; break;
      default: color = Colors.blue;
    }

    return InkWell(
      onTap: () => setState(() => _selectedTicketPriority = priority),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected 
              ? color.withOpacity(0.1) 
              : (isDark ? Colors.grey.shade900 : Colors.white),
          border: Border.all(
            color: isSelected 
                ? color 
                : (isDark ? Colors.grey.shade700 : Colors.grey.shade300), 
            width: isSelected ? 2 : 1
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            priority,
            style: TextStyle(
              color: isSelected ? color : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 12
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F1724);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
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
                            'Helpdesk',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Support & Tickets',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _showCreateTicketDialog,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('New Ticket'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Stats Grid
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.3,
                    children: [
                      DashboardStatCard(
                        title: 'Total',
                        value: '$_totalTickets',
                        subValue: 'Tickets',
                        icon: Icons.confirmation_number_outlined,
                        baseColor: Colors.blue.shade700,
                        backgroundColor: Colors.blue.shade50,
                      ),
                      DashboardStatCard(
                        title: 'Open',
                        value: '$_openTickets',
                        subValue: 'Pending',
                        icon: Icons.pending_actions,
                        baseColor: Colors.orange.shade700,
                        backgroundColor: Colors.orange.shade50,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Filters
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildDropdown(_selectedStatus, ['All Status', 'Open', 'In Progress', 'Resolved', 'Closed'], (val) => setState(() => _selectedStatus = val!), isDark),
                        const SizedBox(width: 12),
                        _buildDropdown(_selectedPriority, ['All Priority', 'Low', 'Medium', 'High', 'Critical'], (val) => setState(() => _selectedPriority = val!), isDark),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Ticket List
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                itemCount: _filteredTickets.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final ticket = _filteredTickets[index];
                  return Card(
                    elevation: 2,
                    color: cardColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  ticket.ticketId,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getStatusBgColor(ticket.status),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  ticket.status,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _getStatusColor(ticket.status),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            ticket.subject,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.category_outlined, size: 14, color: Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Text(
                                ticket.category,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  border: Border.all(color: _getPriorityColor(ticket.priority).withOpacity(0.5)),
                                  borderRadius: BorderRadius.circular(4),
                                  color: _getPriorityBgColor(ticket.priority),
                                ),
                                child: Text(
                                  ticket.priority,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _getPriorityColor(ticket.priority),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Divider(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Updated ${_formatTimeAgo(ticket.lastUpdate)}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                              ),
                              Icon(Icons.chevron_right, color: Colors.grey.shade300, size: 18),
                            ],
                          ),
                        ],
                      ),
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

  Widget _buildDropdown(String value, List<String> items, ValueChanged<String?> onChanged, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      height: 40,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600, size: 18),
          style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.grey.shade800, fontWeight: FontWeight.w500),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

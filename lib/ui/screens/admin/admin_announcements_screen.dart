import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:loghr_mobile/data/services/admin_service.dart';
import 'package:loghr_mobile/data/models/announcement.dart';
import 'package:loghr_mobile/logic/announcement_provider.dart';
import 'package:loghr_mobile/logic/profile_provider.dart';

class AdminAnnouncementsScreen extends StatefulWidget {
  const AdminAnnouncementsScreen({super.key});

  @override
  State<AdminAnnouncementsScreen> createState() => _AdminAnnouncementsScreenState();
}

class _AdminAnnouncementsScreenState extends State<AdminAnnouncementsScreen> {
  final AdminService _adminService = AdminService();
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All Categories';
  String _selectedPriority = 'All Priorities';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAnnouncements();
    });
  }

  void _loadAnnouncements() {
    final profileProvider = context.read<ProfileProvider>();
    final orgId = profileProvider.profileData?['organization_id'] as String?;
    context.read<AnnouncementProvider>().loadAnnouncements(organizationId: orgId);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openAnnouncementForm() {
    final profileProvider = context.read<ProfileProvider>();
    final orgId = profileProvider.profileData?['organization_id'] as String?;
    
    if (orgId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Organization ID not found'))
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _AnnouncementFormDialog(organizationId: orgId),
    ).then((_) {
      // Refresh list after dialog closes
      _loadAnnouncements();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Announcements'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadAnnouncements(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'admin_announcements_fab',
        onPressed: _openAnnouncementForm,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: Consumer<AnnouncementProvider>(
          builder: (context, provider, child) {
            final filteredAnnouncements = provider.filterAnnouncements(
              query: _searchController.text,
              category: _selectedCategory,
              priority: _selectedPriority,
            );

            return Column(
              children: [
                // Filters
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                       Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                             BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: 'Search announcements...',
                            prefixIcon: Icon(Icons.search),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildDropdown(_selectedCategory, [
                              'All Categories', 'GENERAL', 'HR', 'IT', 'FINANCE', 'OPERATIONS'
                            ], (val) => setState(() => _selectedCategory = val!), isDark),
                            const SizedBox(width: 12),
                            _buildDropdown(_selectedPriority, [
                              'All Priorities', 'LOW', 'NORMAL', 'HIGH', 'URGENT'
                            ], (val) => setState(() => _selectedPriority = val!), isDark),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // List
                Expanded(
                  child: provider.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : filteredAnnouncements.isEmpty
                          ? Center(child: Text('No announcements found', style: TextStyle(color: Colors.grey.shade600)))
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: filteredAnnouncements.length,
                              itemBuilder: (context, index) {
                                return _buildAnnouncementCard(filteredAnnouncements[index], isDark);
                              },
                            ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDropdown(String value, List<String> items, ValueChanged<String?> onChanged, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

    Widget _buildAnnouncementCard(Announcement announcement, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Row(
          children: [
            Expanded(child: Text(announcement.title, style: const TextStyle(fontWeight: FontWeight.bold))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _getPriorityColor(announcement.priority).withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                announcement.priority,
                style: TextStyle(fontSize: 10, color: _getPriorityColor(announcement.priority)),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(announcement.content, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Text(
              DateFormat('MMM dd, yyyy').format(announcement.createdAt),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toUpperCase()) {
      case 'URGENT': return Colors.red;
      case 'HIGH': return Colors.orange;
      case 'NORMAL': return Colors.blue;
      case 'LOW': return Colors.green;
      default: return Colors.grey;
    }
  }
}

class _AnnouncementFormDialog extends StatefulWidget {
  final String organizationId;
  const _AnnouncementFormDialog({required this.organizationId});

  @override
  State<_AnnouncementFormDialog> createState() => _AnnouncementFormDialogState();
}

class _AnnouncementFormDialogState extends State<_AnnouncementFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _expiresController = TextEditingController(text: '30');
  final AdminService _adminService = AdminService();

  String _type = 'General';
  String _priority = 'Low';
  String _sendTo = 'All Employees';
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _expiresController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final success = await _adminService.createAnnouncement({
      'organization_id': widget.organizationId,
      'title': _titleController.text.trim(),
      'content': _contentController.text.trim(),
      'priority': _priority.toUpperCase(),
      'is_new': true,
      'is_read': false,
    });

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Announcement posted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to post announcement')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Purple Gradient Header
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.deepPurple.shade600, Colors.purple.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create New Announcement',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Share important news with your team',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              // Form Body
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      _buildLabel('Title', isRequired: true),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _titleController,
                        decoration: _inputDecoration('Enter announcement title', isDark),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
                      ),

                      const SizedBox(height: 16),

                      // Content
                      _buildLabel('Content', isRequired: true),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _contentController,
                        maxLines: 4,
                        decoration: _inputDecoration('Write your announcement message...', isDark),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Content is required' : null,
                      ),

                      const SizedBox(height: 16),

                      // Type + Priority row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Type'),
                                const SizedBox(height: 6),
                                _buildStyledDropdown(
                                  value: _type,
                                  items: ['General', 'HR', 'IT', 'Finance', 'Operations'],
                                  onChanged: (v) => setState(() => _type = v!),
                                  icon: Icons.category_rounded,
                                  iconColor: Colors.deepPurple,
                                  isDark: isDark,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Priority'),
                                const SizedBox(height: 6),
                                _buildStyledDropdown(
                                  value: _priority,
                                  items: ['Low', 'Normal', 'High', 'Urgent'],
                                  onChanged: (v) => setState(() => _priority = v!),
                                  isDark: isDark,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Send To
                      _buildLabel('Send To', isRequired: true),
                      const SizedBox(height: 6),
                      _buildStyledDropdown(
                        value: _sendTo,
                        items: ['All Employees', 'Department', 'Specific Team'],
                        onChanged: (v) => setState(() => _sendTo = v!),
                        isDark: isDark,
                      ),

                      const SizedBox(height: 16),

                      // Expires In
                      _buildLabel('Expires In (Days)'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _expiresController,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration('30', isDark),
                      ),
                    ],
                  ),
                ),
              ),

              // Buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded, size: 16),
                      label: Text(_isSaving ? 'Sending...' : 'Create & Send'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text, {bool isRequired = false}) {
    return RichText(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
        children: isRequired
            ? [const TextSpan(text: ' *', style: TextStyle(color: Colors.red))]
            : [],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      filled: true,
      fillColor: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.deepPurple.shade400, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _buildStyledDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    IconData? icon,
    Color? iconColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          icon: Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Colors.grey.shade500),
          items: items.map((item) => DropdownMenuItem(
            value: item,
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: iconColor ?? Colors.grey),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(item, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          )).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

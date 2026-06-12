import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:loghr_mobile/data/models/announcement.dart';
import 'package:loghr_mobile/logic/announcement_provider.dart';
import 'package:loghr_mobile/logic/profile_provider.dart';

class AnnouncementsScreen extends StatefulWidget {
  final VoidCallback? onNavigateToDashboard;
  
  const AnnouncementsScreen({super.key, this.onNavigateToDashboard});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All Categories';
  String _selectedPriority = 'All Priorities';

  @override
  void initState() {
    super.initState();
    // Fetch announcements when screen loads
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F1724);

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
          'Announcements',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
        ),
      ),
      body: SafeArea(
        child: Consumer<AnnouncementProvider>(
          builder: (context, provider, child) {
            // Get filtered list based on current local state
            final filteredAnnouncements = provider.filterAnnouncements(
              query: _searchController.text,
              category: _selectedCategory,
              priority: _selectedPriority,
            );

            return Column(
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Announcements',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Latest updates from your organization',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Optional: Show unread badge if needed, e.g. provider.unreadCount
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Search and Filter Bar
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isMobile = constraints.maxWidth < 600;
                          if (isMobile) {
                            return Column(
                              children: [
                                // Search field
                                _buildSearchField(isDark),
                                const SizedBox(height: 12),
                                // Filter dropdowns
                                Row(
                                  children: [
                                    Expanded(child: _buildDropdown(_selectedCategory, [
                                      'All Categories', 'GENERAL', 'HR', 'IT', 'FINANCE', 'OPERATIONS'
                                    ], (val) => setState(() => _selectedCategory = val!), isDark)),
                                    const SizedBox(width: 12),
                                    Expanded(child: _buildDropdown(_selectedPriority, [
                                      'All Priorities', 'LOW', 'NORMAL', 'HIGH', 'URGENT'
                                    ], (val) => setState(() => _selectedPriority = val!), isDark)),
                                  ],
                                ),
                              ],
                            );
                          } else {
                            return Row(
                              children: [
                                Expanded(child: _buildSearchField(isDark)),
                                const SizedBox(width: 12),
                                Expanded(child: _buildDropdown(_selectedCategory, [
                                  'All Categories', 'GENERAL', 'HR', 'IT', 'FINANCE', 'OPERATIONS'
                                ], (val) => setState(() => _selectedCategory = val!), isDark)),
                                const SizedBox(width: 12),
                                Expanded(child: _buildDropdown(_selectedPriority, [
                                  'All Priorities', 'LOW', 'NORMAL', 'HIGH', 'URGENT'
                                ], (val) => setState(() => _selectedPriority = val!), isDark)),
                              ],
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),

                // Announcements List
                Expanded(
                  child: provider.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                          onRefresh: () async => _loadAnnouncements(),
                          child: filteredAnnouncements.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade300),
                                      const SizedBox(height: 16),
                                      Text(
                                        provider.error != null 
                                            ? 'Error loading announcements' 
                                            : 'No announcements found',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey.shade500,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      if (provider.error != null)
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(provider.error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                                        ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  itemCount: filteredAnnouncements.length,
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  itemBuilder: (context, index) {
                                    final announcement = filteredAnnouncements[index];
                                    return _buildAnnouncementCard(announcement, isDark);
                                  },
                                ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSearchField(bool isDark) {
    return TextField(
      controller: _searchController,
      style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        hintText: 'Search title or content',
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        prefixIcon: Icon(Icons.search, color: Colors.grey.shade400, size: 20),
        filled: true,
        fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blue, width: 1.5),
        ),
      ),
      onChanged: (_) => setState(() {}),
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
          dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          isExpanded: true,
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

  Widget _buildAnnouncementCard(Announcement announcement, bool isDark) {
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');
    final formattedDate = dateFormat.format(announcement.createdAt);

    Color priorityColor;
    Color priorityBg;
    switch (announcement.priority.toUpperCase()) {
      case 'URGENT':
        priorityColor = Colors.red.shade700;
        priorityBg = Colors.red.shade50;
        break;
      case 'HIGH':
        priorityColor = Colors.orange.shade700;
        priorityBg = Colors.orange.shade50;
        break;
      case 'NORMAL':
        priorityColor = Colors.blue.shade700;
        priorityBg = Colors.blue.shade50;
        break;
      case 'LOW':
        priorityColor = Colors.green.shade700;
        priorityBg = Colors.green.shade50;
        break;
      default:
        priorityColor = Colors.blue.shade700;
        priorityBg = Colors.blue.shade50;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shadowColor: Colors.black.withOpacity(0.05),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tags Row
            Row(
              children: [
                if (announcement.isNew)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade600,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.star, color: Colors.white, size: 10),
                        SizedBox(width: 4),
                        Text('NEW', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade200),
                  ),
                  child: Text(
                    announcement.category,
                    style: TextStyle(
                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: priorityBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: priorityBg), 
                  ),
                  child: Text(
                    announcement.priority,
                    style: TextStyle(
                      color: priorityColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Title
            Text(
              announcement.title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F1724),
              ),
            ),
            const SizedBox(height: 8),
            // Content
            Text(
              announcement.content,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey.shade300 : Colors.black87,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            // Timestamp
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey.shade400),
                const SizedBox(width: 6),
                Text(
                  formattedDate,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:loghr_mobile/data/models/goal.dart';
import 'package:loghr_mobile/data/services/performance_service.dart';
import 'package:intl/intl.dart';

class GoalDetailsModal extends StatefulWidget {
  final Goal goal;

  const GoalDetailsModal({
    super.key,
    required this.goal,
  });

  @override
  State<GoalDetailsModal> createState() => _GoalDetailsModalState();
}

class _GoalDetailsModalState extends State<GoalDetailsModal> {
  final PerformanceService _performanceService = PerformanceService();
  List<Map<String, dynamic>> _comments = [];
  bool _isLoadingComments = true;
  final TextEditingController _commentController = TextEditingController();
  Map<String, dynamic>? _goalDetails;
  String? _assignedToName;
  String? _departmentName;
  String? _createdByName;

  @override
  void initState() {
    super.initState();
    _loadGoalDetails();
    _loadComments();
  }

  Future<void> _loadGoalDetails() async {
    try {
      final goalData = await _performanceService.getGoalDetails(widget.goal.id);
      if (goalData != null && mounted) {
        setState(() {
          _goalDetails = goalData;
          _assignedToName = goalData['assigned_to_name'] as String?;
          _departmentName = goalData['department_name'] as String?;
          _createdByName = goalData['created_by_name'] as String?;
        });
      }
    } catch (e) {
      print('GoalDetailsModal: Error loading goal details: $e');
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      setState(() => _isLoadingComments = true);
      final comments = await _performanceService.getGoalComments(widget.goal.id);
      if (mounted) {
        setState(() {
          _comments = comments;
          _isLoadingComments = false;
        });
      }
    } catch (e) {
      print('GoalDetailsModal: Error loading comments: $e');
      if (mounted) {
        setState(() => _isLoadingComments = false);
      }
    }
  }

  Future<void> _addComment() async {
    final commentText = _commentController.text.trim();
    if (commentText.isEmpty) return;

    try {
      final success = await _performanceService.addGoalComment(widget.goal.id, commentText);
      if (success) {
        _commentController.clear();
        await _loadComments();
      }
    } catch (e) {
      print('GoalDetailsModal: Error adding comment: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F1724);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: borderColor),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.goal.title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    color: textColor,
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Description
                    _buildSection(
                      'Description',
                      widget.goal.description?.isNotEmpty == true
                          ? widget.goal.description!
                          : 'No description provided.',
                      isDark,
                    ),
                    const SizedBox(height: 24),
                    // Milestones
                    _buildSection(
                      'Milestones',
                      'No milestones defined.',
                      isDark,
                    ),
                    const SizedBox(height: 24),
                    // Discussion
                    Text(
                      'Discussion',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_isLoadingComments)
                      const Center(child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ))
                    else if (_comments.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'No comments yet',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      )
                    else
                      ..._comments.map((comment) => _buildComment(comment, isDark)),
                    const SizedBox(height: 16),
                    // Add comment input
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            decoration: InputDecoration(
                              hintText: 'Add a comment...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: borderColor),
                              ),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade50,
                            ),
                            style: TextStyle(color: textColor),
                            maxLines: 2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _addComment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Send'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Progress
                    Text(
                      'Progress',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Completion',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Slider(
                                value: widget.goal.progress.toDouble(),
                                min: 0,
                                max: 100,
                                divisions: 100,
                                label: '${widget.goal.progress}%',
                                onChanged: (value) {
                                  // TODO: Update progress
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Status dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.blue.withOpacity(0.2) : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? Colors.blue.withOpacity(0.3) : Colors.blue.shade200,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Status',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                          DropdownButton<String>(
                            value: widget.goal.status == GoalStatus.active
                                ? 'In Progress'
                                : widget.goal.status.displayName,
                            underline: const SizedBox(),
                            items: ['In Progress', 'Completed', 'Overdue'].map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (value) {
                              // TODO: Update status
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Progress bar
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: widget.goal.progress / 100,
                              minHeight: 8,
                              backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${widget.goal.progress} %',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Assigned to, Department, Timeline, Created by
                    _buildInfoRow('ASSIGNED TO', _assignedToName ?? 'Not specified', Icons.person, isDark),
                    const SizedBox(height: 12),
                    _buildInfoRow('DEPARTMENT', _departmentName ?? 'Not specified', Icons.business, isDark),
                    const SizedBox(height: 12),
                    _buildInfoRow('TIMELINE', 
                      'Start: ${DateFormat('MMM d, yyyy').format(widget.goal.startDate)}\nDue: ${DateFormat('MMM d, yyyy').format(widget.goal.dueDate)}',
                      Icons.calendar_today, isDark),
                    const SizedBox(height: 12),
                    _buildInfoRow('CREATED BY', _createdByName ?? 'Not specified', Icons.people, isDark),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0F1724),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
            ),
          ),
          child: Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white : const Color(0xFF0F1724),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComment(Map<String, dynamic> comment, bool isDark) {
    String? userName;
    if (comment['user_profiles'] != null) {
      final userProfiles = comment['user_profiles'];
      if (userProfiles is Map<String, dynamic>) {
        userName = userProfiles['full_name'] as String?;
      }
    }
    userName ??= comment['user_name'] as String?;
    userName ??= 'Unknown User';
    
    final commentText = comment['comment'] as String? ?? comment['content'] as String? ?? '';
    final createdAt = comment['created_at'] != null
        ? DateTime.parse(comment['created_at'] as String)
        : DateTime.now();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.blue.shade600,
            child: Text(
              userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      userName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F1724),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('MMM d, h:mm a').format(createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  commentText,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF0F1724),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white : const Color(0xFF0F1724),
            ),
          ),
        ),
      ],
    );
  }
}


import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:loghr_mobile/logic/auth_provider.dart';
import 'package:loghr_mobile/data/services/performance_service.dart';
import 'package:loghr_mobile/data/services/task_service.dart';
import 'package:loghr_mobile/data/models/performance.dart';
import 'package:loghr_mobile/data/models/goal.dart';
import 'package:loghr_mobile/data/models/badge.dart' as model;
import 'package:loghr_mobile/data/models/performance_review.dart';
import 'package:loghr_mobile/data/models/task.dart';
import 'package:loghr_mobile/ui/widgets/performance_widgets.dart';
import 'package:loghr_mobile/ui/widgets/goal_details_modal.dart';
import 'package:loghr_mobile/config/supabase_config.dart';

class PerformanceScreen extends StatefulWidget {
  final VoidCallback? onNavigateToDashboard;
  
  const PerformanceScreen({super.key, this.onNavigateToDashboard});

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  final PerformanceService _performanceService = PerformanceService();
  final TaskService _taskService = TaskService();

  Performance? _performance;
  List<Goal> _goals = [];
  List<model.Badge> _badges = [];
  List<PerformanceReview> _reviews = [];
  List<Task> _activeTasks = [];
  List<Task> _completedTasks = [];
  List<Map<String, dynamic>> _recentActivity = [];
  Map<String, dynamic> _stats = {};

  String _selectedGoalStatus = 'All Status';
  String _selectedGoalType = 'All Types';

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    // Get the current authenticated user directly from Supabase Auth
    // This ensures we're using the correct user ID that matches the email
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // First try to get from Supabase Auth directly (most reliable)
    String? userId;
    try {
      final authUser = supabase.auth.currentUser;
      userId = authUser?.id;
      print('PerformanceScreen: Using user_id from Supabase Auth: $userId');
      if (authUser?.email != null) {
        print('PerformanceScreen: User email: ${authUser?.email}');
      }
    } catch (e) {
      print('PerformanceScreen: Error getting user from Supabase Auth: $e');
      // Fallback to AuthProvider
      userId = authProvider.user?.id;
      print('PerformanceScreen: Using user_id from AuthProvider: $userId');
    }

    if (userId == null) {
      print('PerformanceScreen: No user ID available');
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      print('PerformanceScreen: Loading all performance data for user: $userId');
      
      // Load all data in parallel
      final results = await Future.wait([
        _performanceService.getEmployeePerformance(userId),
        _performanceService.getGoals(userId),
        _performanceService.getBadges(userId),
        _performanceService.getReviews(userId),
        _taskService.getTasksForUser(userId),
        _performanceService.getRecentActivity(userId),
        _performanceService.getPerformanceStats(userId),
      ]);

      final goals = results[1] as List<Goal>;
      final reviews = results[3] as List<PerformanceReview>;
      
      print('PerformanceScreen: Loaded ${goals.length} goals');
      print('PerformanceScreen: Loaded ${reviews.length} reviews');
      
      if (goals.isEmpty) {
        print('PerformanceScreen: ⚠️ WARNING - No goals loaded!');
        print('PerformanceScreen: User ID: $userId');
        // Try to debug why goals aren't loading
        try {
          final authUser = supabase.auth.currentUser;
          print('PerformanceScreen: Auth user ID: ${authUser?.id}');
          print('PerformanceScreen: Auth user email: ${authUser?.email}');
          
          // Try to fetch goals directly to see what happens
          print('PerformanceScreen: Attempting direct goals fetch for debugging...');
          final directGoals = await _performanceService.getGoals(userId);
          print('PerformanceScreen: Direct fetch returned ${directGoals.length} goals');
        } catch (e) {
          print('PerformanceScreen: Error during debug fetch: $e');
        }
      } else {
        print('PerformanceScreen: ✅ Goals loaded successfully:');
        for (var goal in goals) {
          print('  - ${goal.title} (${goal.status.displayName}, ${goal.progress}%)');
        }
      }
      
      if (mounted) {
        setState(() {
          _performance = results[0] as Performance?;
          _goals = goals;
          _badges = results[2] as List<model.Badge>;
          _reviews = reviews;
          
          final allTasks = results[4] as List<Task>;
          _activeTasks = allTasks.where((t) => t.status != 'completed').toList();
          _completedTasks = allTasks.where((t) => t.status == 'completed').toList();
          
          _recentActivity = results[5] as List<Map<String, dynamic>>;
          _stats = results[6] as Map<String, dynamic>;
          
          _isLoading = false;
        });
        
        print('PerformanceScreen: Data loaded successfully');
        print('PerformanceScreen: Goals count: ${_goals.length}');
        print('PerformanceScreen: Reviews count: ${_reviews.length}');
      }
    } catch (e, stackTrace) {
      print('PerformanceScreen: Error loading performance data: $e');
      print('PerformanceScreen: Stack trace: $stackTrace');
      
      final errorStr = e.toString();
      if (errorStr.contains('Failed host lookup') || 
          errorStr.contains('SocketException') ||
          errorStr.contains('Network is unreachable')) {
        print('PerformanceScreen: Network connectivity issue detected');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Network error: Please check your internet connection'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
      
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleSubmitProof(String taskId) async {
    // TODO: Implement submit proof functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Submit proof functionality coming soon')),
    );
  }

  void _handleGoalTap(Goal goal) {
    // Show goal details modal
    showDialog(
      context: context,
      builder: (context) => GoalDetailsModal(goal: goal),
    );
  }

  List<Goal> get _filteredGoals {
    return _goals.where((goal) {
      bool statusMatch = _selectedGoalStatus == 'All Status' ||
          goal.status.displayName == _selectedGoalStatus;
      bool typeMatch = _selectedGoalType == 'All Types' ||
          goal.type.displayName == _selectedGoalType;
      return statusMatch && typeMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F1724);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200;

    if (_isLoading) {
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
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

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
          'Performance',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                Text(
                  'My Performance',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Track your goals and performance reviews',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 24),

                // Summary Metrics Cards (matching web design)
                _buildSummaryMetrics(),
                const SizedBox(height: 24),

                // My Goals Section
                Card(
                  elevation: 0,
                  color: cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: borderColor),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'My Goals',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.blue.withOpacity(0.2) : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.track_changes, color: Colors.blue.shade700, size: 20),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Filters
                        Row(
                          children: [
                            Expanded(
                              child: _buildDropdown(
                                _selectedGoalStatus,
                                ['All Status', 'Active', 'Completed', 'Overdue'],
                                (val) => setState(() => _selectedGoalStatus = val!),
                                isDark,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildDropdown(
                                _selectedGoalType,
                                ['All Types', 'Personal', 'Team', 'Department'],
                                (val) => setState(() => _selectedGoalType = val!),
                                isDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Goals List
                        if (_filteredGoals.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                children: [
                                  Icon(Icons.track_changes, size: 48, color: Colors.grey.shade300),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No goals found',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade500,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ...(_filteredGoals.map((goal) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: GoalCard(
                                  goal: goal,
                                  onTap: () => _handleGoalTap(goal),
                                ),
                              ))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Performance Reviews Section
                Card(
                  elevation: 0,
                  color: cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: borderColor),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Performance Reviews',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.orange.withOpacity(0.2) : Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.star_outline, color: Colors.orange.shade700, size: 20),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_reviews.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                children: [
                                  Icon(Icons.star_border, size: 48, color: Colors.grey.shade300),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No performance reviews yet',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade500,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ...(_reviews.map((review) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: ReviewCard(review: review),
                              ))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown(String value, List<String> items, ValueChanged<String?> onChanged, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.transparent : Colors.grey.shade200),
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

  Widget _buildSummaryMetrics() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Calculate metrics from goals (matching web version exactly)
    // Active Goals: Goals that are in progress (status = active)
    final activeGoals = _goals.where((g) => g.status == GoalStatus.active).length;
    
    // Completed: Goals with status = completed
    final completedGoals = _goals.where((g) => g.status == GoalStatus.completed).length;
    
    // Overdue: Goals that are not completed and due date has passed
    final overdueGoals = _goals.where((g) {
      if (g.status == GoalStatus.completed) return false;
      // Check if due date is before today (not including today)
      final today = DateTime.now();
      final dueDate = DateTime(g.dueDate.year, g.dueDate.month, g.dueDate.day);
      final todayDate = DateTime(today.year, today.month, today.day);
      return dueDate.isBefore(todayDate);
    }).length;
    
    // Calculate average progress from all goals (matching web: 85%)
    final avgProgress = _goals.isEmpty 
        ? 0.0 
        : (_goals.map((g) => g.progress).reduce((a, b) => a + b) / _goals.length).roundToDouble();
    
    // Calculate average rating from reviews (matching web: 5)
    // If no reviews, show 0, otherwise calculate average
    final avgRating = _reviews.isEmpty 
        ? 0.0 
        : (_reviews.map((r) => r.rating).reduce((a, b) => a + b) / _reviews.length);
    
    print('📊 Summary Metrics:');
    print('  Active Goals: $activeGoals');
    print('  Completed: $completedGoals');
    print('  Overdue: $overdueGoals');
    print('  Avg Progress: $avgProgress%');
    print('  Avg Rating: $avgRating');

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Active Goals',
                activeGoals.toString(),
                Icons.track_changes,
                Colors.blue,
                isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Completed',
                completedGoals.toString(),
                Icons.check_circle,
                Colors.green,
                isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Overdue',
                overdueGoals.toString(),
                Icons.warning,
                Colors.red,
                isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Avg Progress',
                '${avgProgress.round()}%',
                Icons.trending_up,
                Colors.purple,
                isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Avg Rating',
                avgRating > 0 ? avgRating.toStringAsFixed(1) : '0',
                Icons.star,
                Colors.orange,
                isDark,
              ),
            ),
            const Spacer(),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

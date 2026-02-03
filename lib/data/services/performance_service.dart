import 'package:loghr_mobile/data/models/performance.dart';
import 'package:loghr_mobile/data/models/goal.dart';
import 'package:loghr_mobile/data/models/badge.dart' as model;
import 'package:loghr_mobile/data/models/performance_review.dart';
import 'package:loghr_mobile/config/supabase_config.dart';
import 'package:loghr_mobile/data/services/loyalty_service.dart';

class PerformanceService {
  // Helper method to get employee_id from user_id
  Future<String?> _getEmployeeId(String userId) async {
    try {
      print('PerformanceService: Fetching employee_id for user_id: $userId');
      
      // Try to get from user_profiles first
      var profileData = await supabase
          .from('user_profiles')
          .select('employee_id, full_name, user_id')
          .eq('user_id', userId)
          .maybeSingle();

      print('PerformanceService: Profile query result: $profileData');

      if (profileData == null) {
        print('PerformanceService: No profile found by user_id, trying alternative lookup...');
        // Try alternative: maybe employee_id is the same as user_id
        // Or try to get from employees table directly
        try {
          final employeeData = await supabase
              .from('employees')
              .select('id, full_name')
              .eq('user_id', userId)
              .maybeSingle();
          
          if (employeeData != null) {
            final empId = employeeData['id'] as String?;
            print('PerformanceService: Found employee_id from employees table: $empId');
            return empId;
          }
        } catch (e) {
          print('PerformanceService: Error checking employees table: $e');
        }
        
        print('PerformanceService: No profile found for user_id: $userId');
        return null;
      }

      final employeeId = profileData['employee_id'] as String?;
      final fullName = profileData['full_name'] as String?;
      
      print('PerformanceService: Profile data - employee_id: $employeeId, full_name: $fullName');

      if (employeeId == null || employeeId.isEmpty) {
        print('PerformanceService: No employee_id found in profile, trying to use user_id as employee_id...');
        // Some systems might use user_id directly as employee_id
        // Try querying goals with user_id directly
        try {
          final testGoals = await supabase
              .from('goals')
              .select('id')
              .eq('employee_id', userId)
              .limit(1);
          
          if (testGoals.isNotEmpty) {
            print('PerformanceService: Found goals using user_id as employee_id');
            return userId;
          }
        } catch (e) {
          print('PerformanceService: Error testing user_id as employee_id: $e');
        }
        
        print('PerformanceService: No employee_id found for user: $userId');
        return null;
      }

      print('PerformanceService: Successfully retrieved employee_id: $employeeId');
      return employeeId;
    } catch (e, stackTrace) {
      print('PerformanceService: Error getting employee_id: $e');
      print('PerformanceService: Stack trace: $stackTrace');
      return null;
    }
  }

  // Get employee performance data
  Future<Performance?> getEmployeePerformance(String userId) async {
    try {
      print('PerformanceService: Fetching performance for user: $userId');

      final employeeId = await _getEmployeeId(userId);
      if (employeeId == null) {
        print('PerformanceService: Cannot fetch performance without employee_id');
        return null;
      }

      // Try to fetch performance data
      try {
        final data = await supabase
            .from('employee_performance')
            .select('*')
            .eq('employee_id', employeeId)
            .maybeSingle();

        if (data == null) {
          print('PerformanceService: No performance data found');
          // Don't try to create default if table doesn't exist
          return null;
        }

        return Performance.fromJson(data);
      } catch (e) {
        // Table might not exist in new database
        if (e.toString().contains('PGRST205') || e.toString().contains('does not exist')) {
          print('PerformanceService: employee_performance table does not exist, returning null');
          return null;
        }
        rethrow;
      }
    } catch (e, stackTrace) {
      print('PerformanceService: Error fetching performance: $e');
      print('PerformanceService: Stack trace: $stackTrace');
      // Return null instead of throwing to allow UI to show empty state
      return null;
    }
  }

  // Create default performance record (not used if table doesn't exist)
  Future<Performance?> _createDefaultPerformance(String employeeId) async {
    try {
      final data = await supabase
          .from('employee_performance')
          .insert({
            'employee_id': employeeId,
            'total_xp': 0,
            'current_level': 1,
            'rank': 'Beginner',
            'xp_to_next_level': 100,
            'day_streak': 0,
            'badges_earned': [],
          })
          .select()
          .single();

      return Performance.fromJson(data);
    } catch (e) {
      print('PerformanceService: Error creating default performance: $e');
      // If table doesn't exist, return null
      return null;
    }
  }

  // Update XP and recalculate level
  Future<bool> updateXP(String userId, int xpToAdd) async {
    try {
      final employeeId = await _getEmployeeId(userId);
      if (employeeId == null) {
        print('PerformanceService: Cannot update XP without employee_id');
        return false;
      }

      final performance = await getEmployeePerformance(userId);
      if (performance == null) {
        print('PerformanceService: Cannot update XP - no performance record found');
        return false;
      }

      final newTotalXp = performance.totalXp + xpToAdd;
      final newLevel = Performance.calculateLevel(newTotalXp);
      final newRank = Performance.getRankForLevel(newLevel);
      final xpForNextLevel = Performance.getXpForNextLevel(newLevel);
      final xpToNextLevel = xpForNextLevel - newTotalXp;

      await supabase
          .from('employee_performance')
          .update({
            'total_xp': newTotalXp,
            'current_level': newLevel,
            'rank': newRank,
            'xp_to_next_level': xpToNextLevel,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('employee_id', employeeId);

      // Add activity feed entry
      await _addActivityFeed(
        employeeId,
        'xp_earned',
        'Earned +$xpToAdd XP',
        null,
      );

      return true;
    } catch (e) {
      print('PerformanceService: Error updating XP: $e');
      return false;
    }
  }

  // Get goals for employee
  Future<List<Goal>> getGoals(String userId, {GoalStatus? statusFilter, GoalType? typeFilter}) async {
    try {
      print('\n🔵 ========== FETCHING GOALS ==========');
      print('🔵 User ID: $userId');

      // First, check if Supabase is connected
      try {
        final currentUser = supabase.auth.currentUser;
        if (currentUser == null) {
          print('🔵 ⚠️ No authenticated user found');
        } else {
          print('🔵 ✅ Authenticated user: ${currentUser.id}');
        }
      } catch (e) {
        print('🔵 ❌ ERROR: Cannot access Supabase auth: $e');
        print('🔵 This might be a network connectivity issue');
        return [];
      }

      // First, test if we can access the goals table at all
      print('🔵 Step 1: Testing goals table access...');
      try {
        final testAccess = await supabase
            .from('goals')
            .select('id, title, employee_id')
            .limit(5)
            .timeout(const Duration(seconds: 10));
        print('🔵 ✅ Goals table is accessible! Found ${testAccess.length} goals');
        if (testAccess.isNotEmpty) {
          print('🔵 Sample goals:');
          for (var goal in testAccess) {
            print('  - ID: ${goal['id']}, Title: ${goal['title']}, Employee ID: ${goal['employee_id']}');
          }
        }
      } catch (e) {
        final errorStr = e.toString();
        if (errorStr.contains('Failed host lookup') || 
            errorStr.contains('SocketException') ||
            errorStr.contains('Network is unreachable')) {
          print('🔵 ❌ NETWORK ERROR: Cannot connect to Supabase');
          print('🔵 Please check your internet connection');
          print('🔵 Error: $e');
          return [];
        }
        print('🔵 ❌ ERROR: Cannot access goals table: $e');
        print('🔵 This might be an RLS (Row Level Security) issue');
        return [];
      }

      final employeeId = await _getEmployeeId(userId);
      print('🔵 Step 2: Employee ID lookup result: $employeeId');
      
      if (employeeId == null) {
        print('🔵 ❌ CRITICAL: employee_id is NULL!');
        print('🔵 Cannot fetch goals without employee_id');
        print('🔵 User ID: $userId');
        print('🔵 Please check if user_profiles table has employee_id for this user');
        return [];
      }
      
      // Try multiple approaches to fetch goals
      List<dynamic> allGoalsData = [];
      
      // Approach 1: Try with employee_id (goals table uses employee_id, not user_id)
      print('🔵 Step 3: Trying to fetch goals with employee_id: $employeeId');
      try {
        var query = supabase
            .from('goals')
            .select('*')
            .eq('employee_id', employeeId);
        
        if (statusFilter != null) {
          query = query.eq('status', statusFilter.name.toUpperCase());
        }
        if (typeFilter != null) {
          query = query.eq('type', typeFilter.name.toUpperCase());
        }
        
        print('🔵 Executing query: SELECT * FROM goals WHERE employee_id = $employeeId');
          final data = await query.order('end_date', ascending: true).timeout(const Duration(seconds: 10));
        print('🔵 ✅ Query successful! Found ${data.length} goals with employee_id: $employeeId');
        if (data.isNotEmpty) {
          allGoalsData = data;
          print('🔵 First goal details:');
          print('  - ID: ${data[0]['id']}');
          print('  - Title: ${data[0]['title']}');
          print('  - Employee ID: ${data[0]['employee_id']}');
          print('  - Status: ${data[0]['status']}');
          print('  - Progress: ${data[0]['progress']}');
        } else {
          print('🔵 ⚠️ Query returned 0 results for employee_id: $employeeId');
        }
      } catch (e) {
        final errorStr = e.toString();
        if (errorStr.contains('Failed host lookup') || 
            errorStr.contains('SocketException') ||
            errorStr.contains('Network is unreachable')) {
          print('🔵 ❌ NETWORK ERROR: Cannot fetch goals');
          return [];
        }
        print('🔵 ❌ Error with employee_id query: $e');
        print('🔵 Employee ID used: $employeeId');
      }
      
      // Approach 2: Get all goals and filter in code (for debugging and fallback)
      if (allGoalsData.isEmpty) {
        print('🔵 Step 4: Fetching all goals to debug (fallback approach)...');
        try {
          final allGoals = await supabase
              .from('goals')
              .select('*')
              .limit(100)
              .timeout(const Duration(seconds: 10));
          print('🔵 Total goals accessible in database: ${allGoals.length}');
          
          if (allGoals.isNotEmpty) {
            print('🔵 Sample goal structure:');
            print('  Columns: ${allGoals[0].keys.toList()}');
            print('  First goal data: ${allGoals[0]}');
            
            // Show all employee_id values
            final employeeIds = allGoals.map((g) => g['employee_id']).toSet();
            print('🔵 All Employee IDs found in goals table: $employeeIds');
            print('🔵 Looking for employee_id: $employeeId (type: ${employeeId.runtimeType})');
            
            // Show data types
            if (allGoals.isNotEmpty) {
              final firstEmpId = allGoals[0]['employee_id'];
              print('🔵 First goal employee_id type: ${firstEmpId.runtimeType}, value: $firstEmpId');
            }
          }
          
          // Filter by employee_id in code (with type conversion)
          for (var goal in allGoals) {
            final goalEmployeeId = goal['employee_id'];
            final goalEmployeeIdStr = goalEmployeeId?.toString();
            final employeeIdStr = employeeId.toString();
            
            print('🔵 Comparing: goal.employee_id="$goalEmployeeIdStr" (${goalEmployeeId.runtimeType}) vs looking for="$employeeIdStr" (${employeeId.runtimeType})');
            
            if (goalEmployeeIdStr == employeeIdStr) {
              allGoalsData.add(goal);
              print('🔵 ✅ Match found! Goal: ${goal['title']}');
            }
          }
          print('🔵 Found ${allGoalsData.length} matching goals after filtering');
        } catch (e) {
          final errorStr = e.toString();
          if (errorStr.contains('Failed host lookup') || 
              errorStr.contains('SocketException') ||
              errorStr.contains('Network is unreachable')) {
            print('🔵 ❌ NETWORK ERROR: Cannot fetch goals');
            return [];
          }
          print('🔵 ❌ Error fetching all goals: $e');
          print('🔵 This might indicate RLS (Row Level Security) is blocking access');
        }
      }
      
      if (allGoalsData.isEmpty) {
        print('🔵 ❌ No goals found after all approaches');
        print('🔵 Possible reasons:');
        print('  1. No goals exist for this user/employee');
        print('  2. RLS policies are blocking access');
        print('  3. Column names don\'t match (user_id vs employee_id)');
        print('  4. Data type mismatch (UUID vs String)');
        print('🔵 ==========================================\n');
        return [];
      }

      final data = allGoalsData;

      print('PerformanceService: ✅ Successfully found ${data.length} goals');
      if (data.isNotEmpty) {
        print('PerformanceService: First goal sample: ${data[0]}');
      }

      print('🔵 Step 4: Parsing ${data.length} goals...');
      final List<Goal> goals = [];
      for (int i = 0; i < data.length; i++) {
        final json = data[i];
        try {
          print('🔵 Parsing goal ${i + 1}/${data.length}:');
          print('  - ID: ${json['id']}');
          print('  - Title: ${json['title']}');
          print('  - Status: ${json['status']}');
          print('  - Progress: ${json['progress']}');
          print('  - Employee ID: ${json['employee_id']}');
          print('  - User ID: ${json['user_id']}');
          print('  - All fields: ${json.keys.toList()}');
          
          final goal = Goal.fromJson(json);
          goals.add(goal);
          print('🔵 ✅ Successfully parsed: ${goal.title} (${goal.status.displayName}, ${goal.progress}%)');
        } catch (e, stackTrace) {
          print('🔵 ❌ ERROR parsing goal ${i + 1}: $e');
          print('🔵 Goal data: $json');
          print('🔵 Stack trace: $stackTrace');
          // Continue with other goals instead of failing completely
        }
      }

      print('🔵 ========== GOALS FETCH COMPLETE ==========');
      print('🔵 Successfully parsed ${goals.length} out of ${data.length} goals');
      if (goals.isEmpty && data.isNotEmpty) {
        print('🔵 ⚠️ WARNING: All goals failed to parse! Check the errors above.');
      }
      print('');
      return goals;
    } catch (e, stackTrace) {
      print('PerformanceService: Error fetching goals: $e');
      print('PerformanceService: Stack trace: $stackTrace');
      return [];
    }
  }

  // Update goal progress
  Future<bool> updateGoalProgress(String goalId, int progress) async {
    try {
      await supabase
          .from('goals')
          .update({
            'progress': progress,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', goalId);

      return true;
    } catch (e) {
      print('PerformanceService: Error updating goal progress: $e');
      return false;
    }
  }

  // Complete goal and award XP
  Future<bool> completeGoal(String goalId, String userId) async {
    try {
      final employeeId = await _getEmployeeId(userId);
      if (employeeId == null) {
        print('PerformanceService: Cannot complete goal without employee_id');
        return false;
      }

      // Get goal details
      final goalData = await supabase
          .from('goals')
          .select('*')
          .eq('id', goalId)
          .eq('employee_id', employeeId) // Ensure goal belongs to employee
          .single();

      final goal = Goal.fromJson(goalData);

      // Update goal status
      await supabase
          .from('goals')
          .update({
            'status': 'COMPLETED',
            'progress': 100,
            'completed_date': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', goalId)
          .eq('employee_id', employeeId);

      // Award XP
      await updateXP(userId, goal.xpReward);

      // Award 100 loyalty points for goal completion
      await LoyaltyService().awardPoints(
        employeeId: employeeId,
        points: 100,
        type: 'goal_completion',
        description: 'Completed goal: ${goal.title}',
        referenceId: goalId,
      );

      // Add activity feed
      await _addActivityFeed(
        employeeId,
        'goal_completed',
        'Completed goal: ${goal.title}',
        goalId,
      );

      return true;
    } catch (e) {
      print('PerformanceService: Error completing goal: $e');
      return false;
    }
  }

  // Get badges for employee
  Future<List<model.Badge>> getBadges(String userId) async {
    try {
      final employeeId = await _getEmployeeId(userId);
      if (employeeId == null) {
        print('PerformanceService: Cannot fetch badges without employee_id');
        return [];
      }

      // Try to fetch earned badges with badge details
      try {
        final data = await supabase
            .from('employee_badges')
            .select('*, badges(*)')
            .eq('employee_id', employeeId)
            .order('earned_date', ascending: false);

        if (data.isEmpty) {
          print('PerformanceService: No badges found for employee: $employeeId');
          return [];
        }

        return (data as List).map((json) {
          try {
            final badgeData = json['badges'];
            if (badgeData == null) {
              print('PerformanceService: Badge data is null for employee_badge: ${json['id']}');
              return null;
            }
            return model.Badge.fromJson({
              ...(badgeData as Map<String, dynamic>),
              'earned_date': json['earned_date'],
            });
        } catch (e) {
          print('PerformanceService: Error parsing badge: $e');
          return null;
        }
      }).whereType<model.Badge>().toList();
      } catch (e) {
        // Table might not exist in new database
        if (e.toString().contains('PGRST205') || e.toString().contains('does not exist')) {
          print('PerformanceService: employee_badges table does not exist, returning empty list');
          return [];
        }
        rethrow;
      }
    } catch (e) {
      print('PerformanceService: Error fetching badges: $e');
      return [];
    }
  }

  // Get performance reviews
  Future<List<PerformanceReview>> getReviews(String userId) async {
    try {
      final employeeId = await _getEmployeeId(userId);
      if (employeeId == null) {
        print('PerformanceService: Cannot fetch reviews without employee_id');
        return [];
      }

      // Try to fetch reviews with joins to get reviewer information
      List<dynamic> data;
      try {
        // First try with joins to get reviewer name
        try {
          data = await supabase
              .from('performance_reviews')
              .select('''
                *,
                reviewer:user_profiles!reviewer_id(full_name, email),
                goal:goals!goal_id(title)
              ''')
              .eq('employee_id', employeeId)
              .order('created_at', ascending: false);
        } catch (e) {
          print('PerformanceService: Join query failed, trying simple query: $e');
          // Fallback to simple query
          data = await supabase
              .from('performance_reviews')
              .select('*')
              .eq('employee_id', employeeId)
              .order('created_at', ascending: false);
        }
      } catch (e) {
        print('PerformanceService: Error fetching reviews: $e');
        return [];
      }

      if (data.isEmpty) {
        print('PerformanceService: No reviews found for employee: $employeeId');
        return [];
      }

      print('PerformanceService: Found ${data.length} reviews for employee: $employeeId');

      // Process reviews and fetch reviewer names
      final List<PerformanceReview> reviews = [];
      
      for (final json in data) {
        try {
          // Safely extract reviewer name
          String? reviewerName;
          
          // Try to get reviewer name from joined data
          if (json['reviewer'] != null) {
            if (json['reviewer'] is Map) {
              reviewerName = json['reviewer']?['full_name'] as String?;
            } else if (json['reviewer'] is List && (json['reviewer'] as List).isNotEmpty) {
              reviewerName = (json['reviewer'] as List)[0]?['full_name'] as String?;
            }
          }
          
          // If reviewer name not found, try to fetch it directly
          if ((reviewerName == null || reviewerName.isEmpty) && json['reviewer_id'] != null) {
            final reviewerId = json['reviewer_id'] as String;
            try {
              // Try to get from user_profiles first
              final profile = await supabase
                  .from('user_profiles')
                  .select('full_name, employee_id')
                  .eq('user_id', reviewerId)
                  .maybeSingle();
              
              if (profile != null && profile['full_name'] != null) {
                reviewerName = profile['full_name'] as String;
              } else if (profile != null && profile['employee_id'] != null) {
                // If not found in user_profiles, try employees table
                final employeeId = profile['employee_id'] as String;
                final employee = await supabase
                    .from('employees')
                    .select('full_name')
                    .eq('id', employeeId)
                    .maybeSingle();
                
                if (employee != null && employee['full_name'] != null) {
                  reviewerName = employee['full_name'] as String;
                }
              }
            } catch (e) {
              print('PerformanceService: Error fetching reviewer name: $e');
            }
            
            // If still not found, try employees table directly
            if ((reviewerName == null || reviewerName.isEmpty)) {
              try {
                final employee = await supabase
                    .from('employees')
                    .select('full_name')
                    .eq('id', reviewerId)
                    .maybeSingle();
                
                if (employee != null && employee['full_name'] != null) {
                  reviewerName = employee['full_name'] as String;
                }
              } catch (e) {
                print('PerformanceService: Error checking employees table: $e');
              }
            }
          }
          
          reviewerName ??= json['reviewer_name'] as String?;
          reviewerName ??= 'Not specified';
          
          // Try to get goal title
          String? goalTitle;
          if (json['goal'] != null) {
            if (json['goal'] is Map) {
              goalTitle = json['goal']?['title'] as String?;
            } else if (json['goal'] is List && (json['goal'] as List).isNotEmpty) {
              goalTitle = (json['goal'] as List)[0]?['title'] as String?;
            }
          }
          
          // If goal_id exists but goal title not found, try to fetch it
          if ((goalTitle == null || goalTitle.isEmpty) && json['goal_id'] != null) {
            try {
              final goalId = json['goal_id'] as String;
              final goal = await supabase
                  .from('goals')
                  .select('title')
                  .eq('id', goalId)
                  .maybeSingle();
              
              if (goal != null && goal['title'] != null) {
                goalTitle = goal['title'] as String;
              }
            } catch (e) {
              print('PerformanceService: Error fetching goal title: $e');
            }
          }
          
          // Debug rating field - print all fields to see what's available
          print('PerformanceService: Review - reviewer: $reviewerName, period: ${json['period']}');
          print('PerformanceService: All review fields: ${json.keys.toList()}');
          print('PerformanceService: Rating values - rating: ${json['rating']} (${json['rating']?.runtimeType}), overall_rating: ${json['overall_rating']} (${json['overall_rating']?.runtimeType})');
          print('PerformanceService: Full review data: $json');
          
          reviews.add(PerformanceReview.fromJson({
            ...json,
            'reviewer_name': reviewerName,
            'goal_title': goalTitle,
          }));
        } catch (e, stackTrace) {
          print('PerformanceService: Error parsing review: $e');
          print('Review data: $json');
          print('Stack trace: $stackTrace');
        }
      }
      
      return reviews;
    } catch (e) {
      print('PerformanceService: Error fetching reviews: $e');
      return [];
    }
  }

  // Get recent activity feed
  Future<List<Map<String, dynamic>>> getRecentActivity(String userId, {int limit = 10}) async {
    try {
      final employeeId = await _getEmployeeId(userId);
      if (employeeId == null) {
        print('PerformanceService: Cannot fetch activity without employee_id');
        return [];
      }

      try {
        final data = await supabase
            .from('activity_feed')
            .select('*')
            .eq('employee_id', employeeId)
            .order('created_at', ascending: false)
            .limit(limit);

        if (data.isEmpty) {
          print('PerformanceService: No activity found for employee: $employeeId');
          return [];
        }

        return (data as List).cast<Map<String, dynamic>>();
      } catch (e) {
        // Table might not exist in new database
        if (e.toString().contains('PGRST205') || e.toString().contains('does not exist')) {
          print('PerformanceService: activity_feed table does not exist, returning empty list');
          return [];
        }
        rethrow;
      }
    } catch (e) {
      print('PerformanceService: Error fetching activity: $e');
      return [];
    }
  }

  // Add activity feed entry
  Future<void> _addActivityFeed(
    String employeeId,
    String activityType,
    String description,
    String? relatedId,
  ) async {
    try {
      await supabase.from('activity_feed').insert({
        'employee_id': employeeId,
        'activity_type': activityType,
        'description': description,
        'related_id': relatedId,
      });
    } catch (e) {
      print('PerformanceService: Error adding activity: $e');
    }
  }

  // Get performance stats
  Future<Map<String, dynamic>> getPerformanceStats(String userId) async {
    try {
      final employeeId = await _getEmployeeId(userId);
      if (employeeId == null) {
        print('PerformanceService: Cannot fetch stats without employee_id');
        return {
          'activeGoals': 0,
          'completed': 0,
          'overdue': 0,
          'avgProgress': 0.0,
          'avgRating': 0.0,
          'tasksDone': 0,
        };
      }

      final goals = await getGoals(userId);
      
      final activeGoals = goals.where((g) => g.status == GoalStatus.active).length;
      final completedGoals = goals.where((g) => g.status == GoalStatus.completed).length;
      final overdueGoals = goals.where((g) => g.isOverdue).length;
      
      final avgProgress = goals.isEmpty 
          ? 0.0 
          : goals.map((g) => g.progress).reduce((a, b) => a + b) / goals.length;

      final reviews = await getReviews(userId);
      final avgRating = reviews.isEmpty
          ? 0.0
          : reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;

      // Get completed tasks count from tasks table
      int tasksDone = 0;
      try {
        final tasksData = await supabase
            .from('tasks')
            .select('id')
            .eq('assigned_to', employeeId)
            .eq('status', 'completed');
        tasksDone = (tasksData as List).length;
      } catch (e) {
        print('PerformanceService: Error fetching tasks count: $e');
        tasksDone = 0;
      }

      return {
        'activeGoals': activeGoals,
        'completed': completedGoals,
        'overdue': overdueGoals,
        'avgProgress': avgProgress.roundToDouble(),
        'avgRating': avgRating.roundToDouble(),
        'tasksDone': tasksDone,
      };
    } catch (e) {
      print('PerformanceService: Error fetching stats: $e');
      return {
        'activeGoals': 0,
        'completed': 0,
        'overdue': 0,
        'avgProgress': 0.0,
        'avgRating': 0.0,
        'tasksDone': 0,
      };
    }
  }
}

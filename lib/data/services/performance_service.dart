import 'package:loghr_mobile/config/api_client.dart';
import 'package:loghr_mobile/data/models/performance.dart';
import 'package:loghr_mobile/data/models/goal.dart';
import 'package:loghr_mobile/data/models/badge.dart' as model;
import 'package:loghr_mobile/data/models/performance_review.dart';

class PerformanceService {
  // Get employee performance data
  Future<Performance?> getEmployeePerformance(String userId) async {
    // Return a mock performance details since employee_performance is not in the DB
    return Performance(
      id: 'mock-performance-$userId',
      employeeId: userId,
      totalXp: 150,
      currentLevel: 2,
      rank: 'Intermediate',
      xpToNextLevel: 50,
      dayStreak: 3,
      badgesEarned: const [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  // Update XP and recalculate level
  Future<bool> updateXP(String userId, int xpToAdd) async {
    return true; // Mock success
  }

  // Get goals for employee
  Future<List<Goal>> getGoals(String userId, {GoalStatus? statusFilter, GoalType? typeFilter}) async {
    try {
      final response = await api.get('/misc/performance/goals');
      if (response == null) return [];
      
      final list = response as List;
      final parsed = list.map((json) {
        // Map progress_percentage back to progress for the model compatibility
        final map = Map<String, dynamic>.from(json);
        map['progress'] = json['progress_percentage'] ?? 0;
        map['status'] = (json['status']?.toString() ?? 'not_started').toUpperCase();
        return Goal.fromJson(map);
      }).toList();

      if (statusFilter != null) {
        return parsed.where((g) => g.status == statusFilter).toList();
      }
      return parsed;
    } catch (e) {
      print('Error fetching goals: $e');
      return [];
    }
  }

  // Get goal details by ID (including names of assignee, department, and creator)
  Future<Map<String, dynamic>?> getGoalDetails(String goalId) async {
    try {
      final response = await api.get('/misc/performance/goals/$goalId');
      return response as Map<String, dynamic>?;
    } catch (e) {
      print('Error fetching goal details: $e');
      return null;
    }
  }

  // Get goal comments
  Future<List<Map<String, dynamic>>> getGoalComments(String goalId) async {
    try {
      final response = await api.get('/misc/performance/goals/$goalId/comments');
      if (response == null) return [];
      final list = response as List;
      return list.map((json) => Map<String, dynamic>.from(json)).toList();
    } catch (e) {
      print('Error fetching goal comments: $e');
      return [];
    }
  }

  // Add goal comment
  Future<bool> addGoalComment(String goalId, String comment) async {
    try {
      final response = await api.post('/misc/performance/goals/$goalId/comments', {
        'comment': comment,
      });
      return response != null;
    } catch (e) {
      print('Error adding goal comment: $e');
      return false;
    }
  }

  // Update goal progress
  Future<bool> updateGoalProgress(String goalId, int progress) async {
    try {
      final response = await api.post('/misc/performance/goals/$goalId/progress', {
        'progress': progress,
      });
      return response != null;
    } catch (e) {
      print('Error updating goal progress: $e');
      return false;
    }
  }

  // Complete goal and award XP
  Future<bool> completeGoal(String goalId, String userId) async {
    try {
      final response = await api.post('/misc/performance/goals/$goalId/complete', {});
      return response != null;
    } catch (e) {
      print('Error completing goal: $e');
      return false;
    }
  }

  // Get badges for employee
  Future<List<model.Badge>> getBadges(String userId) async {
    return []; // Return empty badges roster since badges table is deprecated
  }

  // Get performance reviews
  Future<List<PerformanceReview>> getReviews(String userId) async {
    try {
      final response = await api.get('/misc/performance/reviews');
      if (response == null) return [];
      
      final list = response as List;
      return list.map((json) {
        final map = Map<String, dynamic>.from(json);
        map['reviewer_name'] = json['reviewer_name'] ?? 'HR Manager';
        map['rating'] = double.tryParse(json['final_rating']?.toString() ?? json['manager_rating']?.toString() ?? '4.0') ?? 4.0;
        return PerformanceReview.fromJson(map);
      }).toList();
    } catch (e) {
      print('Error fetching performance reviews: $e');
      return [];
    }
  }

  // Get recent activity feed
  Future<List<Map<String, dynamic>>> getRecentActivity(String userId, {int limit = 10}) async {
    return []; // Return empty feed since activity_feed table is deprecated
  }

  // Get performance stats
  Future<Map<String, dynamic>> getPerformanceStats(String userId) async {
    try {
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

      return {
        'activeGoals': activeGoals,
        'completed': completedGoals,
        'overdue': overdueGoals,
        'avgProgress': avgProgress.roundToDouble(),
        'avgRating': avgRating.roundToDouble(),
        'tasksDone': completedGoals, // Use completed goals as proxy for engagement tasks
      };
    } catch (e) {
      print('Error fetching performance stats: $e');
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

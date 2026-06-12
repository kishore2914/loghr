import 'package:flutter/material.dart';
import 'package:loghr_mobile/ui/widgets/dashboard_widgets.dart';

class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  // Mock data - replace with actual data from provider
  int _availableCourses = 0;
  int _enrolled = 0;
  int _completed = 0;
  int _certifications = 0;

  @override
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F1724);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Training',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Courses & Learning Paths',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New Course'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                childAspectRatio: 1.1,
                children: [
                  DashboardStatCard(
                    title: 'Available',
                    value: '$_availableCourses',
                    subValue: 'Courses',
                    icon: Icons.menu_book,
                    baseColor: Colors.blue.shade700,
                    backgroundColor: Colors.blue.shade50,
                  ),
                  DashboardStatCard(
                    title: 'Enrolled',
                    value: '$_enrolled',
                    subValue: 'Courses',
                    icon: Icons.person_outline,
                    baseColor: Colors.orange.shade700,
                    backgroundColor: Colors.orange.shade50,
                  ),
                  DashboardStatCard(
                    title: 'Completed',
                    value: '$_completed',
                    subValue: 'Courses',
                    icon: Icons.check_circle_outline,
                    baseColor: Colors.green.shade700,
                    backgroundColor: Colors.green.shade50,
                  ),
                  DashboardStatCard(
                    title: 'Certificates',
                    value: '$_certifications',
                    subValue: 'Earned',
                    icon: Icons.verified_outlined,
                    baseColor: Colors.purple.shade700,
                    backgroundColor: Colors.purple.shade50,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Main Content Area
              Card(
                elevation: 2,
                color: cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide.none,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.blue.withOpacity(0.2) : Colors.blue.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.school_outlined,
                          size: 64,
                          color: Colors.blue.shade300,
                        ),
                      ),
                      const SizedBox(height: 32),
                       Text(
                        'Learning Center',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Create courses, track enrollments, and manage certifications through the admin portal.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                         decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade100),
                        ),
                        child: Text(
                          'Coming Soon',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

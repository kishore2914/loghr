import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// --- Stat Card ---

class DashboardStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subValue;
  final IconData icon;
  final Color baseColor; // The main theme color for this card (icon, text)
  final Color backgroundColor; // The pastel background
  final List<Color>? gradient; // Optional gradient

  const DashboardStatCard({
    Key? key,
    required this.title,
    required this.value,
    required this.icon,
    required this.baseColor,
    required this.backgroundColor,
    this.subValue,
    this.gradient,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Adjust colors for dark mode
    final cardBgByTheme = isDark ? const Color(0xFF1E1E1E) : backgroundColor;
    final iconBgByTheme = isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.6);
    final titleColor = isDark ? Colors.grey.shade400 : baseColor.withOpacity(0.8);
    final valueColor = isDark ? Colors.white : baseColor;
    final subValueColor = isDark ? Colors.grey.shade600 : baseColor.withOpacity(0.6);

    return Container(
      decoration: BoxDecoration(
        color: gradient == null ? cardBgByTheme : null,
        gradient: gradient != null && !isDark 
            ? LinearGradient(
                colors: gradient!,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ) 
            : null,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: Colors.white.withOpacity(0.05)) : null,
        boxShadow: !isDark ? [
           BoxShadow(
            color: baseColor.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ] : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBgByTheme,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: baseColor, size: 20),
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: titleColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: valueColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subValue != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      subValue!,
                      style: TextStyle(
                        color: subValueColor,
                        fontSize: 12,
                        overflow: TextOverflow.ellipsis,
                      ),
                      maxLines: 1,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
}

// --- Payroll Summary Section ---

class PayrollSummarySection extends StatelessWidget {
  final double totalAmount;
  final int paidCount;
  final int pendingCount;
  final int processingCount;
  final String currency;

  const PayrollSummarySection({
    Key? key,
    this.totalAmount = 0.0,
    this.paidCount = 0,
    this.pendingCount = 0,
    this.processingCount = 0,
    this.currency = 'INR',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 0,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: isDark ? BorderSide(color: Colors.white.withOpacity(0.05)) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: const Text(
                    'Monthly Payroll Summary',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('MMMM yyyy').format(DateTime.now()),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                // Determine if we should split into 2 rows of 2 or 1 row of 4 based on width
                // For mobile, grid or column is usually safer.
                return GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: [
                    _buildSummaryItem(
                      label: 'Total Amount',
                      value: NumberFormat('#,###').format(totalAmount),
                      subLabel: currency,
                      bgColor: Colors.blue.shade50,
                      accColor: Colors.blue.shade700,
                    ),
                    _buildSummaryItem(
                      label: 'Paid',
                      value: '$paidCount',
                      subLabel: 'Employees',
                      bgColor: Colors.green.shade50,
                      accColor: Colors.green.shade700,
                    ),
                    _buildSummaryItem(
                      label: 'Pending',
                      value: '$pendingCount',
                      subLabel: 'Payments',
                      bgColor: Colors.orange.shade50,
                      accColor: Colors.orange.shade800,
                    ),
                    _buildSummaryItem(
                      label: 'Processing',
                      value: '$processingCount',
                      subLabel: 'This Month',
                      bgColor: Colors.purple.shade50,
                      accColor: Colors.purple.shade700,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem({
    required String label,
    required String value,
    required String subLabel,
    required Color bgColor,
    required Color accColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(child: Text(label, style: TextStyle(color: accColor.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis, maxLines: 1)),
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(color: accColor, fontSize: 18, fontWeight: FontWeight.bold))),
          Flexible(child: Text(subLabel, style: TextStyle(color: accColor.withOpacity(0.8), fontSize: 11), overflow: TextOverflow.ellipsis, maxLines: 1)),
        ],
      ),
    );
  }
}

// --- List Tile (Salary/General) ---

class DashboardListTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String trailing;
  final Color dotColor;

  const DashboardListTile({
    Key? key,
    required this.title,
    this.subtitle,
    required this.trailing,
    required this.dotColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis, maxLines: 1),
                      if (subtitle != null)
                        Text(subtitle!, style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 11), overflow: TextOverflow.ellipsis, maxLines: 1),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(trailing, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}

// --- Salary Due List ---

class SalaryDueList extends StatelessWidget {
  final List<Map<String, dynamic>> salaryDueList;

  const SalaryDueList({
    Key? key,
    this.salaryDueList = const [],
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 0,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: isDark ? BorderSide(color: Colors.white.withOpacity(0.05)) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Salary Due List', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (salaryDueList.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Center(
                  child: Text('No pending salaries', style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              ...salaryDueList.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final name = item['name'] as String? ?? 'Unknown';
                final amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
                final currency = item['currency'] as String? ?? 'INR';
                final formattedAmount = NumberFormat('#,###').format(amount);
                
                return Column(
                  children: [
                    if (index > 0) const Divider(height: 1),
                    DashboardListTile(
                      title: name,
                      trailing: '$formattedAmount $currency',
                      dotColor: Colors.orange,
                    ),
                  ],
                );
              }).toList(),
          ],
        ),
      ),
    );
  }
}

// --- Upcoming Birthdays ---

class UpcomingBirthdaysCard extends StatelessWidget {
  final List<Map<String, dynamic>> birthdays;

  const UpcomingBirthdaysCard({
    Key? key,
    this.birthdays = const [],
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.pink.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.cake, color: Colors.pink.shade400, size: 20),
                ),
                const SizedBox(width: 12),
                const Text('Upcoming Birthdays', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 24),
            if (birthdays.isEmpty)
              const Center(
                child: Text('No birthdays this week', style: TextStyle(color: Colors.grey)),
              )
            else
              ...birthdays.map((birthday) {
                final name = birthday['name'] as String? ?? 'Unknown';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
                );
              }).toList(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// --- Leave Balance ---

class LeaveBalanceCard extends StatelessWidget {
  final List<Map<String, dynamic>> leaveBalances;

  const LeaveBalanceCard({
    Key? key,
    this.leaveBalances = const [],
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.calendar_today, color: Colors.orange.shade700, size: 20),
                ),
                const SizedBox(width: 12),
                const Text('Leave Balance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 20),
            if (leaveBalances.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text('No leave balance data', style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              ...leaveBalances.asMap().entries.map((entry) {
                final index = entry.key;
                final balance = entry.value;
                final name = balance['name'] as String? ?? 'Unknown';
                final annual = balance['annual'] as int? ?? 0;
                final sick = balance['sick'] as int? ?? 0;
                
                return Column(
                  children: [
                    if (index > 0) const SizedBox(height: 16),
                    _employeeLeaveRow(name, annual, sick),
                  ],
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _employeeLeaveRow(String name, int annual, int sick) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                child: Column(
                  children: [
                    Text('Annual', style: TextStyle(color: Colors.blue.shade800, fontSize: 10)),
                    Text('$annual', style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                child: Column(
                  children: [
                    Text('Sick', style: TextStyle(color: Colors.green.shade800, fontSize: 10)),
                    Text('$sick', style: TextStyle(color: Colors.green.shade900, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

class PayslipScreen extends StatefulWidget {
  final VoidCallback? onToggleTheme;
  final ThemeMode? themeMode;
  const PayslipScreen({Key? key, this.onToggleTheme, this.themeMode}) : super(key: key);

  @override
  State<PayslipScreen> createState() => _PayslipScreenState();
}

class _PayslipScreenState extends State<PayslipScreen> {
  bool _showValues = true;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: [
                // Top Navigation
                _buildTopBar(context, isDark),

                // Scrollable content
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 16),
                    children: [
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _latestSalaryCard(primary, isDark),
                      ),
                      const SizedBox(height: 12),

                      // 2024 Section
                      _buildYearSection(context, title: '2024', items: _sample2024()),

                      const SizedBox(height: 24),

                      // 2023 Section
                      _buildYearSection(context, title: '2023', items: _sample2023()),

                      const SizedBox(height: 36),
                    ],
                  ),
                ),

                // Bottom Tab Bar
                _bottomTabBar(context, primary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
        border: Border(bottom: BorderSide(color: isDark ? Colors.white12 : Colors.black12)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.arrow_back_ios_new),
            tooltip: 'Back',
          ),
          const Expanded(
            child: Center(
              child: Text(
                'My Payslips',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _showValues = !_showValues;
              });
            },
            icon: Icon(_showValues ? Icons.visibility : Icons.visibility_off),
            tooltip: 'Toggle Values',
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter',
          ),
          // theme toggle button (small)
          if (widget.onToggleTheme != null)
            IconButton(
              onPressed: widget.onToggleTheme,
              icon: Icon(widget.themeMode == ThemeMode.light ? Icons.dark_mode : Icons.light_mode),
              tooltip: 'Toggle theme',
            ),
        ],
      ),
    );
  }

  Widget _latestSalaryCard(Color primary, bool isDark) {
    return Material(
      borderRadius: BorderRadius.circular(16),
      color: primary,
      elevation: 6,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Latest Net Salary', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text(_showValues ? '₹ 12,500' : '₹ ••••', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text('October 2024', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.account_balance_wallet, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: Colors.white24),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF34D399), shape: BoxShape.circle),),
                    const SizedBox(width: 8),
                    Text('Processed on Oct 30', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.18), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  icon: const Icon(Icons.arrow_forward, size: 16, color: Colors.white),
                  label: const Text('View Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYearSection(BuildContext context, {required String title, required List<PayslipItem> items}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
          child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black54)),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: items.map((it) => _payslipTile(it)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _payslipTile(PayslipItem item) {
    final theme = Theme.of(context);
    final isPaid = item.status.toLowerCase() == 'paid';
    return GestureDetector(
      onTap: () {},
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.cardColor.withOpacity(theme.brightness == Brightness.dark ? 0.8 : 1.0),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: theme.brightness == Brightness.dark ? Colors.black26 : Colors.black12, blurRadius: 6, offset: const Offset(0,2))
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: item.monthBoxColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(item.monthShort, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: item.monthTextColor)),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(item.monthFull, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isPaid ? const Color(0xFFF0FFF4) : const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isPaid ? const Color(0xFFDCFCE7) : const Color(0xFFFDE68A)),
                          ),
                          child: Text(item.status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isPaid ? const Color(0xFF047857) : const Color(0xFF92400E))),
                        )
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(item.subtitle, style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7))),
                  ],
                ),
              ],
            ),
            Row(
              children: [
                Text(_showValues ? item.amount : '••••', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _bottomTabBar(BuildContext context, Color primary) {
    final textColor = Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black45;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withOpacity(0.95),
        border: Border(top: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.white12 : Colors.black12)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.home, color: textColor),
              const SizedBox(height: 4),
              Text('Home', style: TextStyle(fontSize: 10, color: textColor)),
            ],
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.receipt_long, color: primary),
              const SizedBox(height: 4),
              Text('Payslips', style: TextStyle(fontSize: 10, color: primary)),
            ],
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person, color: textColor),
              const SizedBox(height: 4),
              Text('Profile', style: TextStyle(fontSize: 10, color: textColor)),
            ],
          ),
        ],
      ),
    );
  }

  List<PayslipItem> _sample2024() => [
    PayslipItem(monthShort: 'Oct', monthFull: 'October', status: 'Paid', subtitle: 'Paid on Oct 30', amount: '12,500', monthBoxColor: Colors.deepPurple.shade50, monthTextColor: Colors.deepPurple),
    PayslipItem(monthShort: 'Sep', monthFull: 'September', status: 'Paid', subtitle: 'Paid on Sep 28', amount: '12,500', monthBoxColor: Colors.grey.shade100, monthTextColor: Colors.grey.shade700),
    PayslipItem(monthShort: 'Aug', monthFull: 'August', status: 'Paid', subtitle: 'Paid on Aug 30', amount: '12,500', monthBoxColor: Colors.grey.shade100, monthTextColor: Colors.grey.shade700),
  ];

  List<PayslipItem> _sample2023() => [
    PayslipItem(monthShort: 'Dec', monthFull: 'December', status: 'Paid', subtitle: 'Paid on Dec 29', amount: '11,800', monthBoxColor: Colors.grey.shade100, monthTextColor: Colors.grey.shade700),
    PayslipItem(monthShort: 'Nov', monthFull: 'November', status: 'Pending', subtitle: 'Processing...', amount: '11,800', monthBoxColor: Colors.grey.shade100, monthTextColor: Colors.grey.shade700),
  ];
}

class PayslipItem {
  final String monthShort;
  final String monthFull;
  final String status;
  final String subtitle;
  final String amount;
  final Color monthBoxColor;
  final Color monthTextColor;

  PayslipItem({required this.monthShort, required this.monthFull, required this.status, required this.subtitle, required this.amount, required this.monthBoxColor, required this.monthTextColor});
}

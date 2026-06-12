import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:loghr_mobile/logic/auth_provider.dart';
import 'package:loghr_mobile/logic/loyalty_provider.dart';
import 'package:loghr_mobile/data/models/loyalty_card.dart';
import 'package:loghr_mobile/ui/widgets/loyalty_card_widget.dart';
import 'package:intl/intl.dart';

class LoyaltyScreen extends StatefulWidget {
  final VoidCallback? onNavigateToDashboard;

  const LoyaltyScreen({super.key, this.onNavigateToDashboard});

  @override
  State<LoyaltyScreen> createState() => _LoyaltyScreenState();
}

class _LoyaltyScreenState extends State<LoyaltyScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        context.read<LoyaltyProvider>().loadLoyaltyCard(user.id);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FD);
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.grey[400]! : Colors.grey;
    final borderColor = isDark ? Colors.white.withOpacity(0.1) : const Color(0xFFEEEEEE);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          padding: const EdgeInsets.only(top: 10),
          decoration: BoxDecoration(
            color: cardBg,
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: AppBar(
            backgroundColor: cardBg,
            elevation: 0,
            leading: widget.onNavigateToDashboard != null
                ? IconButton(
                    icon: Icon(Icons.arrow_back, color: textColor),
                    onPressed: widget.onNavigateToDashboard,
                  )
                : null,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade700,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.stars, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Loyalty & Rewards',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Manage your earning potential and history',
                  style: TextStyle(fontSize: 11, color: subTextColor, fontWeight: FontWeight.w500),
                ),
              ],
            ),

          ),
        ),
      ),
      body: Consumer<LoyaltyProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.loyaltyCard == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final card = provider.loyaltyCard;
          if (card == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.stars_outlined, size: 64, color: isDark ? Colors.grey[800] : Colors.grey.shade300),
                    const SizedBox(height: 24),
                    Text(
                      'No loyalty record found',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'We couldn\'t find or create your loyalty card. Please contact HR or try again later.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: subTextColor),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        final user = context.read<AuthProvider>().user;
                        if (user != null) {
                          provider.loadLoyaltyCard(user.id);
                        }
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;
              
              Widget mainContent = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Side: Card and Metrics
                  Expanded(
                    flex: isWide ? 4 : 1,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MEMBERSHIP CARD',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: subTextColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          LoyaltyCardWidget(
                            card: card,
                            onTap: () {},
                          ),
                          const SizedBox(height: 32),
                          Text(
                            'PERFORMANCE METRICS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: subTextColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildMetricCard(
                            label: 'ORG RANK',
                            value: '#1',
                            icon: Icons.trending_up,
                            iconColor: Colors.teal,
                            bgColor: isDark ? const Color(0xFF1B2E2A) : const Color(0xFFE8F5E9),
                            isDark: isDark,
                          ),
                          const SizedBox(height: 14),
                          _buildMetricCard(
                            label: 'LIFETIME POINTS',
                            value: '${card.points}',
                            icon: Icons.history,
                            iconColor: Colors.blue.shade700,
                            bgColor: isDark ? const Color(0xFF1A2633) : const Color(0xFFE3F2FD),
                            isDark: isDark,
                          ),
                          const SizedBox(height: 32),
                          _buildRedemptionNote(isDark),
                        ],
                      ),
                    ),
                  ),
                  
                  // Vertical Divider
                  if (isWide) Container(width: 1, color: borderColor, height: double.infinity),
                  
                  // Right Side: Tabs and Content
                  Expanded(
                    flex: isWide ? 6 : 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                          child: _buildTabBar(isDark),
                        ),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildHowToEarnTab(isDark),
                              _buildActivityLogTab(provider.transactions, isDark),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              if (!isWide && constraints.maxWidth < 600) {
                 // Simplified Column layout for small screens
                 // NestedScrollView for better scrolling behavior on small screens
                 mainContent = NestedScrollView(
                   headerSliverBuilder: (context, innerBoxIsScrolled) {
                     return [
                       SliverToBoxAdapter(
                         child: Padding(
                           padding: const EdgeInsets.all(24),
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               Text('MEMBERSHIP CARD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: subTextColor)),
                               const SizedBox(height: 12),
                               LoyaltyCardWidget(card: card, onTap: () {}),
                               const SizedBox(height: 24),
                               _buildMetricCard(label: 'ORG RANK', value: '#1', icon: Icons.trending_up, iconColor: Colors.teal, bgColor: isDark ? const Color(0xFF1B2E2A) : const Color(0xFFE8F5E9), isDark: isDark),
                               const SizedBox(height: 12),
                               _buildMetricCard(label: 'LIFETIME POINTS', value: '${card.points}', icon: Icons.history, iconColor: Colors.blue.shade700, bgColor: isDark ? const Color(0xFF1A2633) : const Color(0xFFE3F2FD), isDark: isDark),
                             ],
                           ),
                         ),
                       ),
                       SliverToBoxAdapter(
                         child: Padding(
                           padding: const EdgeInsets.symmetric(horizontal: 24),
                           child: _buildTabBar(isDark),
                         ),
                       ),
                     ];
                   },
                   body: TabBarView(
                     controller: _tabController,
                     children: [
                       _buildHowToEarnTab(isDark),
                       _buildActivityLogTab(provider.transactions, isDark),
                     ],
                   ),
                 );
              }

              return Container(
                margin: EdgeInsets.all(isWide ? 24 : 12),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: mainContent,
                ),
              );
            },
          );
        },
      ),

    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252525) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF0F0F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[500] : const Color(0xFFAAAAAA)),
              ),
              Text(
                value,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF222222)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRedemptionNote(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2633) : const Color(0xFFF5F9FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.blue.withOpacity(0.2) : const Color(0xFFE1EDFF)),
      ),
      child: Text(
        '* Redeem points for bonuses, leave, or gift cards via the HR department.',
        style: TextStyle(
          fontSize: 11,
          fontStyle: FontStyle.italic,
          color: isDark ? Colors.blue[300] : Colors.blue.shade800,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTabBar(bool isDark) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withOpacity(0.2) : const Color(0xFFF5F6F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: isDark ? const Color(0xFF333333) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        labelColor: const Color(0xFF2E5BFF),
        unselectedLabelColor: isDark ? Colors.grey[600] : Colors.grey.shade500,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: 'HOW TO EARN'),
          Tab(text: 'ACTIVITY LOG'),
        ],
      ),
    );
  }

  Widget _buildHowToEarnTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'REWARDS DISTRIBUTION PLAN',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: isDark ? Colors.grey[500] : const Color(0xFFAAAAAA), letterSpacing: 0.5),
        ),
        const SizedBox(height: 24),
        _buildEarnItem(
          icon: Icons.check_circle_outline,
          iconColor: const Color(0xFF2E5BFF),
          title: 'Task Completion',
          points: '+20 PTS',
          isDark: isDark,
        ),
        _buildEarnItem(
          icon: Icons.track_changes_outlined,
          iconColor: const Color(0xFF00C853),
          title: 'Objective Milestone',
          points: '+50 PTS',
          isDark: isDark,
        ),
        _buildEarnItem(
          icon: Icons.timer_outlined,
          iconColor: const Color(0xFF7C4DFF),
          title: 'Attendance Perfection',
          points: '+10 PTS',
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildEarnItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String points,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252525) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF0F0F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF333333)),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              points,
              style: TextStyle(color: iconColor, fontWeight: FontWeight.w900, fontSize: 12),
            ),
          ),
          const SizedBox(width: 10),
          Icon(Icons.chevron_right, color: isDark ? Colors.grey[700] : Colors.grey.shade300, size: 18),
        ],
      ),
    );
  }

  Widget _buildActivityLogTab(List<LoyaltyTransaction> transactions, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'STATEMENT OF POINTS',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: isDark ? Colors.grey[500] : const Color(0xFFAAAAAA)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isDark ? Colors.black.withOpacity(0.2) : const Color(0xFFF5F6F8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${transactions.length} ENTRIES',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: isDark ? Colors.grey[400] : const Color(0xFF666666)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (transactions.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Column(
                children: [
                   Icon(Icons.history_toggle_off, size: 40, color: isDark ? Colors.grey[800] : const Color(0xFFEEEEEE)),
                  const SizedBox(height: 12),
                  Text('No transactions yet.', style: TextStyle(color: isDark ? Colors.grey[700] : const Color(0xFFCCCCCC), fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          )
        else
          ...transactions.map((tx) => _buildTransactionItem(tx, isDark)),
      ],
    );
  }

  Widget _buildTransactionItem(LoyaltyTransaction tx, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252525) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF0F0F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withOpacity(0.1) : const Color(0xFFF5F6F8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.show_chart, color: isDark ? Colors.grey[600] : const Color(0xFFB0BEC5), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.description ?? tx.type.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: isDark ? Colors.white : const Color(0xFF333333)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('dd MMM yyyy').format(tx.createdAt).toUpperCase(),
                  style: TextStyle(color: isDark ? Colors.grey[600] : const Color(0xFFAAAAAA), fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B2E2A) : const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '+${tx.points}',
              style: const TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.w900, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

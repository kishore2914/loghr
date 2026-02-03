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

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          padding: const EdgeInsets.only(top: 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
          ),
          child: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: widget.onNavigateToDashboard != null
                ? IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
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
                    const Text(
                      'Loyalty & Rewards',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                const Text(
                  'Manage your earning potential and history',
                  style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
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
                    Icon(Icons.stars_outlined, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 24),
                    const Text(
                      'No loyalty record found',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'We couldn\'t find or create your loyalty card. Please contact HR or try again later.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
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
                          const Text(
                            'MEMBERSHIP CARD',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          LoyaltyCardWidget(
                            card: card,
                            onTap: () {},
                          ),
                          const SizedBox(height: 32),
                          const Text(
                            'PERFORMANCE METRICS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildMetricCard(
                            label: 'ORG RANK',
                            value: '#1',
                            icon: Icons.trending_up,
                            iconColor: Colors.teal,
                            bgColor: const Color(0xFFE8F5E9),
                          ),
                          const SizedBox(height: 14),
                          _buildMetricCard(
                            label: 'LIFETIME POINTS',
                            value: '${card.points}',
                            icon: Icons.history,
                            iconColor: Colors.blue.shade700,
                            bgColor: const Color(0xFFE3F2FD),
                          ),
                          const SizedBox(height: 32),
                          _buildRedemptionNote(),
                        ],
                      ),
                    ),
                  ),
                  
                  // Vertical Divider
                  if (isWide) Container(width: 1, color: Colors.grey.shade100, height: double.infinity),
                  
                  // Right Side: Tabs and Content
                  Expanded(
                    flex: isWide ? 6 : 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                          child: _buildTabBar(),
                        ),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildHowToEarnTab(),
                              _buildActivityLogTab(provider.transactions),
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
                               const Text('MEMBERSHIP CARD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                               const SizedBox(height: 12),
                               LoyaltyCardWidget(card: card, onTap: () {}),
                               const SizedBox(height: 24),
                               _buildMetricCard(label: 'ORG RANK', value: '#1', icon: Icons.trending_up, iconColor: Colors.teal, bgColor: const Color(0xFFE8F5E9)),
                               const SizedBox(height: 12),
                               _buildMetricCard(label: 'LIFETIME POINTS', value: '${card.points}', icon: Icons.history, iconColor: Colors.blue.shade700, bgColor: const Color(0xFFE3F2FD)),
                             ],
                           ),
                         ),
                       ),
                       SliverToBoxAdapter(
                         child: Padding(
                           padding: const EdgeInsets.symmetric(horizontal: 24),
                           child: _buildTabBar(),
                         ),
                       ),
                     ];
                   },
                   body: TabBarView(
                     controller: _tabController,
                     children: [
                       _buildHowToEarnTab(),
                       _buildActivityLogTab(provider.transactions),
                     ],
                   ),
                 );
              }

              return Container(
                margin: EdgeInsets.all(isWide ? 24 : 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
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
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0F0F0)),
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
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFAAAAAA)),
              ),
              Text(
                value,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF222222)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRedemptionNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F9FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1EDFF)),
      ),
      child: Text(
        '* Redeem points for bonuses, leave, or gift cards via the HR department.',
        style: TextStyle(
          fontSize: 11,
          fontStyle: FontStyle.italic,
          color: Colors.blue.shade800,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        labelColor: const Color(0xFF2E5BFF),
        unselectedLabelColor: Colors.grey.shade500,
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

  Widget _buildHowToEarnTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'REWARDS DISTRIBUTION PLAN',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFAAAAAA), letterSpacing: 0.5),
        ),
        const SizedBox(height: 24),
        _buildEarnItem(
          icon: Icons.check_circle_outline,
          iconColor: const Color(0xFF2E5BFF),
          title: 'Task Completion',
          points: '+20 PTS',
        ),
        _buildEarnItem(
          icon: Icons.track_changes_outlined,
          iconColor: const Color(0xFF00C853),
          title: 'Objective Milestone',
          points: '+50 PTS',
        ),
        _buildEarnItem(
          icon: Icons.timer_outlined,
          iconColor: const Color(0xFF7C4DFF),
          title: 'Attendance Perfection',
          points: '+10 PTS',
        ),
      ],
    );
  }

  Widget _buildEarnItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String points,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0F0F0)),
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
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF333333)),
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
          Icon(Icons.chevron_right, color: Colors.grey.shade300, size: 18),
        ],
      ),
    );
  }

  Widget _buildActivityLogTab(List<LoyaltyTransaction> transactions) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'STATEMENT OF POINTS',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFAAAAAA)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6F8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${transactions.length} ENTRIES',
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF666666)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (transactions.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.only(top: 60),
              child: Column(
                children: [
                  Icon(Icons.history_toggle_off, size: 40, color: Color(0xFFEEEEEE)),
                  SizedBox(height: 12),
                  Text('No transactions yet.', style: TextStyle(color: Color(0xFFCCCCCC), fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          )
        else
          ...transactions.map((tx) => _buildTransactionItem(tx)),
      ],
    );
  }

  Widget _buildTransactionItem(LoyaltyTransaction tx) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F6F8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.show_chart, color: Color(0xFFB0BEC5), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.description ?? tx.type.replaceAll('_', ' ').toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF333333)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('dd MMM yyyy').format(tx.createdAt).toUpperCase(),
                  style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
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

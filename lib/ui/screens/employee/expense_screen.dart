import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:loghr_mobile/logic/expense_provider.dart';
import 'package:loghr_mobile/logic/auth_provider.dart';
import 'package:intl/intl.dart';

class ExpenseScreen extends StatefulWidget {
  final VoidCallback onNavigateToDashboard;

  const ExpenseScreen({
    super.key,
    required this.onNavigateToDashboard,
  });

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  String _selectedTab = 'Expenses';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final user = authProvider.user;
      if (user != null) {
        context.read<ExpenseProvider>().loadExpenses(user.id);
        context.read<ExpenseProvider>().loadCharges(user.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final expenseProvider = context.watch<ExpenseProvider>();
    final user = authProvider.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final stats = _selectedTab == 'Expenses' 
        ? expenseProvider.stats 
        : expenseProvider.chargeStats;
    
    final items = _selectedTab == 'Expenses'
        ? expenseProvider.filteredExpenses
        : expenseProvider.filteredCharges;
    
    final isLoading = _selectedTab == 'Expenses'
        ? expenseProvider.isLoading
        : expenseProvider.isChargesLoading;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Expenses & Charges'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onNavigateToDashboard,
        ),
      ),
      body: Column(
        children: [
          // Header Actions
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Manage employee expense claims and infraction charges',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ),
                    Row(
                      children: [
                        _buildFilterTab('Expenses', _selectedTab == 'Expenses'),
                        const SizedBox(width: 4),
                        _buildFilterTab('Charges', _selectedTab == 'Charges'),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.download_outlined, size: 18),
                        label: const Text('Download Report', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          side: BorderSide(color: Colors.blue.shade700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _selectedTab == 'Expenses' 
                            ? () => _showAddExpenseDialog(context, user?.id ?? '')
                            : null,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('New Claim', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          disabledBackgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                          disabledForegroundColor: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Summary Cards Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        _selectedTab == 'Expenses' ? 'Total Claims' : 'Total Charges',
                        stats['total_claims'].toString(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        'Pending',
                        stats['pending'].toString(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        _selectedTab == 'Expenses' ? 'Approved' : 'Acknowledged',
                        (_selectedTab == 'Expenses' ? stats['approved'] : stats['acknowledged']).toString(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        _selectedTab == 'Expenses' ? 'Rejected' : 'Settled',
                        (_selectedTab == 'Expenses' ? stats['rejected'] : stats['settled']).toString(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildSummaryCard(
                  'Total Amount',
                  '₹${NumberFormat('#,##,##0').format(stats['total_amount'])}',
                  isFullWidth: true,
                ),
              ],
            ),
          ),

          // Filters
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1F2937) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      onChanged: (val) => expenseProvider.setSearchQuery(val),
                      decoration: const InputDecoration(
                        hintText: 'Search...',
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                        contentPadding: EdgeInsets.zero,
                        filled: false,
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 24,
                    color: Colors.grey.withOpacity(0.2),
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  _buildStatusDropdown(expenseProvider),
                  Container(
                    width: 1,
                    height: 24,
                    color: Colors.grey.withOpacity(0.2),
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  _buildMethodDropdown(expenseProvider),
                ],
              ),
            ),
          ),

          // Content List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                    ? Center(child: Text(_selectedTab == 'Expenses' ? 'No expense claims yet' : 'No charges found'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return _buildItemCard(item);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDropdown(ExpenseProvider provider) {
    final statuses = _selectedTab == 'Expenses'
        ? ['All Status', 'Pending', 'Approved', 'Rejected', 'Reimbursed']
        : ['All Status', 'Pending', 'Acknowledged', 'Settled', 'Deducted'];

    return PopupMenuButton<String>(
      initialValue: provider.statusFilter,
      onSelected: (String value) {
        provider.setStatusFilter(value);
      },
      itemBuilder: (BuildContext context) {
        return statuses.map((String status) {
          return PopupMenuItem<String>(
            value: status,
            child: Text(status, style: const TextStyle(fontSize: 13)),
          );
        }).toList();
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(provider.statusFilter, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const Icon(Icons.keyboard_arrow_down, size: 14, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildMethodDropdown(ExpenseProvider provider) {
    final methods = ['All Methods', 'Cash', 'Payroll', 'Bank Transfer'];

    return PopupMenuButton<String>(
      initialValue: provider.methodFilter,
      onSelected: (String value) {
        provider.setMethodFilter(value);
      },
      itemBuilder: (BuildContext context) {
        return methods.map((String method) {
          return PopupMenuItem<String>(
            value: method,
            child: Text(method, style: const TextStyle(fontSize: 13)),
          );
        }).toList();
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(provider.methodFilter, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const Icon(Icons.keyboard_arrow_down, size: 14, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String label, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.red.shade50 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: Colors.red.shade100) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isSelected ? Colors.red.shade600 : Colors.grey,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, {bool isFullWidth = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: isFullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: isFullWidth ? 20 : 16, 
              fontWeight: FontWeight.bold,
              color: isFullWidth ? Colors.blue.shade700 : null,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildItemCard(dynamic item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = item.status.toString().split('.').last.toLowerCase();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.description ?? 'No description',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusTag(status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.expenseNumber ?? 'N/A'} • ${DateFormat('d/M/y').format(item.expenseDate)} • ${item.category ?? 'Other'}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '₹${NumberFormat('#,##,###').format(item.amount)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade600,
            ),
          ),
          if (_selectedTab == 'Charges') ...[
            const SizedBox(width: 12),
            const Icon(Icons.visibility_outlined, size: 18, color: Colors.grey),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusTag(String status) {
    Color color;
    String label = status.toUpperCase();
    
    switch (status) {
      case 'approved':
        color = Colors.green;
        break;
      case 'reimbursed':
        color = Colors.blue;
        label = 'REIMBURSED (CASH)';
        break;
      case 'pending':
        color = Colors.orange;
        break;
      case 'rejected':
        color = Colors.red;
        break;
      case 'acknowledged':
        color = Colors.blue;
        break;
      case 'settled':
      case 'deducted':
        color = Colors.teal;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _showAddExpenseDialog(BuildContext context, String userId) async {
    final formKey = GlobalKey<FormState>();
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();
    final categoryController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    bool isSubmitting = false;

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final isDarkDialog = Theme.of(context).brightness == Brightness.dark;
            return AlertDialog(
              backgroundColor: isDarkDialog ? const Color(0xFF1F2937) : Colors.white,
              title: const Text(
                'Add Expense Claim',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          hintText: 'e.g. Travel to client site',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a description';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Amount',
                          prefixText: '₹ ',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter an amount';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: categoryController,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          hintText: 'e.g. Travel, Food, etc.',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a category';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Date',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        subtitle: Text(
                          DateFormat('dd MMM yyyy').format(selectedDate),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.calendar_today, color: Colors.blue),
                          onPressed: isSubmitting ? null : () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (date != null) {
                              setState(() {
                                selectedDate = date;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting ? null : () async {
                    if (formKey.currentState!.validate()) {
                      setState(() {
                        isSubmitting = true;
                      });

                      try {
                        final authProvider = context.read<AuthProvider>();
                        final user = authProvider.user;
                        
                        if (user == null) {
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('User not found'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                          return;
                        }
                        
                        final success = await context.read<ExpenseProvider>().createExpenseClaim(
                          userId: userId,
                          employeeId: user.id,
                          description: descriptionController.text,
                          amount: double.parse(amountController.text),
                          category: categoryController.text,
                          merchant: 'N/A',
                          date: selectedDate,
                        );

                        if (context.mounted) {
                          Navigator.pop(context);
                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Expense claim submitted successfully'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to submit expense claim'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      } finally {
                        if (mounted) {
                          setState(() {
                            isSubmitting = false;
                          });
                        }
                      }
                    }
                  },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

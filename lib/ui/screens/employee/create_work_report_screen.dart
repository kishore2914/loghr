import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CreateWorkReportScreen extends StatefulWidget {
  const CreateWorkReportScreen({super.key});

  @override
  State<CreateWorkReportScreen> createState() => _CreateWorkReportScreenState();
}

class _CreateWorkReportScreenState extends State<CreateWorkReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reportTitleController = TextEditingController();
  final _summaryController = TextEditingController();
  final _achievementsController = TextEditingController();
  final _challengesController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  String _selectedReportType = 'Daily';
  double _hoursWorked = 8.0;
  
  List<String> _completedTasks = [''];
  List<String> _inProgressTasks = [''];
  List<String> _plannedTasks = [''];

  @override
  void dispose() {
    _reportTitleController.dispose();
    _summaryController.dispose();
    _achievementsController.dispose();
    _challengesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _addTask(List<String> taskList, int index) {
    setState(() {
      taskList.add('');
    });
  }

  void _removeTask(List<String> taskList, int index) {
    if (taskList.length > 1) {
      setState(() {
        taskList.removeAt(index);
      });
    }
  }

  void _submitReport() {
    if (_formKey.currentState!.validate()) {
      // TODO: Save report to database
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Work report submitted successfully!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F1724);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.blue.shade600,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Create Work Report',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            padding: const EdgeInsets.only(left: 16, bottom: 16),
            alignment: Alignment.centerLeft,
            child: const Text(
              'Document your daily activities and achievements',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Report Details Section
              _buildSectionHeader('Report Details', Icons.info_outline, isDark, textColor),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                color: cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: borderColor),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Report Date
                      _buildDateField('Report Date *', _selectedDate, () => _selectDate(context), isDark, cardColor, borderColor),
                      const SizedBox(height: 16),
                      // Report Type
                      _buildDropdownField(
                        'Report Type *',
                        _selectedReportType,
                        ['Daily', 'Weekly', 'Monthly'],
                        (val) => setState(() => _selectedReportType = val!),
                        isDark,
                        cardColor,
                        borderColor,
                      ),
                      const SizedBox(height: 16),
                      // Hours Worked
                      _buildNumberField(
                        'Hours Worked',
                        _hoursWorked,
                        (val) => setState(() => _hoursWorked = val),
                        isDark,
                        cardColor,
                        borderColor,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Report Title
              _buildSectionHeader('Report Title', Icons.title, isDark, textColor),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _reportTitleController,
                label: 'Report Title *',
                hint: 'e.g., Daily Report - December 2, 2025',
                isRequired: true,
                isDark: isDark,
                cardColor: cardColor,
                borderColor: borderColor,
              ),
              const SizedBox(height: 24),

              // Summary
              _buildSectionHeader('Summary', Icons.summarize, isDark, textColor),
              const SizedBox(height: 12),
              _buildTextArea(
                controller: _summaryController,
                label: 'Summary',
                hint: 'Brief summary of your work today...',
                isDark: isDark,
                cardColor: cardColor,
                borderColor: borderColor,
              ),
              const SizedBox(height: 24),

              // Tasks Completed
              _buildSectionHeader('Tasks Completed', Icons.check_circle_outline, isDark, textColor),
              const SizedBox(height: 12),
              _buildTaskSection(
                _completedTasks,
                'Describe completed task...',
                Icons.check_circle_outline,
                isDark,
                cardColor,
                borderColor,
              ),
              const SizedBox(height: 24),

              // Tasks In Progress
              _buildSectionHeader('Tasks In Progress', Icons.radio_button_unchecked, isDark, textColor),
              const SizedBox(height: 12),
              _buildTaskSection(
                _inProgressTasks,
                'Describe ongoing task...',
                Icons.radio_button_unchecked,
                isDark,
                cardColor,
                borderColor,
              ),
              const SizedBox(height: 24),

              // Tasks Planned
              _buildSectionHeader('Tasks Planned', null, isDark, textColor),
              const SizedBox(height: 12),
              _buildTaskSection(
                _plannedTasks,
                'Describe planned task...',
                Icons.calendar_today,
                isDark,
                cardColor,
                borderColor,
              ),
              const SizedBox(height: 24),

              // Achievements
              _buildSectionHeader('Achievements', Icons.emoji_events, isDark, textColor),
              const SizedBox(height: 12),
              _buildTextArea(
                controller: _achievementsController,
                label: 'Achievements',
                hint: 'Key accomplishments, milestones reached...',
                isDark: isDark,
                cardColor: cardColor,
                borderColor: borderColor,
              ),
              const SizedBox(height: 24),

              // Challenges / Blockers
              _buildSectionHeader('Challenges / Blockers', Icons.warning_amber, isDark, textColor),
              const SizedBox(height: 12),
              _buildTextArea(
                controller: _challengesController,
                label: 'Challenges / Blockers',
                hint: 'Issues faced, help needed...',
                isDark: isDark,
                cardColor: cardColor,
                borderColor: borderColor,
              ),
              const SizedBox(height: 32),

              // Cancel and Submit Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.white : Colors.black87,
                        side: BorderSide(color: borderColor),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submitReport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Submit Report',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData? icon, bool isDark, Color textColor) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: Colors.blue.shade600),
          const SizedBox(width: 8),
        ],
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildDateField(String label, DateTime date, VoidCallback onTap, bool isDark, Color cardColor, Color borderColor) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd-MM-yyyy').format(date),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            Icon(Icons.calendar_today, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownField(String label, String value, List<String> items, ValueChanged<String?> onChanged, bool isDark, Color cardColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
              icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade400),
              style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(item),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberField(String label, double value, ValueChanged<double> onChanged, bool isDark, Color cardColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: value.toStringAsFixed(1),
            keyboardType: TextInputType.number,
            style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (val) {
              final numValue = double.tryParse(val) ?? 0.0;
              onChanged(numValue);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool isRequired = false,
    required bool isDark,
    required Color cardColor,
    required Color borderColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: TextFormField(
        controller: controller,
        style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(color: Colors.grey.shade600),
          hintStyle: TextStyle(color: Colors.grey.shade400),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
        validator: isRequired
            ? (value) {
                if (value == null || value.isEmpty) {
                  return 'This field is required';
                }
                return null;
              }
            : null,
      ),
    );
  }

  Widget _buildTextArea({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isDark,
    required Color cardColor,
    required Color borderColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: 4,
        style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(color: Colors.grey.shade600),
          hintStyle: TextStyle(color: Colors.grey.shade400),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildTaskSection(List<String> tasks, String hint, IconData icon, bool isDark, Color cardColor, Color borderColor) {
    return Column(
      children: [
        ...tasks.asMap().entries.map((entry) {
          final index = entry.key;
          return Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 16, top: 16),
                      child: Icon(icon, size: 20, color: Colors.blue.shade600),
                    ),
                    Expanded(
                      child: TextFormField(
                        initialValue: tasks[index],
                        maxLines: 3,
                        style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                        decoration: InputDecoration(
                          hintText: hint,
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                        ),
                        onChanged: (value) {
                          tasks[index] = value;
                        },
                      ),
                    ),
                    if (tasks.length > 1)
                      IconButton(
                        icon: Icon(Icons.remove_circle_outline, color: Colors.red.shade400),
                        onPressed: () => _removeTask(tasks, index),
                      ),
                  ],
                ),
              ),
              if (index < tasks.length - 1) const SizedBox(height: 12),
            ],
          );
        }).toList(),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _addTask(tasks, tasks.length),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Task'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}












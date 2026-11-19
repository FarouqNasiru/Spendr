import 'package:flutter/material.dart';
import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:spendr/screens/add_transactions.dart';
import 'package:spendr/screens/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../core/providers/currency_provider.dart';
import '../core/providers/category_provider.dart';
import '../../core/providers/transaction_provider.dart';
import '../../models/transaction_model.dart';
import 'package:spendr/screens/upload_statement_page.dart';
import 'transfers_page.dart';
import '../core/services/smart_reminder_service.dart';

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  String selectedTimeFrame = 'Month';
  String _categoryViewType = 'Expense';
  String _userName = '';
  StreamSubscription<Map<String, dynamic>>? _smartReminderSub;

  // Period navigation
  late int _selectedYear;
  late int _selectedMonth; // 1–12, only used for 'Week' and 'Month' views
  late int _selectedWeekOffset; // 0 = current week, -1 = last week, etc. (for 'Week' view)

  static const List<String> _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
    _selectedWeekOffset = 0;
    _loadData();
    _initSmartReminders();
  }

  @override
  void dispose() {
    _smartReminderSub?.cancel();
    super.dispose();
  }

  Future<void> _initSmartReminders() async {
    // Check if the app was launched by tapping a smart reminder notification
    final initialPrompt = await SmartReminderService().getInitialPrompt();
    if (initialPrompt != null && mounted) {
      _handleSmartReminder(initialPrompt);
    }

    // Listen for incoming transaction reminders while active
    _smartReminderSub = SmartReminderService().promptStream.listen((prompt) {
      if (mounted) {
        _handleSmartReminder(prompt);
      }
    });
  }

  void _handleSmartReminder(Map<String, dynamic> prompt) {
    final rawAmount = prompt['amount'];
    final double? amount = rawAmount is num ? rawAmount.toDouble() : null;
    final type = prompt['type'] as String? ?? 'Expense';
    final bank = prompt['bank'] as String? ?? '';
    final note = prompt['note'] as String? ?? (bank.isNotEmpty ? 'Bank: $bank' : null);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddTransactionPage(
          initialAmount: amount != null && amount > 0 ? amount : null,
          initialType: type,
          initialNote: note,
        ),
      ),
    ).then((_) {
      if (mounted) {
        _loadData();
      }
    });
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? 'Guest';
    });
  }

  // --- Period navigation helpers ---

  String _periodLabel() {
    if (selectedTimeFrame == 'Week') {
      final start = DateTime.now().add(Duration(days: _selectedWeekOffset * 7 - (DateTime.now().weekday - 1)));
      final end = start.add(const Duration(days: 6));
      return '${start.day} ${_monthNames[start.month - 1]} – ${end.day} ${_monthNames[end.month - 1]}';
    } else if (selectedTimeFrame == 'Month') {
      return '${_monthNames[_selectedMonth - 1]} $_selectedYear';
    } else {
      return '$_selectedYear';
    }
  }

  void _navigatePeriod(int direction) {
    setState(() {
      if (selectedTimeFrame == 'Week') {
        _selectedWeekOffset += direction;
      } else if (selectedTimeFrame == 'Month') {
        _selectedMonth += direction;
        if (_selectedMonth > 12) { _selectedMonth = 1; _selectedYear++; }
        if (_selectedMonth < 1) { _selectedMonth = 12; _selectedYear--; }
      } else {
        _selectedYear += direction;
      }
    });
  }

  void _resetToNow() {
    final now = DateTime.now();
    setState(() {
      _selectedYear = now.year;
      _selectedMonth = now.month;
      _selectedWeekOffset = 0;
    });
  }

  String _formatAmount(double amount) {
    String formatted = amount.toStringAsFixed(2);
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    String Function(Match) mathFunc = (Match match) => '${match[1]},';
    return formatted.replaceAllMapped(reg, mathFunc);
  }

  String _formatCompactAmount(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}k';
    } else {
      return _formatAmount(amount);
    }
  }

  // 3. Logic to Group and Sum Transactions by Category
  List<Map<String, dynamic>> _calculateCategoryStats(
    List<Transaction> allTransactions,
    List<Map<String, dynamic>> masterList,
  ) {
    bool showExpense = _categoryViewType == 'Expense';

    // Initialize with all categories from the master list
    Map<String, double> categoryTotals = {};
    Map<String, IconData> categoryIcons = {};

    for (var cat in masterList) {
      categoryTotals[cat['name']] = 0.0;
      categoryIcons[cat['name']] = cat['icon'];
    }

    // Sum transactions
    for (var tx in allTransactions) {
      // Filter by type (Expense vs Income)
      if (tx.isExpense == showExpense) {
        // ONLY include if the category exists in our master list to avoid rogue merchant cards
        if (categoryTotals.containsKey(tx.category)) {
          categoryTotals[tx.category] =
              categoryTotals[tx.category]! + tx.amount;
        }
      }
    }

    // Convert Map to List of Objects for the UI
    List<Map<String, dynamic>> result = [];
    categoryTotals.forEach((key, value) {
      // We can also filter out categories with 0.0 if we want a cleaner look,
      // but keeping them for now as per previous behavior, just sorted.
      result.add({
        'name': key,
        'amount': value,
        'icon': categoryIcons[key] ?? Icons.category,
      });
    });

    // Sort by amount descending (highest spent/income first)
    result.sort(
      (a, b) => (b['amount'] as double).compareTo(a['amount'] as double),
    );

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final currencyProvider = context.watch<CurrencyProvider>();
    final currencySymbol = currencyProvider.currencySymbol;

    // Access Transaction Provider
    final transactionProvider = context.watch<TransactionProvider>();
    final categoryProvider = context.watch<CategoryProvider>();

    final totalIncome = transactionProvider.totalIncome;
    final totalExpense = transactionProvider.totalExpense;
    final totalSavings = transactionProvider.totalSavings;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Hi $_userName",
                  style: textTheme.bodyMedium?.copyWith(color: Colors.grey),
                ),
                Text(
                  "Welcome Back!",
                  style: textTheme.headlineMedium?.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                ).then((_) => _loadData());
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.settings_outlined,
                  color: colorScheme.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text(
              "Total Savings",
              style: textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
            Text(
              "$currencySymbol${_formatAmount(totalSavings)}",
              style: textTheme.headlineLarge?.copyWith(fontSize: 32),
            ),
            const SizedBox(height: 25),

            Stack(
              children: [
                ClipPath(
                  clipper: GraphCutoutClipper(),
                  child: Container(
                    height: 250,
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(15, 70, 15, 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.light
                          ? colorScheme.secondary
                          : colorScheme.surface,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: _buildGroupedBarChart(
                      colorScheme,
                      currencySymbol,
                      transactionProvider.transactions,
                    ),
                  ),
                ),
                // Period navigator overlaid at the top
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildPeriodNavigator(colorScheme),
                ),
              ],
            ),

            const SizedBox(height: 20),
            _buildStatsRow(
              textTheme,
              currencySymbol,
              totalIncome,
              totalExpense,
            ),
            const SizedBox(height: 30),

            // 4. Pass the provider data to the category section
            _buildCategorySection(
              textTheme,
              colorScheme,
              currencySymbol,
              transactionProvider,
              categoryProvider,
            ),

            const SizedBox(height: 30),
            _buildRecentTransferSection(textTheme, currencySymbol),
            const SizedBox(height: 30),
          ],
        ),
      ),
      floatingActionButton: Builder(
        builder: (context) {
          return FloatingActionButton(
            onPressed: () {
              final RenderBox button = context.findRenderObject() as RenderBox;
              final RenderBox overlay =
                  Overlay.of(context).context.findRenderObject() as RenderBox;
              final RelativeRect position = RelativeRect.fromRect(
                Rect.fromPoints(
                  button.localToGlobal(Offset.zero, ancestor: overlay),
                  button.localToGlobal(
                    button.size.bottomRight(Offset.zero),
                    ancestor: overlay,
                  ),
                ),
                Offset.zero & overlay.size,
              );

              final isDark = Theme.of(context).brightness == Brightness.dark;
              final Color itemColor = isDark ? Colors.white : Colors.black;

              showMenu<String>(
                context: context,
                position: position,
                color: isDark ? const Color(0xFF1E2D3D) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                items: [
                  PopupMenuItem<String>(
                    value: 'add',
                    child: Row(
                      children: [
                        Icon(Icons.add, color: itemColor),
                        const SizedBox(width: 10),
                        Text(
                          'Add Transaction',
                          style: TextStyle(color: itemColor),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'upload',
                    child: Row(
                      children: [
                        Icon(Icons.upload_file, color: itemColor),
                        const SizedBox(width: 10),
                        Text(
                          'Upload Statement',
                          style: TextStyle(color: itemColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ).then((value) async {
                if (value == 'add') {
                  final result = await Navigator.of(context).push(
                    PageRouteBuilder(
                      transitionDuration: const Duration(milliseconds: 300),
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          const AddTransactionPage(),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                            return FadeTransition(
                              opacity: animation,
                              child: child,
                            );
                          },
                    ),
                  );

                  if (result == true) {
                    _loadData();
                  }
                } else if (value == 'upload') {
                  // Navigate to UploadStatementPage
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const UploadStatementPage(),
                    ),
                  );
                  _loadData();
                }
              });
            },
            child: const Icon(Icons.add),
          );
        },
      ),
    );
  }

  // ... (Keep _buildTimeFrameDropdown, _buildGroupedBarChart, _makeGroup, _buildStatsRow, _buildStatBox SAME as previous)

  /// Period navigator: ← period label → (left) and time frame dropdown (right cutout)
  Widget _buildPeriodNavigator(ColorScheme colorScheme) {
    final isDark = colorScheme.brightness == Brightness.dark;
    const arrowColor = Colors.black;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ← period → navigator (now on the left)
          Padding(
            padding: const EdgeInsets.only(left: 15, top: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.white70),
                  onPressed: () => _navigatePeriod(-1),
                  tooltip: 'Previous',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 5),
                GestureDetector(
                  onLongPress: _resetToNow,
                  child: Text(
                    _periodLabel(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: Colors.white70),
                  onPressed: () => _navigatePeriod(1),
                  tooltip: 'Next',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Timeframe dropdown (back to the right cutout)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(30),
                bottomLeft: Radius.circular(20),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedTimeFrame,
                icon: const Icon(Icons.keyboard_arrow_down, color: arrowColor),
                dropdownColor: isDark ? colorScheme.surface : Colors.white,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
                selectedItemBuilder: (_) => ['Week', 'Month', 'Year']
                    .map((v) => Center(
                          child: Text(
                            v,
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ))
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    selectedTimeFrame = v!;
                    _resetToNow();
                  });
                },
                items: ['Week', 'Month', 'Year']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeFrameDropdown(ColorScheme colorScheme) {
    // Kept for reference but no longer used in the UI (replaced by _buildPeriodNavigator)
    return const SizedBox.shrink();
  }

  Widget _buildGroupedBarChart(
    ColorScheme colorScheme,
    String currencySymbol,
    List<Transaction> transactions,
  ) {
    // 1. Process Data
    List<_ChartGroup> data = _processChartData(transactions);

    // Check for empty data
    if (data.every((g) => g.income == 0 && g.expense == 0)) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart,
              size: 50,
              color: Colors.white.withOpacity(0.5),
            ),
            const SizedBox(height: 10),
            Text(
              "No transactions added",
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    // 2. Calculate Max Y for dynamic scale
    double maxY = 0;
    for (var group in data) {
      if (group.income > maxY) maxY = group.income;
      if (group.expense > maxY) maxY = group.expense;
    }
    maxY = (maxY * 1.2).ceilToDouble(); // Add buffer
    if (maxY == 0) maxY = 10; // Default min height

    return BarChart(
      BarChartData(
        maxY: maxY,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: colorScheme.surface,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              String type = rodIndex == 0 ? 'Income' : 'Expense';
              return BarTooltipItem(
                '$type\n$currencySymbol${rod.toY.toStringAsFixed(0)}',
                TextStyle(color: resolveContentColor(colorScheme)),
              );
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 4, // 4 lines
          getDrawingHorizontalLine: (value) {
            return FlLine(color: Colors.white.withOpacity(0.1), strokeWidth: 1);
          },
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) => _getBottomTitles(value, meta),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: maxY / 4,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                return Text(
                  '${value >= 1000 ? (value / 1000).toStringAsFixed(1) + 'k' : value.toInt()}',
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: data
            .map((g) => _makeGroup(g.x, g.income, g.expense, colorScheme))
            .toList(),
      ),
    );
  }

  // --- Data Processing Logic ---

  List<_ChartGroup> _processChartData(List<Transaction> transactions) {
    Map<int, _ChartGroup> groups = {};

    // Bucket count based on timeframe
    int bucketCount = selectedTimeFrame == 'Week' ? 7
        : selectedTimeFrame == 'Month' ? 5
        : 12;

    for (int i = 0; i < bucketCount; i++) {
      groups[i] = _ChartGroup(i, 0, 0);
    }

    // Anchor dates for the selected period
    final weekAnchor = DateTime.now().add(Duration(days: _selectedWeekOffset * 7));

    for (var tx in transactions) {
      int? index;

      if (selectedTimeFrame == 'Week') {
        // Show 7 days of the selected week (Mon–Sun)
        final weekStart = weekAnchor.subtract(Duration(days: weekAnchor.weekday - 1));
        final weekEnd = weekStart.add(const Duration(days: 6));
        if (!tx.date.isBefore(weekStart) && !tx.date.isAfter(weekEnd.add(const Duration(days: 1)))) {
          index = tx.date.weekday - 1; // 0=Mon … 6=Sun
        }
      } else if (selectedTimeFrame == 'Month') {
        // Show weeks in the selected month/year
        if (tx.date.year == _selectedYear && tx.date.month == _selectedMonth) {
          int weekOfMonth = ((tx.date.day - 1) / 7).floor();
          if (weekOfMonth > 4) weekOfMonth = 4;
          index = weekOfMonth;
        }
      } else if (selectedTimeFrame == 'Year') {
        // Show all 12 months of the selected year
        if (tx.date.year == _selectedYear) {
          index = tx.date.month - 1; // 0=Jan … 11=Dec
        }
      }

      if (index != null && groups.containsKey(index)) {
        double currentInc = groups[index]!.income;
        double currentExp = groups[index]!.expense;
        if (tx.isExpense) {
          currentExp += tx.amount;
        } else {
          currentInc += tx.amount;
        }
        groups[index] = _ChartGroup(index, currentInc, currentExp);
      }
    }

    var list = groups.values.toList();
    list.sort((a, b) => a.x.compareTo(b.x));
    return list;
  }

  Widget _getBottomTitles(double value, TitleMeta meta) {
    int index = value.toInt();
    String text = '';

    if (selectedTimeFrame == 'Week') {
      // 0 = Mon, 6 = Sun of the selected week
      const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
      if (index >= 0 && index < days.length) text = days[index];
    } else if (selectedTimeFrame == 'Month') {
      text = 'W${index + 1}';
    } else if (selectedTimeFrame == 'Year') {
      if (index >= 0 && index < _monthNames.length) text = _monthNames[index];
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Text(
        text,
        style: const TextStyle(color: Colors.grey, fontSize: 10),
      ),
    );
  }

  Color resolveContentColor(ColorScheme scheme) {
    return scheme.brightness == Brightness.dark ? Colors.white : Colors.black;
  }

  BarChartGroupData _makeGroup(
    int x,
    double y1,
    double y2,
    ColorScheme colorScheme,
  ) {
    return BarChartGroupData(
      barsSpace: 4,
      x: x,
      barRods: [
        BarChartRodData(
          toY: y1,
          color: const Color(0xFFFFEB3B), // Income Yellow
          width: 8, // Thinner bars to fit more data
          borderRadius: BorderRadius.circular(2),
        ),
        BarChartRodData(
          toY: y2,
          color: colorScheme.primary, // Expense Lime
          width: 8,
          borderRadius: BorderRadius.circular(2),
        ),
      ],
    );
  }

  Widget _buildStatsRow(
    TextTheme textTheme,
    String currencySymbol,
    double income,
    double expense,
  ) {
    return Row(
      children: [
        _buildStatBox(
          "Income",
          "$currencySymbol${_formatCompactAmount(income)}",
          const Color(0xFFFFEB3B),
          Icons.arrow_upward,
          textTheme,
        ),
        const SizedBox(width: 15),
        _buildStatBox(
          "Expense",
          "$currencySymbol${_formatCompactAmount(expense)}",
          const Color(0xFFC5E1A5),
          Icons.arrow_downward,
          textTheme,
        ),
      ],
    );
  }

  Widget _buildStatBox(
    String title,
    String amount,
    Color color,
    IconData icon,
    TextTheme textTheme,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white54,
              child: Icon(icon, size: 16, color: Colors.black),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  amount,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- MODIFIED CATEGORY SECTION ----------------
  Widget _buildCategorySection(
    TextTheme textTheme,
    ColorScheme colorScheme,
    String currencySymbol,
    TransactionProvider transactionProvider,
    CategoryProvider categoryProvider,
  ) {
    // 1. Calculate the dynamic data
    final masterList = _categoryViewType == 'Expense'
        ? categoryProvider.expenseCategories
        : categoryProvider.incomeCategories;

    final categoryData = _calculateCategoryStats(
      transactionProvider.recentTransactions,
      masterList,
    );

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Categories",
              style: textTheme.headlineMedium?.copyWith(fontSize: 20),
            ),
            // 2. Dropdown Logic
            DropdownButton<String>(
              value: _categoryViewType,
              underline: const SizedBox(),
              icon: Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: colorScheme.brightness == Brightness.dark
                    ? Colors.white
                    : colorScheme.secondary,
              ),
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black54,
                fontWeight: FontWeight.bold,
              ),
              dropdownColor: colorScheme.surface,
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _categoryViewType = newValue;
                  });
                }
              },
              items: ['Expense', 'Income'].map<DropdownMenuItem<String>>((
                String value,
              ) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 140,
          // 3. Dynamic List View
          child: categoryData.isEmpty
              ? Center(
                  child: Text(
                    "No ${_categoryViewType.toLowerCase()}s recorded",
                  ),
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: categoryData.length,
                  itemBuilder: (context, index) {
                    final cat = categoryData[index];
                    return _buildCategoryCard(
                      cat['icon'] as IconData,
                      cat['name'] as String,
                      "$currencySymbol${_formatAmount(cat['amount'])}",
                      colorScheme,
                      textTheme,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(
    IconData icon,
    String title,
    String amount,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 15),
      child: ClipPath(
        clipper: CategoryCardClipper(),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colorScheme.surface, // Uses 'cardLight' from Theme
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                icon,
                size: 28,
                color: colorScheme.brightness == Brightness.dark
                    ? Colors.white
                    : colorScheme.secondary,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    amount,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: colorScheme.brightness == Brightness.dark
                          ? Colors.white
                          : colorScheme.secondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ... (Keep Recent Transfers Section and Clippers unchanged)

  Widget _buildRecentTransferSection(
    TextTheme textTheme,
    String currencySymbol,
  ) {
    final transactionProvider = context.watch<TransactionProvider>();
    final recentTransactions = transactionProvider.recentTransactions;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Hero(
              tag: 'recent-transfers',
              child: Material(
                type: MaterialType.transparency,
                child: Text(
                  "Transactions",
                  style: textTheme.headlineMedium?.copyWith(fontSize: 20),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TransfersPage(),
                  ),
                );
              },
              child: Text(
                "View All",
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black54,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        if (recentTransactions.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20.0),
            child: Text("No recent transactions"),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recentTransactions.length > 5
                ? 5
                : recentTransactions.length,
            itemBuilder: (context, index) {
              final transaction = recentTransactions[index];
              return _buildTransactionItem(
                transaction,
                textTheme,
                currencySymbol,
              );
            },
          ),
      ],
    );
  }

  Widget _buildTransactionItem(
    Transaction transaction,
    TextTheme textTheme,
    String currencySymbol,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.surface
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: transaction.isExpense
                  ? Colors.red.withOpacity(0.1)
                  : Colors.green.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              transaction.icon,
              color: transaction.isExpense ? Colors.red : Colors.green,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _formatDate(transaction.date),
                  style: textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
              ],
            ),
          ),
          Text(
            "${transaction.isExpense ? '-' : '+'}$currencySymbol${transaction.amount.toStringAsFixed(2)}",
            style: textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: transaction.isExpense ? Colors.red : Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }
}

class _ChartGroup {
  final int x;
  final double income;
  final double expense;

  _ChartGroup(this.x, this.income, this.expense);
}

class GraphCutoutClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    double cutoutWidth = 100;
    double cutoutHeight = 60;
    double cornerRadius = 30;
    path.moveTo(0, cornerRadius);
    path.quadraticBezierTo(0, 0, cornerRadius, 0);
    path.lineTo(size.width - cutoutWidth - cornerRadius, 0);
    path.quadraticBezierTo(
      size.width - cutoutWidth,
      0,
      size.width - cutoutWidth,
      cutoutHeight / 2,
    );
    path.quadraticBezierTo(
      size.width - cutoutWidth,
      cutoutHeight,
      size.width - cutoutWidth + cornerRadius,
      cutoutHeight,
    );
    path.lineTo(size.width - cornerRadius, cutoutHeight);
    path.quadraticBezierTo(
      size.width,
      cutoutHeight,
      size.width,
      cutoutHeight + cornerRadius,
    );
    path.lineTo(size.width, size.height - cornerRadius);
    path.quadraticBezierTo(
      size.width,
      size.height,
      size.width - cornerRadius,
      size.height,
    );
    path.lineTo(cornerRadius, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - cornerRadius);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class CategoryCardClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    double cutoutWidth = 55;
    double cutoutHeight = 25;
    double cornerRadius = 20;
    path.moveTo(0, cornerRadius);
    path.quadraticBezierTo(0, 0, cornerRadius, 0);
    path.lineTo(size.width - cutoutWidth - cornerRadius, 0);
    path.quadraticBezierTo(
      size.width - cutoutWidth,
      0,
      size.width - cutoutWidth,
      cutoutHeight / 2,
    );
    path.quadraticBezierTo(
      size.width - cutoutWidth,
      cutoutHeight,
      size.width - cutoutWidth + cornerRadius,
      cutoutHeight,
    );
    path.lineTo(size.width - cornerRadius, cutoutHeight);
    path.quadraticBezierTo(
      size.width,
      cutoutHeight,
      size.width,
      cutoutHeight + cornerRadius,
    );
    path.lineTo(size.width, size.height - cornerRadius);
    path.quadraticBezierTo(
      size.width,
      size.height,
      size.width - cornerRadius,
      size.height,
    );
    path.lineTo(cornerRadius, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - cornerRadius);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

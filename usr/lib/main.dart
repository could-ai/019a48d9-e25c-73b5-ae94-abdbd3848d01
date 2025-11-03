import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Money Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1B33),
        primaryColor: const Color(0xFF00C6FF),
        hintColor: const Color(0xFF00C6FF),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
          headlineSmall: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0D1B33),
          elevation: 0,
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1A2A47),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide.none,
          ),
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        ),
        cardTheme: CardTheme(
          color: const Color(0xFF1A2A47),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          elevation: 4,
          shadowColor: Colors.black.withOpacity(0.5),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00C6FF),
            foregroundColor: const Color(0xFF0D1B33),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14.0),
            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        dialogBackgroundColor: const Color(0xFF1A2A47),
      ),
      home: const MoneyManagerPage(),
    );
  }
}

class Transaction {
  final String category;
  final double amount;
  final DateTime date;
  final bool isIncome;

  Transaction({
    required this.category,
    required this.amount,
    required this.date,
    required this.isIncome,
  });

  Map<String, dynamic> toJson() => {
        'category': category,
        'amount': amount,
        'date': date.toIso8601String(),
        'isIncome': isIncome,
      };

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
        category: json['category'],
        amount: json['amount'],
        date: DateTime.parse(json['date']),
        isIncome: json['isIncome'],
      );
}

class MoneyManagerPage extends StatefulWidget {
  const MoneyManagerPage({super.key});

  @override
  State<MoneyManagerPage> createState() => _MoneyManagerPageState();
}

class _MoneyManagerPageState extends State<MoneyManagerPage> {
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  List<Transaction> _transactions = [];
  double _totalIncome = 0.0;
  double _totalExpense = 0.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? transactionsString = prefs.getString('transactions');
    if (transactionsString != null) {
      final List<dynamic> decoded = jsonDecode(transactionsString);
      setState(() {
        _transactions = decoded.map((item) => Transaction.fromJson(item)).toList();
        _calculateTotals();
      });
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_transactions.map((item) => item.toJson()).toList());
    await prefs.setString('transactions', encoded);
  }

  void _calculateTotals() {
    _totalIncome = _transactions
        .where((t) => t.isIncome)
        .fold(0, (sum, item) => sum + item.amount);
    _totalExpense = _transactions
        .where((t) => !t.isIncome)
        .fold(0, (sum, item) => sum + item.amount);
  }

  void _addTransaction(bool isIncome) {
    final String category = _categoryController.text;
    final double? amount = double.tryParse(_amountController.text);

    if (category.isNotEmpty && amount != null && amount > 0) {
      final newTransaction = Transaction(
        category: category,
        amount: amount,
        date: DateTime.now(),
        isIncome: isIncome,
      );
      setState(() {
        _transactions.insert(0, newTransaction);
        _calculateTotals();
        _saveData();
      });
      _categoryController.clear();
      _amountController.clear();
      FocusScope.of(context).unfocus(); // Dismiss keyboard
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid category and amount.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _resetAll() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Reset All Data'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Are you sure you want to delete all data permanently?'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Reset', style: TextStyle(color: Theme.of(context).hintColor)),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                setState(() {
                  _transactions = [];
                  _totalIncome = 0.0;
                  _totalExpense = 0.0;
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
  
  void _showCalculator() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => const CalculatorDialog(),
    );
    if (result != null) {
      _amountController.text = result;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double balance = _totalIncome - _totalExpense;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Money Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: _resetAll,
            tooltip: 'Reset All Data',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSummaryCard(balance),
            const SizedBox(height: 20),
            _buildChartCard(),
            const SizedBox(height: 20),
            _buildInputCard(),
            const SizedBox(height: 20),
            _buildHistoryList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(double balance) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Current Balance', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              '${balance >= 0 ? '' : '- '}\$${balance.abs().toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: balance >= 0 ? Colors.greenAccent : Colors.redAccent,
                fontSize: 28,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem('Income', _totalIncome, Colors.greenAccent),
                _buildSummaryItem('Expense', _totalExpense, Colors.redAccent),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String title, double amount, Color color) {
    return Column(
      children: [
        Text(title, style: TextStyle(color: color.withOpacity(0.8))),
        const SizedBox(height: 4),
        Text('\$${amount.toStringAsFixed(2)}', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  Widget _buildChartCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Breakdown', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 20),
            SizedBox(
              height: 150,
              child: (_totalIncome == 0 && _totalExpense == 0)
                  ? Center(child: Text('No data to display', style: TextStyle(color: Colors.white.withOpacity(0.5))))
                  : PieChart(
                      PieChartData(
                        sections: [
                          PieChartSectionData(
                            color: Colors.greenAccent,
                            value: _totalIncome,
                            title: '${(_totalIncome + _totalExpense) == 0 ? 0 : (_totalIncome / (_totalIncome + _totalExpense) * 100).toStringAsFixed(0)}%',
                            radius: 50,
                            titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D1B33)),
                          ),
                          PieChartSectionData(
                            color: Colors.redAccent,
                            value: _totalExpense,
                            title: '${(_totalIncome + _totalExpense) == 0 ? 0 : (_totalExpense / (_totalIncome + _totalExpense) * 100).toStringAsFixed(0)}%',
                            radius: 50,
                            titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D1B33)),
                          ),
                        ],
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _categoryController,
              decoration: const InputDecoration(hintText: 'Category (e.g., Salary, Groceries)'),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              decoration: InputDecoration(
                hintText: 'Amount',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calculate, color: Color(0xFF00C6FF)),
                  onPressed: _showCalculator,
                  tooltip: 'Open Calculator',
                ),
              ),
              style: const TextStyle(color: Colors.white),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _addTransaction(true),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
                    child: const Text('Add Income'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _addTransaction(false),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                    child: const Text('Add Expense'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('History', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 10),
        _transactions.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text('No transactions yet.'),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _transactions.length,
                itemBuilder: (context, index) {
                  final transaction = _transactions[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6.0),
                    child: ListTile(
                      leading: Icon(
                        transaction.isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                        color: transaction.isIncome ? Colors.greenAccent : Colors.redAccent,
                      ),
                      title: Text(transaction.category, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(DateFormat.yMMMd().format(transaction.date)),
                      trailing: Text(
                        '${transaction.isIncome ? '+' : '-'} \$${transaction.amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: transaction.isIncome ? Colors.greenAccent : Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
      ],
    );
  }
}

class CalculatorDialog extends StatefulWidget {
  const CalculatorDialog({super.key});

  @override
  _CalculatorDialogState createState() => _CalculatorDialogState();
}

class _CalculatorDialogState extends State<CalculatorDialog> {
  String _output = "0";
  String _currentNumber = "";
  double _num1 = 0;
  String _operand = "";

  void _buttonPressed(String buttonText) {
    setState(() {
      if ("0123456789.".contains(buttonText)) {
        if (_currentNumber.contains('.') && buttonText == '.') return;
        _currentNumber += buttonText;
        _output = _currentNumber;
      } else if (buttonText == "C") {
        _output = "0";
        _currentNumber = "";
        _num1 = 0;
        _operand = "";
      } else if (["+", "-", "×", "÷"].contains(buttonText)) {
        if (_currentNumber.isEmpty) return;
        _num1 = double.parse(_currentNumber);
        _operand = buttonText;
        _currentNumber = "";
      } else if (buttonText == "=") {
        if (_currentNumber.isEmpty || _operand.isEmpty) return;
        double num2 = double.parse(_currentNumber);
        double result = 0;
        if (_operand == "+") result = _num1 + num2;
        if (_operand == "-") result = _num1 - num2;
        if (_operand == "×") result = _num1 * num2;
        if (_operand == "÷") result = _num1 / num2;
        _output = result.toStringAsFixed(2).replaceAll(RegExp(r'([.]*0)(?!.*\d)'), ''); // remove trailing .00
        _num1 = result;
        _currentNumber = _output;
        _operand = "";
      }
    });
  }

  Widget _buildButton(String buttonText, {Color? color, Color? textColor}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color ?? const Color(0xFF0D1B33),
            foregroundColor: textColor ?? Colors.white,
            padding: const EdgeInsets.all(20.0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => _buttonPressed(buttonText),
          child: Text(
            buttonText,
            style: const TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: const EdgeInsets.all(8),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 12.0),
              child: Text(
                _output,
                style: const TextStyle(fontSize: 48.0, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(),
            Column(
              children: [
                Row(children: [
                  _buildButton("C", color: Colors.grey[700]),
                  _buildButton("÷", color: Theme.of(context).hintColor),
                ]),
                Row(children: [
                  _buildButton("7"),
                  _buildButton("8"),
                  _buildButton("9"),
                  _buildButton("×", color: Theme.of(context).hintColor),
                ]),
                Row(children: [
                  _buildButton("4"),
                  _buildButton("5"),
                  _buildButton("6"),
                  _buildButton("-", color: Theme.of(context).hintColor),
                ]),
                Row(children: [
                  _buildButton("1"),
                  _buildButton("2"),
                  _buildButton("3"),
                  _buildButton("+", color: Theme.of(context).hintColor),
                ]),
                Row(children: [
                  _buildButton("."),
                  _buildButton("0"),
                  _buildButton("=", color: Theme.of(context).hintColor),
                ]),
              ],
            )
          ],
        ),
      ),
      actions: [
        TextButton(
          child: const Text("Cancel"),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          child: Text("OK", style: TextStyle(color: Theme.of(context).hintColor)),
          onPressed: () {
            if (_output.isNotEmpty && double.tryParse(_output) != null) {
              Navigator.of(context).pop(_output);
            }
          },
        ),
      ],
    );
  }
}

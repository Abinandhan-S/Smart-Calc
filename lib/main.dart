import 'package:flutter/material.dart';
import 'package:math_expressions/math_expressions.dart' as math;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => CalculatorProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.indigoAccent,
          centerTitle: true,
        ),
      ),
      home: const CalculatorScreen(),
    );
  }
}

// ──────────────────────────── PROVIDER ────────────────────────────

class CalculatorProvider extends ChangeNotifier {
  String expression = "";
  String result = "";
  int cursorIndex = 0;
  List<String> history = [];
  bool showHistory = false;

  CalculatorProvider() {
    loadHistory();
  }

  Future<void> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    history = prefs.getStringList('history') ?? [];
    notifyListeners();
  }

  Future<void> saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('history', history);
  }

  void addCharacter(String char) {
    expression = expression.substring(0, cursorIndex) + char + expression.substring(cursorIndex);
    cursorIndex++;
    notifyListeners();
  }

  void deleteCharacter() {
    if (cursorIndex > 0) {
      expression = expression.substring(0, cursorIndex - 1) + expression.substring(cursorIndex);
      cursorIndex--;
      notifyListeners();
    }
  }

  void clear() {
    expression = "";
    result = "";
    cursorIndex = 0;
    notifyListeners();
  }

  void moveCursorLeft() {
    if (cursorIndex > 0) cursorIndex--;
    notifyListeners();
  }

  void moveCursorRight() {
    if (cursorIndex < expression.length) cursorIndex++;
    notifyListeners();
  }

  void calculate() {
    try {
      math.Parser p = math.Parser();
      math.Expression exp = p.parse(
        expression.replaceAll('×', '*').replaceAll('÷', '/'),
      );
      math.ContextModel cm = math.ContextModel();
      result = '${exp.evaluate(math.EvaluationType.REAL, cm)}';

      if (expression.isNotEmpty) {
        history.insert(0, "$expression = $result");
        if (history.length > 10) history.removeLast();
        saveHistory();
      }
    } catch (e) {
      result = "Error";
    }
    notifyListeners();
  }

  void toggleHistory() {
    showHistory = !showHistory;
    notifyListeners();
  }
}

// ──────────────────────────── UI SCREEN ────────────────────────────

class CalculatorScreen extends StatelessWidget {
  const CalculatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final calc = Provider.of<CalculatorProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Calculator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: calc.toggleHistory,
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // ─── Display ───
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.bottomRight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      RichText(
                        text: TextSpan(
                          text: calc.expression.substring(0, calc.cursorIndex),
                          style: const TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          children: [
                            const TextSpan(
                              text: '|',
                              style: TextStyle(
                                color: Colors.amber,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(
                              text: calc.expression.substring(calc.cursorIndex),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        calc.result,
                        style: const TextStyle(fontSize: 28, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),

              // ─── Keypad ───
              Expanded(
                flex: 3,
                child: _buildButtons(calc),
              ),

              // ─── Navigation Row Below Keypad ───
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _navButton(Icons.arrow_left, calc.moveCursorLeft),
                    const SizedBox(width: 24),
                    _navButton(Icons.arrow_right, calc.moveCursorRight),
                  ],
                ),
              ),
            ],
          ),

          // ─── Slide-in History Panel ───
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            top: 0,
            right: calc.showHistory ? 0 : -MediaQuery.of(context).size.width,
            bottom: 0,
            child: Container(
              width: MediaQuery.of(context).size.width,
              color: Colors.grey[900],
              child: Column(
                children: [
                  Container(
                    color: Colors.indigoAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 16),
                          child: Text(
                            "History",
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: calc.toggleHistory,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: calc.history.length,
                      itemBuilder: (context, index) {
                        final item = calc.history[index];
                        return ListTile(
                          title: Text(item, style: const TextStyle(color: Colors.white)),
                          onTap: () {
                            calc.expression = item.split('=')[0].trim();
                            calc.cursorIndex = calc.expression.length;
                            calc.showHistory = false;
                            calc.notifyListeners();
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtons(CalculatorProvider calc) {
    final buttons = [
      ['(', ')', 'C', 'DEL'],
      ['7', '8', '9', '÷'],
      ['4', '5', '6', '×'],
      ['1', '2', '3', '-'],
      ['0', '.', '=', '+'],
    ];

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: buttons.map((row) {
          return Expanded(
            child: Row(
              children: row.map((btnText) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _getButtonColor(btnText),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        if (btnText == '=') {
                          calc.calculate();
                        } else if (btnText == 'C') {
                          calc.clear();
                        } else if (btnText == 'DEL') {
                          calc.deleteCharacter();
                        } else {
                          calc.addCharacter(btnText);
                        }
                      },
                      child: Text(
                        btnText,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _getButtonColor(String text) {
    if (text == 'C' || text == 'DEL') return Colors.redAccent;
    if (text == '=' || text == '+' || text == '-' || text == '×' || text == '÷') {
      return Colors.indigoAccent;
    }
    return Colors.grey[850]!;
  }

  Widget _navButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: CircleAvatar(
        backgroundColor: Colors.indigoAccent,
        radius: 28,
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}

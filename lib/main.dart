import 'package:flutter/material.dart';
import 'package:math_expressions/math_expressions.dart' as math;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => CalculatorProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Calculator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B0B0D),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.indigoAccent,
          centerTitle: true,
        ),
      ),
      home: const CalculatorScreen(),
    );
  }
}

// -------------------------- Provider --------------------------

class CalculatorProvider extends ChangeNotifier {
  String expression = "";
  String result = "";
  int cursorIndex = 0;
  List<String> history = [];
  List<String> savedFormulas = [];
  bool showHistory = false;

  CalculatorProvider() {
    _loadAll();
  }

  Future<void> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    history = prefs.getStringList('history') ?? [];
    savedFormulas = prefs.getStringList('saved_formulas') ?? [];
    notifyListeners();
  }

  Future<void> _saveHistoryToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('history', history);
  }

  Future<void> _saveSavedFormulasToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('saved_formulas', savedFormulas);
  }

  void addCharacter(String char) {
    // safe substring handling
    if (cursorIndex < 0) cursorIndex = 0;
    if (cursorIndex > expression.length) cursorIndex = expression.length;
    expression = expression.substring(0, cursorIndex) + char + expression.substring(cursorIndex);
    cursorIndex++;
    notifyListeners();
  }

  void deleteCharacter() {
    if (cursorIndex > 0 && expression.isNotEmpty) {
      expression = expression.substring(0, cursorIndex - 1) + expression.substring(cursorIndex);
      cursorIndex--;
      notifyListeners();
    }
  }

  void clearExpression() {
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
      final expString = expression.replaceAll('×', '*').replaceAll('÷', '/');
      math.Parser p = math.Parser();
      math.Expression exp = p.parse(expString);
      math.ContextModel cm = math.ContextModel();
      final eval = exp.evaluate(math.EvaluationType.REAL, cm);
      result = eval.toString();

      // Save to history (unique)
      final record = "$expression = $result";
      if (expression.isNotEmpty) {
        if (!history.contains(record)) history.insert(0, record);
        // keep history length reasonable
        if (history.length > 100) history = history.sublist(0, 100);
        _saveHistoryToPrefs();
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

  // Saved formulas management
  Future<void> saveCurrentFormula() async {
    if (expression.trim().isEmpty) return;
    if (!savedFormulas.contains(expression.trim())) {
      savedFormulas.insert(0, expression.trim());
      if (savedFormulas.length > 100) savedFormulas = savedFormulas.sublist(0, 100);
      await _saveSavedFormulasToPrefs();
      notifyListeners();
    }
  }

  Future<void> clearSavedFormulas() async {
    savedFormulas.clear();
    await _saveSavedFormulasToPrefs();
    notifyListeners();
  }

  // Optionally: remove single saved formula
  Future<void> removeSavedFormulaAt(int index) async {
    if (index >= 0 && index < savedFormulas.length) {
      savedFormulas.removeAt(index);
      await _saveSavedFormulasToPrefs();
      notifyListeners();
    }
  }

  // Load a formula into expression
  void loadFormula(String formula) {
    expression = formula;
    cursorIndex = expression.length;
    result = "";
    showHistory = false;
    notifyListeners();
  }

  // Clear history (separate from saved formulas)
  Future<void> clearHistory() async {
    history.clear();
    await _saveHistoryToPrefs();
    notifyListeners();
  }
}

// -------------------------- UI Screen --------------------------

class CalculatorScreen extends StatelessWidget {
  const CalculatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final calc = Provider.of<CalculatorProvider>(context, listen: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Calculator'),
        actions: [
          // Show saved formulas sheet
          IconButton(
            tooltip: 'Saved formulas',
            icon: const Icon(Icons.bookmark),
            onPressed: () => _showSavedSheet(context, calc),
          ),
          // History toggle
          IconButton(
            tooltip: 'History',
            icon: Icon(calc.showHistory ? Icons.close : Icons.history),
            onPressed: calc.toggleHistory,
          ),
        ],
      ),

      body: Stack(
        children: [
          Column(
            children: [
              // Display area
              Expanded(
                flex: 2,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  alignment: Alignment.bottomRight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Expression with cursor: handle empty safely
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        reverse: true,
                        child: _buildExpressionWithCursor(calc),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        calc.result,
                        style: const TextStyle(fontSize: 26, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),

              // Keypad grid (numbers/operators) — medium spacing (Option B)
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: _keypadGrid(calc),
                ),
              ),

              // Bottom row: ( )  C  ⌫  — above nav buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                child: Row(
                  children: [
                    _bottomActionButton('(', calc),
                    const SizedBox(width: 8),
                    _bottomActionButton(')', calc),
                    const SizedBox(width: 8),
                    _bottomActionButton('C', calc, color: Colors.redAccent),
                    const SizedBox(width: 8),
                    _bottomIconButton(Icons.backspace, calc, color: Colors.redAccent),
                  ],
                ),
              ),

              // Save / Clear Saved quick row (easy access) — small buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await calc.saveCurrentFormula();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Formula saved')),
                          );
                        },
                        icon: const Icon(Icons.save),
                        label: const Text('Save'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await calc.clearSavedFormulas();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Saved formulas cleared')),
                          );
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Clear Saved'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Navigation row (cursor left/right)
              Padding(
                padding: const EdgeInsets.only(bottom: 16, top: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _navButton(Icons.arrow_left, calc.moveCursorLeft),
                    const SizedBox(width: 28),
                    _navButton(Icons.arrow_right, calc.moveCursorRight),
                  ],
                ),
              ),
            ],
          ),

          // Slide-in History overlay (from bottom)
          if (calc.showHistory)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: MediaQuery.of(context).size.height * 0.55,
              child: _historyPanel(context, calc),
            ),
        ],
      ),
    );
  }

  // Expression + cursor builder (protect substrings)
  Widget _buildExpressionWithCursor(CalculatorProvider calc) {
    final expr = calc.expression;
    final idx = calc.cursorIndex.clamp(0, expr.length);
    final left = expr.substring(0, idx);
    final right = expr.substring(idx);
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold),
        children: [
          TextSpan(text: left),
          const WidgetSpan(
            child: SizedBox(width: 6),
          ),
          const TextSpan(
            text: '|',
            style: TextStyle(color: Colors.amber),
          ),
          TextSpan(text: right, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  // Keypad grid widget (numbers/operators)
  Widget _keypadGrid(CalculatorProvider calc) {
    // layout rows — medium spacing: crossAxisSpacing & mainAxisSpacing = 8
    final rows = [
      ['7', '8', '9', '÷'],
      ['4', '5', '6', '×'],
      ['1', '2', '3', '-'],
      ['0', '.', '=', '+'],
    ];

    return Column(
      children: rows.map((row) {
        return Expanded(
          child: Row(
            children: row.map((label) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(4.0), // medium spacing
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _buttonColor(label),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      if (label == '=') {
                        calc.calculate();
                      } else {
                        calc.addCharacter(label);
                      }
                    },
                    child: Text(
                      label,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  Color _buttonColor(String label) {
    if (label == '=' || label == '+' || label == '-' || label == '×' || label == '÷') {
      return Colors.indigoAccent;
    }
    return const Color(0xFF161617); // dark button
  }

  // Bottom row text button builder
  Widget _bottomActionButton(String text, CalculatorProvider calc, {Color? color}) {
    return Expanded(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? const Color(0xFF161617),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: () {
          if (text == 'C') {
            calc.clearExpression();
          } else {
            calc.addCharacter(text);
          }
        },
        child: Text(text, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
      ),
    );
  }

  // Bottom row icon button (backspace)
  Widget _bottomIconButton(IconData icon, CalculatorProvider calc, {Color? color}) {
    return Expanded(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? const Color(0xFF161617),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onPressed: calc.deleteCharacter,
        child: Icon(icon, size: 26),
      ),
    );
  }

  // Nav button (circle)
  Widget _navButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: CircleAvatar(
        radius: 28,
        backgroundColor: Colors.indigoAccent,
        child: Icon(icon, color: Colors.white, size: 26),
      ),
    );
  }

  // History panel
  Widget _historyPanel(BuildContext context, CalculatorProvider calc) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F0F10),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 8)],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('History', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Clear history',
                        onPressed: () async {
                          await calc.clearHistory();
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('History cleared')));
                        },
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: calc.toggleHistory,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  )
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white12),
            Expanded(
              child: calc.history.isEmpty
                  ? const Center(child: Text('No history yet', style: TextStyle(color: Colors.white54)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemCount: calc.history.length,
                      itemBuilder: (context, idx) {
                        final item = calc.history[idx];
                        return Card(
                          color: const Color(0xFF131314),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            title: Text(item, style: const TextStyle(fontSize: 16)),
                            trailing: IconButton(
                              icon: const Icon(Icons.upload, size: 20),
                              tooltip: 'Load',
                              onPressed: () {
                                // load only the left side (before =)
                                final parts = item.split('=');
                                final formula = parts.isNotEmpty ? parts[0].trim() : item;
                                calc.loadFormula(formula);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Loaded formula')));
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Saved formulas sheet (modal bottom sheet)
  Future<void> _showSavedSheet(BuildContext context, CalculatorProvider calc) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.25,
          maxChildSize: 0.9,
          builder: (context, sc) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0F0F10),
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Saved Formulas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            IconButton(
                              tooltip: 'Clear saved formulas',
                              onPressed: () async {
                                await calc.clearSavedFormulas();
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved formulas cleared')));
                                // close sheet
                                Navigator.of(context).pop();
                              },
                              icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                            ),
                            IconButton(
                              tooltip: 'Close',
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Colors.white12),
                  Expanded(
                    child: calc.savedFormulas.isEmpty
                        ? const Center(child: Text('No saved formulas', style: TextStyle(color: Colors.white54)))
                        : ListView.separated(
                            controller: sc,
                            padding: const EdgeInsets.all(12),
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemCount: calc.savedFormulas.length,
                            itemBuilder: (context, i) {
                              final f = calc.savedFormulas[i];
                              return Card(
                                color: const Color(0xFF131314),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: ListTile(
                                  title: Text(f),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Load',
                                        icon: const Icon(Icons.upload, size: 20),
                                        onPressed: () {
                                          calc.loadFormula(f);
                                          Navigator.of(context).pop();
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Loaded saved formula')));
                                        },
                                      ),
                                      IconButton(
                                        tooltip: 'Remove saved',
                                        icon: const Icon(Icons.delete_outline, color: Colors.white70),
                                        onPressed: () async {
                                          await calc.removeSavedFormulaAt(i);
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removed saved formula')));
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }
}

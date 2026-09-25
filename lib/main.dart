import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const green = Color(0xFF1B6E2E);
const red = Color(0xFFD32F2F);

String rs(double v) => '₹ ${v.toStringAsFixed(0)}';
String dt(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class Person {
  String id, name, phone;
  Person(this.id, this.name, this.phone);
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'phone': phone};
  factory Person.fromJson(Map j) => Person(j['id'], j['name'], j['phone'] ?? '');
}

class Txn {
  String id, personId, notes;
  double amount;
  bool gave, paid;
  DateTime date;
  Txn({
    required this.id,
    required this.personId,
    required this.amount,
    required this.gave,
    required this.date,
    this.notes = '',
    this.paid = false,
  });
  Map<String, dynamic> toJson() => {
        'id': id,
        'personId': personId,
        'amount': amount,
        'gave': gave,
        'date': date.toIso8601String(),
        'notes': notes,
        'paid': paid,
      };
  factory Txn.fromJson(Map j) => Txn(
        id: j['id'],
        personId: j['personId'],
        amount: (j['amount'] as num).toDouble(),
        gave: j['gave'],
        date: DateTime.parse(j['date']),
        notes: j['notes'] ?? '',
        paid: j['paid'] ?? false,
      );
}

class Store extends ChangeNotifier {
  List<Person> people = [];
  List<Txn> txns = [];

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString('data');
    if (s != null) {
      final m = jsonDecode(s);
      people = (m['people'] as List).map((e) => Person.fromJson(e)).toList();
      txns = (m['txns'] as List).map((e) => Txn.fromJson(e)).toList();
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
        'data',
        jsonEncode({
          'people': people.map((e) => e.toJson()).toList(),
          'txns': txns.map((e) => e.toJson()).toList(),
        }));
    notifyListeners();
  }

  String newId() => DateTime.now().microsecondsSinceEpoch.toString();
  String nameOf(String id) =>
      people.firstWhere((p) => p.id == id, orElse: () => Person('', '?', '')).name;

  String addPerson(String name, String phone) {
    final p = Person(newId(), name, phone);
    people.add(p);
    _save();
    return p.id;
  }

  void addTxn(Txn t) {
    txns.insert(0, t);
    txns.sort((a, b) => b.date.compareTo(a.date));
    _save();
  }

  void togglePaid(Txn t) {
    t.paid = !t.paid;
    _save();
  }

  void deleteTxn(Txn t) {
    txns.remove(t);
    _save();
  }

  // Pending amounts only
  double sum(bool gave, {String? pid}) => txns
      .where((t) => t.gave == gave && !t.paid && (pid == null || t.personId == pid))
      .fold(0.0, (a, t) => a + t.amount);
}

final store = Store();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await store.load();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Personal Lending Book',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: green),
          appBarTheme: const AppBarTheme(
              backgroundColor: green, foregroundColor: Colors.white),
        ),
        home: const Shell(),
      );
}

Future<String?> addPersonDialog(BuildContext context) {
  final name = TextEditingController();
  final phone = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Add Person'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Name *')),
        TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone (optional)')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (name.text.trim().isEmpty) return;
            Navigator.pop(c, store.addPerson(name.text.trim(), phone.text.trim()));
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(tab == 0 ? 'Personal Lending Book' : 'People'),
          actions: [
            if (tab == 1)
              IconButton(
                  icon: const Icon(Icons.person_add),
                  onPressed: () => addPersonDialog(context)),
          ],
        ),
        body: ListenableBuilder(
            listenable: store,
            builder: (c, _) => tab == 0 ? const HomePage() : const PeoplePage()),
        floatingActionButton: FloatingActionButton(
          backgroundColor: green,
          foregroundColor: Colors.white,
          onPressed: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const AddTxn())),
          child: const Icon(Icons.add),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (i) => setState(() => tab = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.people), label: 'People'),
          ],
        ),
      );
}

Widget summaryCard(String label, double v, Color color) => Expanded(
      child: Card(
        color: color.withOpacity(0.12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: color)),
            const SizedBox(height: 4),
            Text(rs(v),
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          ]),
        ),
      ),
    );

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    final gave = store.sum(true), owe = store.sum(false);
    return ListView(padding: const EdgeInsets.all(12), children: [
      Row(children: [
        summaryCard('You Gave', gave, green),
        summaryCard('You Owe', owe, red),
      ]),
      Card(
        child: ListTile(
          title: const Text('Total Balance'),
          subtitle: Text(gave >= owe ? 'You will get back' : 'You need to pay'),
          trailing: Text(rs((gave - owe).abs()),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ),
      ),
      const Padding(
        padding: EdgeInsets.fromLTRB(8, 12, 8, 4),
        child: Text('Recent Transactions',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      if (store.txns.isEmpty)
        const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('No transactions yet. Tap + to add.'))),
      ...store.txns.take(15).map((t) => TxnTile(t, showName: true)),
    ]);
  }
}

class TxnTile extends StatelessWidget {
  final Txn t;
  final bool showName;
  const TxnTile(this.t, {super.key, this.showName = false});
  @override
  Widget build(BuildContext context) {
    final color = t.gave ? green : red;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.12),
        child: Icon(t.gave ? Icons.north_east : Icons.south_west, color: color),
      ),
      title: Text(
        '${t.gave ? 'Gave' : 'Received'} ${rs(t.amount)}${showName ? ' • ${store.nameOf(t.personId)}' : ''}',
        style: TextStyle(
            decoration: t.paid ? TextDecoration.lineThrough : null,
            fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
          '${dt(t.date)} • ${t.paid ? 'Paid' : 'Pending'}${t.notes.isEmpty ? '' : ' • ${t.notes}'}'),
      trailing: PopupMenuButton<String>(
        onSelected: (v) => v == 'paid' ? store.togglePaid(t) : store.deleteTxn(t),
        itemBuilder: (_) => [
          PopupMenuItem(value: 'paid', child: Text(t.paid ? 'Mark pending' : 'Mark paid')),
          const PopupMenuItem(value: 'del', child: Text('Delete')),
        ],
      ),
    );
  }
}

class PeoplePage extends StatelessWidget {
  const PeoplePage({super.key});
  @override
  Widget build(BuildContext context) {
    if (store.people.isEmpty) {
      return const Center(child: Text('No people yet. Tap the person icon above.'));
    }
    return ListView(
      children: store.people.map((p) {
        final net = store.sum(true, pid: p.id) - store.sum(false, pid: p.id);
        return ListTile(
          leading: CircleAvatar(
              backgroundColor: green,
              child: Text(p.name[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white))),
          title: Text(p.name),
          subtitle: Text(net == 0 ? 'Settled' : (net > 0 ? 'You gave' : 'You owe')),
          trailing: Text(rs(net.abs()),
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: net >= 0 ? green : red)),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => PersonPage(p))),
        );
      }).toList(),
    );
  }
}

class PersonPage extends StatelessWidget {
  final Person p;
  const PersonPage(this.p, {super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (c, _) {
          final list = store.txns.where((t) => t.personId == p.id).toList();
          return Scaffold(
            appBar: AppBar(title: Text(p.name)),
            floatingActionButton: FloatingActionButton(
              backgroundColor: green,
              foregroundColor: Colors.white,
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => AddTxn(personId: p.id))),
              child: const Icon(Icons.add),
            ),
            body: ListView(padding: const EdgeInsets.all(12), children: [
              if (p.phone.isNotEmpty) Text('Phone: ${p.phone}'),
              Row(children: [
                summaryCard('Total You Gave', store.sum(true, pid: p.id), green),
                summaryCard('Total You Owe', store.sum(false, pid: p.id), red),
              ]),
              if (list.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('No transactions'))),
              ...list.map((t) => TxnTile(t)),
            ]),
          );
        },
      );
}

class AddTxn extends StatefulWidget {
  final String? personId;
  const AddTxn({super.key, this.personId});
  @override
  State<AddTxn> createState() => _AddTxnState();
}

class _AddTxnState extends State<AddTxn> {
  String? pid;
  bool gave = true, paid = false;
  DateTime date = DateTime.now();
  final amt = TextEditingController();
  final notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    pid = widget.personId;
  }

  void msg(String s) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  void save() {
    final a = double.tryParse(amt.text.trim());
    if (pid == null) return msg('Select a person');
    if (a == null || a <= 0) return msg('Enter a valid amount');
    store.addTxn(Txn(
        id: store.newId(),
        personId: pid!,
        amount: a,
        gave: gave,
        date: date,
        notes: notes.text.trim(),
        paid: paid));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Add Transaction')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('You Gave')),
              ButtonSegment(value: false, label: Text('You Owe')),
            ],
            selected: {gave},
            onSelectionChanged: (s) => setState(() => gave = s.first),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: pid,
                decoration: const InputDecoration(
                    labelText: 'Person *', border: OutlineInputBorder()),
                items: store.people
                    .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name)))
                    .toList(),
                onChanged: (v) => setState(() => pid = v),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: () async {
                final id = await addPersonDialog(context);
                if (id != null) setState(() => pid = id);
              },
            ),
          ]),
          const SizedBox(height: 16),
          TextField(
            controller: amt,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Amount *', prefixText: '₹ ', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          ListTile(
            shape: RoundedRectangleBorder(
                side: const BorderSide(color: Colors.grey),
                borderRadius: BorderRadius.circular(4)),
            title: Text('Date: ${dt(date)}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final d = await showDatePicker(
                  context: context,
                  initialDate: date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100));
              if (d != null) setState(() => date = d);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: notes,
            maxLines: 2,
            decoration: const InputDecoration(
                labelText: 'Notes (optional)', border: OutlineInputBorder()),
          ),
          SwitchListTile(
            title: const Text('Already paid / settled'),
            value: paid,
            onChanged: (v) => setState(() => paid = v),
          ),
          const SizedBox(height: 8),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: green, minimumSize: const Size.fromHeight(50)),
            onPressed: save,
            child: const Text('Save Transaction'),
          ),
        ]),
      );
}

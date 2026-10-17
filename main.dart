import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'models/appointment.dart';
import 'models/attachment.dart';
import 'models/financial_record.dart';
import 'models/patient.dart';
import 'services/database_helper.dart';
import 'utils/jalali_helper.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ClinicManagerApp());
}

class ClinicManagerApp extends StatelessWidget {
  const ClinicManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مدیریت مطب',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        fontFamily: 'Vazir',
      ),
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [Locale('fa', 'IR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;
  final _db = DatabaseHelper.instance;

  Future<void> _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(onChanged: _refresh),
      PatientsPage(onChanged: _refresh),
      FinancePage(onChanged: _refresh),
      const ReportsPage(),
    ];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('مدیریت مطب درمان سوءمصرف مواد'),
          centerTitle: true,
        ),
        body: pages[_index],
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard), label: 'داشبورد'),
            NavigationDestination(icon: Icon(Icons.people), label: 'بیماران'),
            NavigationDestination(
                icon: Icon(Icons.attach_money), label: 'مالی'),
            NavigationDestination(
                icon: Icon(Icons.assessment), label: 'گزارش'),
          ],
        ),
      ),
    );
  }
}

// ================= داشبورد =================
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.onChanged});
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final db = DatabaseHelper.instance;
    return RefreshIndicator(
      onRefresh: () async => onChanged(),
      child: FutureBuilder<List<dynamic>>(
        future: Future.wait([
          db.patientCount(),
          db.getUpcomingAppointments(),
          db.financialSummary(),
        ]),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('خطا در بارگذاری داشبورد: ${snap.error}'));
          }
          final patientCount = snap.data![0] as int;
          final upcoming = snap.data![1] as List<Appointment>;
          final summary = snap.data![2] as Map<String, int>;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('امروز: ${JalaliHelper.todayJalali()}',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text('تعداد بیماران: $patientCount'),
                      Text(
                          'درآمد: ${_fmt(summary['income'] ?? 0)} تومان'),
                      Text(
                          'هزینه: ${_fmt(summary['expense'] ?? 0)} تومان'),
                      Text(
                          'تراز: ${_fmt(summary['balance'] ?? 0)} تومان'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('نوبت‌های پیش‌رو',
                  style: Theme.of(context).textTheme.titleLarge),
              if (upcoming.isEmpty) const Text('نوبتی ثبت نشده است.'),
              ...upcoming.map((a) => FutureBuilder<Patient?>(
                    future: db.getPatient(a.patientId),
                    builder: (context, ps) {
                      final name = ps.data?.fullName ?? 'بیمار #${a.patientId}';
                      return ListTile(
                        leading: const Icon(Icons.event),
                        title: Text(name),
                        subtitle:
                            Text('${a.dateJalali} ${a.time ?? ''} ${a.reason ?? ''}'),
                      );
                    },
                  )),
            ],
          );
        },
      ),
    );
  }
}

String _fmt(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    b.write(s[i]);
    final left = s.length - 1 - i;
    if (left > 0 && left % 3 == 0) b.write(',');
  }
  return b.toString();
}

// ================= بیماران =================
class PatientsPage extends StatefulWidget {
  const PatientsPage({super.key, required this.onChanged});
  final VoidCallback onChanged;

  @override
  State<PatientsPage> createState() => _PatientsPageState();
}

class _PatientsPageState extends State<PatientsPage> {
  final _db = DatabaseHelper.instance;
  final _searchCtrl = TextEditingController();
  List<Patient>? _patients;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _db.getPatients(_query);
      if (!mounted) return;
      setState(() => _patients = list);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطا در خواندن بیماران: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    labelText: 'جست‌وجو (نام، تلفن، کد ملی)',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) {
                    _query = v;
                    _load();
                  },
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => PatientFormPage()));
                  _load();
                },
                icon: const Icon(Icons.add),
                label: const Text('بیمار جدید'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _patients == null
              ? const Center(child: CircularProgressIndicator())
              : _patients!.isEmpty
                  ? const Center(child: Text('بیماری یافت نشد.'))
                  : ListView.builder(
                      itemCount: _patients!.length,
                      itemBuilder: (context, i) {
                        final p = _patients![i];
                        return Card(
                          child: ListTile(
                            title: Text(p.fullName),
                            subtitle: Text(
                                'تلفن: ${p.phone ?? "-"}  |  ثبت: ${p.createdAtJalali}'),
                            trailing: const Icon(Icons.chevron_left),
                            onTap: () async {
                              await Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) =>
                                      PatientDetailPage(patientId: p.id!)));
                              _load();
                            },
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

// فرم ثبت/ویرایش بیمار
class PatientFormPage extends StatefulWidget {
  const PatientFormPage({super.key});

  @override
  State<PatientFormPage> createState() => _PatientFormPageState();
}

class _PatientFormPageState extends State<PatientFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseHelper.instance;
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _nid = TextEditingController();
  final _birth = TextEditingController();
  final _notes = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _nid.dispose();
    _birth.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await _db.insertPatient(Patient(
        fullName: _name.text.trim(),
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        nationalId: _nid.text.trim().isEmpty ? null : _nid.text.trim(),
        birthJalali: _birth.text.trim().isEmpty ? null : _birth.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        createdAtJalali: JalaliHelper.todayJalali(),
      ));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('بیمار ثبت شد.')));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطا در ثبت بیمار: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('ثبت بیمار جدید')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                      labelText: 'نام و نام خانوادگی *'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'نام الزامی است' : null,
                ),
                TextFormField(
                  controller: _phone,
                  decoration:
                      const InputDecoration(labelText: 'شماره تماس'),
                  keyboardType: TextInputType.phone,
                ),
                TextFormField(
                  controller: _nid,
                  decoration:
                      const InputDecoration(labelText: 'کد ملی'),
                  keyboardType: TextInputType.number,
                ),
                TextFormField(
                  controller: _birth,
                  decoration: const InputDecoration(
                      labelText: 'تاریخ تولد شمسی (مثال: 1380/05/12)'),
                  keyboardType: TextInputType.datetime,
                ),
                TextFormField(
                  controller: _notes,
                  decoration:
                      const InputDecoration(labelText: 'یادداشت'),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _save,
                  child: const Text('ذخیره'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ================= جزئیات بیمار =================
class PatientDetailPage extends StatefulWidget {
  const PatientDetailPage({super.key, required this.patientId});
  final int patientId;

  @override
  State<PatientDetailPage> createState() => _PatientDetailPageState();
}

class _PatientDetailPageState extends State<PatientDetailPage> {
  final _db = DatabaseHelper.instance;
  Patient? _patient;
  List<Appointment>? _appointments;
  List<Attachment>? _attachments;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await _db.getPatient(widget.patientId);
      final aps = await _db.getAppointmentsFor(widget.patientId);
      final atts = await _db.getAttachmentsFor(widget.patientId);
      if (!mounted) return;
      setState(() {
        _patient = p;
        _appointments = aps;
        _attachments = atts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطا در بارگذاری بیمار: $e')));
    }
  }

  Future<void> _addAppointment() async {
    final dateCtrl = TextEditingController(text: JalaliHelper.todayJalali());
    final timeCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('ثبت نوبت'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: dateCtrl,
                decoration: const InputDecoration(
                    labelText: 'تاریخ شمسی (1403/05/12)'),
              ),
              TextField(
                controller: timeCtrl,
                decoration: const InputDecoration(labelText: 'ساعت (اختیاری)'),
              ),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(labelText: 'علت (اختیاری)'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('انصراف')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('ذخیره')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    if (JalaliHelper.parse(dateCtrl.text) == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تاریخ نامعتبر است. فرمت: 1403/05/12')));
      return;
    }
    try {
      await _db.insertAppointment(Appointment(
        patientId: widget.patientId,
        dateJalali: dateCtrl.text.trim(),
        time: timeCtrl.text.trim().isEmpty ? null : timeCtrl.text.trim(),
        reason: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
      ));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('نوبت ثبت شد.')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطا در ثبت نوبت: $e')));
    }
  }

  Future<void> _pickAttachment() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: false,
      );
      final picked = result?.files.single;
      if (picked == null || picked.path == null) return;
      await _db.saveAttachment(
        patientId: widget.patientId,
        sourcePath: picked.path!,
        originalName: picked.name,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('فایل ذخیره شد.')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطا در بارگذاری فایل: $e')));
    }
  }

  Future<void> _openAttachment(Attachment a) async {
    final exists = await _db.attachmentFileExists(a);
    if (!mounted) return;
    if (!exists) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('فایل در مسیر زیر یافت نشد:\n${a.localPath}')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('مسیر فایل: ${a.localPath}')));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(_patient?.fullName ?? 'جزئیات بیمار')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_patient?.fullName ?? '',
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 8),
                          Text('تلفن: ${_patient?.phone ?? "-"}'),
                          Text('کد ملی: ${_patient?.nationalId ?? "-"}'),
                          Text('تاریخ تولد: ${_patient?.birthJalali ?? "-"}'),
                          Text('یادداشت: ${_patient?.notes ?? "-"}'),
                          Text('تاریخ ثبت: ${_patient?.createdAtJalali}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: _addAppointment,
                        icon: const Icon(Icons.event),
                        label: const Text('ثبت نوبت'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonalIcon(
                        onPressed: _pickAttachment,
                        icon: const Icon(Icons.attach_file),
                        label: const Text('افزودن فایل/تصویر'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('نوبت‌ها',
                      style: Theme.of(context).textTheme.titleMedium),
                  if (_appointments == null || _appointments!.isEmpty)
                    const Text('نوبتی ثبت نشده است.'),
                  ...?_appointments?.map((a) => ListTile(
                        leading: const Icon(Icons.event_note),
                        title: Text(a.dateJalali),
                        subtitle: Text(
                            '${a.time ?? ''} ${a.reason ?? ''} ${a.done ? "(انجام شده)" : ""}'),
                      )),
                  const SizedBox(height: 12),
                  Text('پیوست‌ها',
                      style: Theme.of(context).textTheme.titleMedium),
                  if (_attachments == null || _attachments!.isEmpty)
                    const Text('فایلی ثبت نشده است.'),
                  ...?_attachments?.map((a) => ListTile(
                        leading: const Icon(Icons.insert_drive_file),
                        title: Text(a.fileName),
                        subtitle: Text(a.localPath),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () async {
                            await _db.deleteAttachment(a);
                            _load();
                          },
                        ),
                        onTap: () => _openAttachment(a),
                      )),
                ],
              ),
      ),
    );
  }
}

// ================= مالی =================
class FinancePage extends StatefulWidget {
  const FinancePage({super.key, required this.onChanged});
  final VoidCallback onChanged;

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  final _db = DatabaseHelper.instance;
  List<FinancialRecord>? _records;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _db.getFinancialRecords();
      if (!mounted) return;
      setState(() => _records = list);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطا در خواندن سوابق مالی: $e')));
    }
  }

  Future<void> _addRecord(FinancialType type) async {
    final amountCtrl = TextEditingController();
    final dateCtrl = TextEditingController(text: JalaliHelper.todayJalali());
    final descCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title:
              Text(type == FinancialType.income ? 'ثبت درآمد' : 'ثبت هزینه'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'مبلغ (تومان) *'),
              ),
              TextField(
                controller: dateCtrl,
                decoration: const InputDecoration(
                    labelText: 'تاریخ شمسی (1403/05/12)'),
              ),
              TextField(
                controller: descCtrl,
                decoration:
                    const InputDecoration(labelText: 'توضیح (اختیاری)'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('انصراف')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('ذخیره')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final amount = int.tryParse(amountCtrl.text.trim().replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('مبلغ نامعتبر است (تومان، عدد صحیح).')));
      return;
    }
    if (JalaliHelper.parse(dateCtrl.text) == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تاریخ نامعتبر است. فرمت: 1403/05/12')));
      return;
    }
    try {
      await _db.insertFinancialRecord(FinancialRecord(
        type: type,
        amountTomans: amount,
        dateJalali: dateCtrl.text.trim(),
        description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
      ));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ثبت شد.')));
      _load();
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطا در ثبت: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _addRecord(FinancialType.income),
                  icon: const Icon(Icons.south_west),
                  label: const Text('درآمد'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => _addRecord(FinancialType.expense),
                  icon: const Icon(Icons.north_east),
                  label: const Text('هزینه'),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _records == null
              ? const Center(child: CircularProgressIndicator())
              : _records!.isEmpty
                  ? const Center(child: Text('رکوردی ثبت نشده است.'))
                  : ListView.builder(
                      itemCount: _records!.length,
                      itemBuilder: (context, i) {
                        final r = _records![i];
                        final isIn = r.type == FinancialType.income;
                        return ListTile(
                          leading: Icon(
                            isIn ? Icons.add_circle : Icons.remove_circle,
                            color: isIn ? Colors.green : Colors.red,
                          ),
                          title: Text('${_fmt(r.amountTomans)} تومان'),
                          subtitle: Text(
                              '${r.dateJalali}  ${r.description ?? ''}'),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

// ================= گزارش =================
class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final db = DatabaseHelper.instance;
    return FutureBuilder<Map<String, int>>(
      future: db.financialSummary(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('خطا در گزارش: ${snap.error}'));
        }
        final s = snap.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('جمع مبالغ (تومان)',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text('جمع درآمد: ${_fmt(s['income'] ?? 0)}'),
                    Text('جمع هزینه: ${_fmt(s['expense'] ?? 0)}'),
                    Text('تراز: ${_fmt(s['balance'] ?? 0)}'),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

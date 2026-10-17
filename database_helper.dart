import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/appointment.dart';
import '../models/attachment.dart';
import '../models/financial_record.dart';
import '../models/patient.dart';
import '../utils/jalali_helper.dart';

/// سرویس پایگاه‌داده محلی SQLite (تک‌کاربره، آفلاین).
/// روی ویندوز/دسکتاپ از sqflite_common_ffi و روی اندروید از sqflite استفاده می‌شود.
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  Database? _db;
  bool _ffiInitialized = false;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      if (!_ffiInitialized) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        _ffiInitialized = true;
      }
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final dbDir = p.join(docsDir.path, 'ClinicData');
    await Directory(dbDir).create(recursive: true);
    final dbPath = p.join(dbDir, 'clinic_manager.db');

    return openDatabase(dbPath, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute(
        'CREATE TABLE patients (id INTEGER PRIMARY KEY AUTOINCREMENT, full_name TEXT NOT NULL, phone TEXT, national_id TEXT, birth_jalali TEXT, notes TEXT, created_at_jalali TEXT NOT NULL)');
    await db.execute(
        'CREATE TABLE appointments (id INTEGER PRIMARY KEY AUTOINCREMENT, patient_id INTEGER NOT NULL, date_jalali TEXT NOT NULL, time TEXT, reason TEXT, done INTEGER NOT NULL DEFAULT 0)');
    await db.execute(
        'CREATE TABLE financial_records (id INTEGER PRIMARY KEY AUTOINCREMENT, type TEXT NOT NULL, amount_tomans INTEGER NOT NULL, date_jalali TEXT NOT NULL, description TEXT, patient_id INTEGER)');
    await db.execute(
        'CREATE TABLE attachments (id INTEGER PRIMARY KEY AUTOINCREMENT, patient_id INTEGER NOT NULL, file_name TEXT NOT NULL, local_path TEXT NOT NULL, created_at_jalali TEXT NOT NULL)');
  }

  // ---------- Patients ----------
  Future<int> insertPatient(Patient patient) async {
    final db = await database;
    return db.insert('patients', patient.toMap());
  }

  Future<List<Patient>> getPatients(String? query) async {
    final db = await database;
    if (query == null || query.trim().isEmpty) {
      final rows = await db.query('patients', orderBy: 'full_name COLLATE NOCASE');
      return rows.map(Patient.fromMap).toList();
    }
    final q = '%${query.trim()}%';
    final rows = await db.query('patients',
        where: 'full_name LIKE ? OR phone LIKE ? OR national_id LIKE ?',
        whereArgs: [q, q, q],
        orderBy: 'full_name COLLATE NOCASE');
    return rows.map(Patient.fromMap).toList();
  }

  Future<Patient?> getPatient(int id) async {
    final db = await database;
    final rows =
        await db.query('patients', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Patient.fromMap(rows.first);
  }

  // ---------- Appointments ----------
  Future<int> insertAppointment(Appointment a) async {
    final db = await database;
    return db.insert('appointments', a.toMap());
  }

  Future<List<Appointment>> getAppointmentsFor(int patientId) async {
    final db = await database;
    final rows = await db.query('appointments',
        where: 'patient_id = ?',
        whereArgs: [patientId],
        orderBy: 'date_jalali DESC');
    return rows.map(Appointment.fromMap).toList();
  }

  Future<List<Appointment>> getUpcomingAppointments() async {
    final db = await database;
    final rows = await db.query('appointments',
        where: 'done = 0', orderBy: 'date_jalali ASC', limit: 20);
    return rows.map(Appointment.fromMap).toList();
  }

  // ---------- Financial ----------
  Future<int> insertFinancialRecord(FinancialRecord r) async {
    final db = await database;
    return db.insert('financial_records', r.toMap());
  }

  Future<List<FinancialRecord>> getFinancialRecords() async {
    final db = await database;
    final rows = await db
        .query('financial_records', orderBy: 'date_jalali DESC, id DESC');
    return rows.map(FinancialRecord.fromMap).toList();
  }

  /// جمع درآمد، هزینه و تراز (تومان).
  Future<Map<String, int>> financialSummary() async {
    final db = await database;
    final incomeRes = await db.rawQuery(
        "SELECT COALESCE(SUM(amount_tomans), 0) AS s FROM financial_records WHERE type = 'income'");
    final expenseRes = await db.rawQuery(
        "SELECT COALESCE(SUM(amount_tomans), 0) AS s FROM financial_records WHERE type = 'expense'");
    int toInt(dynamic v) => v is int ? v : (v is num ? v.toInt() : 0);
    final income = toInt(incomeRes.first['s']);
    final expense = toInt(expenseRes.first['s']);
    return {'income': income, 'expense': expense, 'balance': income - expense};
  }

  // ---------- Attachments ----------
  /// پوشه دائمی پیوست‌ها: Documents/ClinicData/Attachments
  Future<Directory> attachmentsDir() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docsDir.path, 'ClinicData', 'Attachments'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// کپی فایل انتخاب‌شده به پوشه دائمی و ثبت مسیر آن در SQLite.
  Future<Attachment> saveAttachment({
    required int patientId,
    required String sourcePath,
    required String originalName,
  }) async {
    final db = await database;
    final dir = await attachmentsDir();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final safeName = originalName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final destPath = p.join(dir.path, '${ts}_$safeName');
    try {
      await File(sourcePath).copy(destPath);
    } on FileSystemException catch (e) {
      throw Exception('کپی فایل ناموفق بود: ${e.message}');
    }
    final att = Attachment(
      patientId: patientId,
      fileName: safeName,
      localPath: destPath,
      createdAtJalali: JalaliHelper.todayJalali(),
    );
    final id = await db.insert('attachments', att.toMap());
    return Attachment(
      id: id,
      patientId: att.patientId,
      fileName: att.fileName,
      localPath: att.localPath,
      createdAtJalali: att.createdAtJalali,
    );
  }

  Future<List<Attachment>> getAttachmentsFor(int patientId) async {
    final db = await database;
    final rows = await db.query('attachments',
        where: 'patient_id = ?',
        whereArgs: [patientId],
        orderBy: 'id DESC');
    return rows.map(Attachment.fromMap).toList();
  }

  Future<bool> attachmentFileExists(Attachment a) async =>
      await File(a.localPath).exists();

  Future<int> deleteAttachment(Attachment a) async {
    try {
      final f = File(a.localPath);
      if (await f.exists()) await f.delete();
    } catch (_) {
      // حذف فیزیکی فایل حیاتی نیست؛ رکورد حذف می‌شود.
    }
    final db = await database;
    return db.delete('attachments', where: 'id = ?', whereArgs: [a.id]);
  }

  // ---------- Dashboard ----------
  Future<int> patientCount() async {
    final db = await database;
    final r = await db.rawQuery('SELECT COUNT(*) AS c FROM patients');
    final v = r.first['c'];
    return v is int ? v : (v as num).toInt();
  }
}

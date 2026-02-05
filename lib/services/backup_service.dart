import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';
import 'package:archive/archive.dart';
import '../config/constants.dart';

/// خدمة النسخ الاحتياطي على Google Drive
class BackupService {
  static final BackupService _instance = BackupService._internal();
  factory BackupService() => _instance;
  BackupService._internal();

  // Google Sign In مع صلاحيات Drive
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      drive.DriveApi.driveFileScope, // للوصول لملفات التطبيق
      drive.DriveApi.driveAppdataScope, // للوصول لمجلد بيانات التطبيق
    ],
  );

  GoogleSignInAccount? _currentUser;
  drive.DriveApi? _driveApi;

  // Getters
  bool get isSignedIn => _currentUser != null;
  String? get userEmail => _currentUser?.email;
  String? get userName => _currentUser?.displayName;
  String? get userPhoto => _currentUser?.photoUrl;

  /// تسجيل الدخول بحساب Google
  Future<bool> signIn() async {
    try {
      _currentUser = await _googleSignIn.signIn();
      if (_currentUser == null) return false;

      // إنشاء Drive API client
      final authHeaders = await _currentUser!.authHeaders;
      final authenticatedClient = GoogleAuthClient(authHeaders);
      _driveApi = drive.DriveApi(authenticatedClient);

      return true;
    } catch (e) {
      debugPrint('Error signing in: $e');
      return false;
    }
  }

  /// تسجيل الخروج
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
    _driveApi = null;
  }

  /// التحقق من تسجيل الدخول السابق
  Future<bool> checkPreviousSignIn() async {
    try {
      _currentUser = await _googleSignIn.signInSilently();
      if (_currentUser != null) {
        final authHeaders = await _currentUser!.authHeaders;
        final authenticatedClient = GoogleAuthClient(authHeaders);
        _driveApi = drive.DriveApi(authenticatedClient);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error checking previous sign in: $e');
      return false;
    }
  }

  /// النسخ الاحتياطي إلى Google Drive
  Future<BackupResult> backup() async {
    if (_driveApi == null) {
      return BackupResult(success: false, message: 'لم يتم تسجيل الدخول');
    }

    try {
      // 1. إغلاق صناديق Hive مؤقتاً للتأكد من حفظ البيانات
      await Hive.close();

      // 2. الحصول على مسار ملفات Hive
      final appDir = await getApplicationDocumentsDirectory();
      final hiveDir = Directory(appDir.path);

      // 3. ضغط ملفات Hive
      final archive = Archive();
      final hiveFiles = hiveDir.listSync().where((f) => 
          f.path.endsWith('.hive') || f.path.endsWith('.lock'));

      for (var file in hiveFiles) {
        if (file is File) {
          final bytes = await file.readAsBytes();
          final fileName = file.path.split(Platform.pathSeparator).last;
          archive.addFile(ArchiveFile(fileName, bytes.length, bytes));
        }
      }

      final zipData = ZipEncoder().encode(archive);
      if (zipData == null) {
        // إعادة فتح Hive
        await _reopenHive();
        return BackupResult(success: false, message: 'فشل في ضغط الملفات');
      }

      // 4. البحث عن ملف النسخة الاحتياطية السابق أو إنشاء جديد
      final fileName = 'ahmed_debts_backup.zip';
      String? existingFileId = await _findBackupFile(fileName);

      // 5. رفع الملف
      final media = drive.Media(
        Stream.value(zipData),
        zipData.length,
      );

      if (existingFileId != null) {
        // تحديث الملف الموجود
        await _driveApi!.files.update(
          drive.File()..name = fileName,
          existingFileId,
          uploadMedia: media,
        );
      } else {
        // إنشاء ملف جديد في Drive الرئيسي
        await _driveApi!.files.create(
          drive.File()..name = fileName,
          uploadMedia: media,
        );
      }

      // 6. حفظ تاريخ آخر نسخة احتياطية
      await _saveLastBackupDate();

      // 7. إعادة فتح Hive
      await _reopenHive();

      debugPrint('✅ Backup successful! File uploaded to Google Drive');
      return BackupResult(
        success: true,
        message: 'تم النسخ الاحتياطي بنجاح',
        date: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Backup error: $e');
      await _reopenHive();
      return BackupResult(success: false, message: 'خطأ: $e');
    }
  }

  /// استعادة البيانات من Google Drive
  Future<BackupResult> restore() async {
    if (_driveApi == null) {
      return BackupResult(success: false, message: 'لم يتم تسجيل الدخول');
    }

    try {
      // 1. البحث عن ملف النسخة الاحتياطية
      final fileName = 'ahmed_debts_backup.zip';
      String? fileId = await _findBackupFile(fileName);

      if (fileId == null) {
        return BackupResult(success: false, message: 'لا توجد نسخة احتياطية');
      }

      // 2. تنزيل الملف
      final response = await _driveApi!.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final List<int> dataStore = [];
      await for (var data in response.stream) {
        dataStore.addAll(data);
      }

      // 3. إغلاق Hive
      await Hive.close();

      // 4. فك ضغط الملفات
      final archive = ZipDecoder().decodeBytes(dataStore);
      final appDir = await getApplicationDocumentsDirectory();

      for (var file in archive) {
        if (file.isFile) {
          final outputFile = File('${appDir.path}/${file.name}');
          await outputFile.writeAsBytes(file.content as List<int>);
        }
      }

      // 5. إعادة فتح Hive
      await _reopenHive();

      return BackupResult(
        success: true,
        message: 'تم استعادة البيانات بنجاح',
      );
    } catch (e) {
      debugPrint('Restore error: $e');
      await _reopenHive();
      return BackupResult(success: false, message: 'خطأ: $e');
    }
  }

  /// الحصول على تاريخ آخر نسخة احتياطية
  Future<DateTime?> getLastBackupDate() async {
    try {
      final box = await Hive.openBox('settings');
      final dateStr = box.get('lastBackupDate');
      if (dateStr != null) {
        return DateTime.parse(dateStr);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// حفظ تاريخ آخر نسخة احتياطية
  Future<void> _saveLastBackupDate() async {
    final box = await Hive.openBox('settings');
    await box.put('lastBackupDate', DateTime.now().toIso8601String());
  }

  /// البحث عن ملف النسخة الاحتياطية
  Future<String?> _findBackupFile(String fileName) async {
    try {
      final fileList = await _driveApi!.files.list(
        spaces: 'drive',
        q: "name = '$fileName' and trashed = false",
      );
      if (fileList.files != null && fileList.files!.isNotEmpty) {
        return fileList.files!.first.id;
      }
      return null;
    } catch (e) {
      debugPrint('Error finding backup file: $e');
      return null;
    }
  }

  /// إعادة فتح صناديق Hive
  Future<void> _reopenHive() async {
    await Hive.openBox(AppConstants.customersBox);
    await Hive.openBox(AppConstants.transactionsBox);
    await Hive.openBox('settings');
  }

  /// النسخ الاحتياطي التلقائي (يعمل في الخلفية)
  /// يُستدعى تلقائياً بعد أي تغيير في البيانات
  static Future<void> autoBackup() async {
    try {
      final service = BackupService();
      
      // التحقق من تسجيل الدخول السابق
      final isSignedIn = await service.checkPreviousSignIn();
      if (!isSignedIn) {
        debugPrint('⚠️ Auto-backup skipped: Not signed in to Google');
        return;
      }
      
      // التحقق من تفعيل النسخ التلقائي
      final settingsBox = Hive.box(AppConstants.settingsBox);
      final autoBackupEnabled = settingsBox.get('auto_backup_enabled', defaultValue: true);
      if (!autoBackupEnabled) {
        debugPrint('⚠️ Auto-backup skipped: Disabled in settings');
        return;
      }
      
      // تنفيذ النسخ الاحتياطي
      debugPrint('🔄 Starting auto-backup...');
      final result = await service.backup();
      
      if (result.success) {
        debugPrint('✅ Auto-backup completed successfully');
      } else {
        debugPrint('❌ Auto-backup failed: ${result.message}');
      }
    } catch (e) {
      debugPrint('❌ Auto-backup error: $e');
    }
  }

  /// حفظ إعداد النسخ التلقائي
  static Future<void> setAutoBackupEnabled(bool enabled) async {
    final settingsBox = Hive.box(AppConstants.settingsBox);
    await settingsBox.put('auto_backup_enabled', enabled);
  }

  /// التحقق من تفعيل النسخ التلقائي
  static bool isAutoBackupEnabled() {
    try {
      final settingsBox = Hive.box(AppConstants.settingsBox);
      return settingsBox.get('auto_backup_enabled', defaultValue: true);
    } catch (e) {
      return true;
    }
  }
}

/// نتيجة عملية النسخ الاحتياطي
class BackupResult {
  final bool success;
  final String message;
  final DateTime? date;

  BackupResult({
    required this.success,
    required this.message,
    this.date,
  });
}

/// HTTP Client مع headers المصادقة
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}

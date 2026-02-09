// ignore_for_file: avoid_print
import 'dart:io';
import 'package:yaml/yaml.dart';

/// سكربت تطبيق الإعدادات من app_config.yaml على ملفات المشروع
/// 
/// الاستخدام:
///   dart run scripts/apply_config.dart
/// 
/// هذا السكربت يحدّث:
///   - android/app/src/main/AndroidManifest.xml (اسم التطبيق)
///   - pubspec.yaml (الوصف)

void main() async {
  print('═══════════════════════════════════════════════════════════════');
  print('              🔧 تطبيق الإعدادات من app_config.yaml');
  print('═══════════════════════════════════════════════════════════════');
  print('');

  // قراءة ملف الإعدادات
  final configFile = File('app_config.yaml');
  if (!configFile.existsSync()) {
    print('❌ خطأ: ملف app_config.yaml غير موجود!');
    exit(1);
  }

  final yamlString = configFile.readAsStringSync();
  final config = loadYaml(yamlString);

  final appName = config['app']['name'] as String;
  final appNameEnglish = config['app']['name_english'] as String;

  print('📱 اسم التطبيق: $appName');
  print('📱 الاسم بالإنجليزي: $appNameEnglish');
  print('');

  // ═══════════════════════════════════════════════════════════════
  // تحديث AndroidManifest.xml
  // ═══════════════════════════════════════════════════════════════
  print('📝 تحديث AndroidManifest.xml...');
  
  final manifestFile = File('android/app/src/main/AndroidManifest.xml');
  if (manifestFile.existsSync()) {
    var manifestContent = manifestFile.readAsStringSync();
    
    // استبدال android:label
    final labelRegex = RegExp(r'android:label="[^"]*"');
    if (labelRegex.hasMatch(manifestContent)) {
      manifestContent = manifestContent.replaceAll(
        labelRegex, 
        'android:label="$appName"'
      );
      manifestFile.writeAsStringSync(manifestContent);
      print('   ✅ تم تحديث اسم التطبيق في AndroidManifest.xml');
    } else {
      print('   ⚠️ لم يتم العثور على android:label');
    }
  } else {
    print('   ❌ ملف AndroidManifest.xml غير موجود!');
  }

  // ═══════════════════════════════════════════════════════════════
  // تحديث pubspec.yaml
  // ═══════════════════════════════════════════════════════════════
  print('📝 تحديث pubspec.yaml...');
  
  final pubspecFile = File('pubspec.yaml');
  if (pubspecFile.existsSync()) {
    var pubspecContent = pubspecFile.readAsStringSync();
    
    // استبدال description
    final descRegex = RegExp(r'description:\s*"[^"]*"');
    if (descRegex.hasMatch(pubspecContent)) {
      pubspecContent = pubspecContent.replaceAll(
        descRegex, 
        'description: "تطبيق $appName"'
      );
      pubspecFile.writeAsStringSync(pubspecContent);
      print('   ✅ تم تحديث الوصف في pubspec.yaml');
    } else {
      // جرب بدون علامات اقتباس
      final descRegex2 = RegExp(r'description:\s*[^\n]+');
      if (descRegex2.hasMatch(pubspecContent)) {
        pubspecContent = pubspecContent.replaceAll(
          descRegex2, 
          'description: "تطبيق $appName"'
        );
        pubspecFile.writeAsStringSync(pubspecContent);
        print('   ✅ تم تحديث الوصف في pubspec.yaml');
      }
    }
  } else {
    print('   ❌ ملف pubspec.yaml غير موجود!');
  }

  print('');
  print('═══════════════════════════════════════════════════════════════');
  print('              ✅ تم تطبيق الإعدادات بنجاح!');
  print('═══════════════════════════════════════════════════════════════');
  print('');
  print('📋 الخطوات التالية:');
  print('   1. flutter pub get');
  print('   2. flutter build apk --release');
  print('');
}

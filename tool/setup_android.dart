// Run once after `flutter create`:  dart run tool/setup_android.dart
//
// Patches the generated Android project for scheduled notifications:
//  - enables core library desugaring (required by flutter_local_notifications)
//  - adds notification / boot / internet permissions and the plugin's receivers
//  - sets the app label to "Hero Time"
import 'dart:io';

const _desugarDep = 'com.android.tools:desugar_jdk_libs:2.1.4';

void main() {
  _patchGradle();
  _patchManifest();
  stdout.writeln('\nDone. Now run:  flutter pub get && flutter run');
}

void _patchGradle() {
  final kts = File('android/app/build.gradle.kts');
  final groovy = File('android/app/build.gradle');

  if (kts.existsSync()) {
    var s = kts.readAsStringSync();
    if (!s.contains('isCoreLibraryDesugaringEnabled')) {
      if (!s.contains('compileOptions {')) {
        _fail('Could not find "compileOptions {" in ${kts.path}. Add isCoreLibraryDesugaringEnabled = true manually.');
      }
      s = s.replaceFirst('compileOptions {', 'compileOptions {\n        isCoreLibraryDesugaringEnabled = true');
    }
    if (!s.contains('desugar_jdk_libs')) {
      s += '\ndependencies {\n    coreLibraryDesugaring("$_desugarDep")\n}\n';
    }
    kts.writeAsStringSync(s);
    stdout.writeln('✓ ${kts.path}: desugaring enabled');
  } else if (groovy.existsSync()) {
    var s = groovy.readAsStringSync();
    if (!s.contains('coreLibraryDesugaringEnabled')) {
      if (!s.contains('compileOptions {')) {
        _fail('Could not find "compileOptions {" in ${groovy.path}. Add coreLibraryDesugaringEnabled true manually.');
      }
      s = s.replaceFirst('compileOptions {', 'compileOptions {\n        coreLibraryDesugaringEnabled true');
    }
    if (!s.contains('desugar_jdk_libs')) {
      s += "\ndependencies {\n    coreLibraryDesugaring '$_desugarDep'\n}\n";
    }
    groovy.writeAsStringSync(s);
    stdout.writeln('✓ ${groovy.path}: desugaring enabled');
  } else {
    _fail('No android/app/build.gradle(.kts). Run `flutter create --platforms=android .` first.');
  }
}

void _patchManifest() {
  final f = File('android/app/src/main/AndroidManifest.xml');
  if (!f.existsSync()) _fail('Missing ${f.path}. Run `flutter create --platforms=android .` first.');
  var s = f.readAsStringSync();

  const perms = [
    'android.permission.INTERNET',
    'android.permission.POST_NOTIFICATIONS',
    'android.permission.RECEIVE_BOOT_COMPLETED',
    'android.permission.VIBRATE',
    'android.permission.USE_EXACT_ALARM', // reminders fire on time (auto-granted, Android 13+)
  ];
  final missing = perms.where((p) => !s.contains('"$p"')).map((p) => '    <uses-permission android:name="$p"/>\n').join();
  if (missing.isNotEmpty) {
    final i = s.indexOf('<application');
    s = s.substring(0, i) + missing + '\n    ' + s.substring(i);
  }
  if (!s.contains('SCHEDULE_EXACT_ALARM')) {
    // Android 12 has no USE_EXACT_ALARM; it uses this user-grantable one instead.
    final i = s.indexOf('<application');
    s = s.substring(0, i) +
        '<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" android:maxSdkVersion="32"/>\n\n    ' +
        s.substring(i);
  }

  if (!s.contains('ScheduledNotificationReceiver')) {
    const receivers = '''
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
''';
    final i = s.lastIndexOf('</application>');
    s = s.substring(0, i) + receivers + '    ' + s.substring(i);
  }

  s = s.replaceFirst(RegExp(r'android:label="[^"]*"'), 'android:label="Hero Time"');
  f.writeAsStringSync(s);
  stdout.writeln('✓ ${f.path}: permissions, receivers, label');
}

Never _fail(String msg) {
  stderr.writeln('✗ $msg');
  exit(1);
}

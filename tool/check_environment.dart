import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  try {
    if (arguments.any((argument) => argument != '--android')) {
      throw ArgumentError('利用できるオプションは --android のみです。');
    }
    final fvm = jsonDecode(File('.fvmrc').readAsStringSync()) as Map;
    final chain =
        jsonDecode(File('tool/toolchain.json').readAsStringSync()) as Map;
    // Prefer the Flutter SDK containing this Dart executable, including FVM.
    final flutterBin = File(
      Platform.resolvedExecutable,
    ).parent.parent.parent.parent;
    final flutterName = Platform.isWindows ? 'flutter.bat' : 'flutter';
    final siblingFlutter = File('${flutterBin.path}/$flutterName');
    final localFlutter = File('.fvm/flutter_sdk/bin/$flutterName');
    final executable = siblingFlutter.existsSync()
        ? siblingFlutter.absolute.path
        : localFlutter.existsSync()
        ? localFlutter.absolute.path
        : 'flutter';
    final result = await Process.run(executable, [
      '--version',
      '--machine',
    ], runInShell: Platform.isWindows);
    if (result.exitCode != 0) {
      throw StateError('flutter --version が失敗しました: ${result.stderr}');
    }
    final output = result.stdout as String;
    final actual = jsonDecode(output.substring(output.indexOf('{'))) as Map;
    final flutter = actual['frameworkVersion'] as String;
    final dart = (actual['dartSdkVersion'] as String).split(' ').first;
    final runningDart = Platform.version.split(' ').first;
    final problems = <String>[
      if (flutter != fvm['flutter']) 'Flutter: $flutter（必要: ${fvm['flutter']}）',
      if (dart != chain['dart']) 'Flutter同梱Dart: $dart（必要: ${chain['dart']}）',
      if (runningDart != chain['dart'])
        '実行中のDart: $runningDart（必要: ${chain['dart']}）',
    ];
    if (arguments.contains('--android')) {
      final java = await Process.run('java', [
        '-version',
      ], runInShell: Platform.isWindows);
      final version = RegExp(
        r'version "(\d+)',
      ).firstMatch('${java.stderr}\n${java.stdout}')?.group(1);
      if (java.exitCode != 0 || version != chain['java']) {
        problems.add('Java: ${version ?? "取得できません"}（必要: ${chain['java']}）');
      }
    }
    if (problems.isNotEmpty) throw StateError(problems.join('\n'));
    stdout.writeln('OK: Flutter ${fvm['flutter']} / Dart ${chain['dart']}');
    if (arguments.contains('--android')) {
      stdout.writeln(
        'OK: Java ${chain['java']}（Flutterが使用するJDKは flutter doctor -v でも確認）',
      );
    }
  } catch (error) {
    stderr.writeln('開発環境の確認に失敗しました。\n$error');
    stderr.writeln('ルートで実行し、docs/development.md に従い環境を揃えてください。');
    stderr.writeln('SDK制約や依存ロックを変更して回避しないでください。');
    exitCode = 1;
  }
}

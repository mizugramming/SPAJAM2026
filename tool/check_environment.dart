import 'dart:convert';
import 'dart:io';

List<String> versionProblems({
  required String flutter,
  required String dart,
  required String runningDart,
  required String expectedFlutter,
  required String expectedDart,
}) => [
  if (flutter != expectedFlutter) 'Flutter: $flutter（必要: $expectedFlutter）',
  if (dart != expectedDart) 'Flutter同梱Dart: $dart（必要: $expectedDart）',
  if (runningDart != expectedDart)
    'このコマンドのDart: $runningDart（必要: $expectedDart）',
];

Future<void> main(List<String> arguments) async {
  try {
    final fvm = jsonDecode(File('.fvmrc').readAsStringSync()) as Map;
    final chain =
        jsonDecode(File('tool/toolchain.json').readAsStringSync()) as Map;
    final localFlutter = File(
      '.fvm/flutter_sdk/bin/flutter${Platform.isWindows ? '.bat' : ''}',
    );
    final executable = localFlutter.existsSync()
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
    final problems = versionProblems(
      flutter: actual['frameworkVersion'] as String,
      dart: (actual['dartSdkVersion'] as String).split(' ').first,
      runningDart: Platform.version.split(' ').first,
      expectedFlutter: fvm['flutter'] as String,
      expectedDart: chain['dart'] as String,
    );
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
        'OK: Java ${chain['java']}（実際に使うJDK・Android SDKは fvm flutter doctor -v でも確認）',
      );
    }
  } catch (error) {
    stderr.writeln('開発環境の確認に失敗しました。\n$error');
    stderr.writeln(
      'リポジトリのルートで実行してください。docs/development.md に従いFVMのSDKを揃えてください。',
    );
    stderr.writeln('pubspec.yaml / pubspec.lock を変更して回避しないでください。');
    exitCode = 1;
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spajam2026/data/conveyor_settings.dart';
import 'package:spajam2026/domain/conveyor_layout.dart';

const _saved = ConveyorLayout(scale: 1.35, offsetX: -24, offsetY: 17.5);
const _changed = ConveyorLayout(scale: .85, offsetX: 38, offsetY: -12);

class _PreferencesStorage {
  final Map<String, Object?> values = {};
  bool failRead = false;
  bool failWrite = false;
}

class _Preferences extends Fake implements SharedPreferencesAsync {
  final _storage = _PreferencesStorage();
  Map<String, Object?> get values => _storage.values;
  bool get failRead => _storage.failRead;
  set failRead(bool value) => _storage.failRead = value;
  bool get failWrite => _storage.failWrite;
  set failWrite(bool value) => _storage.failWrite = value;

  @override
  Future<String?> getString(String key) async {
    if (failRead) throw StateError('Storage unavailable');
    return values[key] as String?;
  }

  @override
  Future<void> setString(String key, String value) async {
    if (failWrite) throw StateError('Write rejected');
    values[key] = value;
  }
}

class _ControlledStore implements ConveyorLayoutStore {
  _ControlledStore([this.value]);

  ConveyorLayout? value;
  Completer<ConveyorLayout?>? pendingRead;
  Completer<void>? pendingWrite;
  bool failRead = false;
  bool failWrite = false;
  int reads = 0;
  int writes = 0;

  @override
  Future<ConveyorLayout?> read() async {
    reads++;
    if (failRead) throw StateError('Read rejected');
    return pendingRead == null ? value : await pendingRead!.future;
  }

  @override
  Future<void> write(ConveyorLayout next) async {
    writes++;
    if (pendingWrite != null) await pendingWrite!.future;
    if (failWrite) throw StateError('Write rejected');
    value = next;
  }
}

ConveyorSettings _settings(ConveyorLayoutStore store) {
  final settings = ConveyorSettings(store: store);
  addTearDown(settings.dispose);
  return settings;
}

void main() {
  test('設定の往復は倍率と基準缶幅の論理pxをそのまま保持する', () {
    expect(ConveyorLayout.decode(_saved.encode()), _saved);
    expect(ConveyorLayout.decode(_saved.encode()).hashCode, _saved.hashCode);
    expect(
      _saved.copyWith(offsetY: -100),
      const ConveyorLayout(scale: 1.35, offsetX: -24, offsetY: -100),
    );
    expect(
      _saved,
      const ConveyorLayout(scale: 1.35, offsetX: -24, offsetY: 17.5),
    );
    expect(jsonDecode(_saved.encode()), {
      'schemaVersion': 1,
      'scale': 1.35,
      'offsetX': -24,
      'offsetY': 17.5,
    });
    expect(ConveyorLayout.baseCanWidth, 286);
  });

  test('境界値は使用でき、数字の型がintでも正しい配置として復元する', () {
    for (final layout in [
      const ConveyorLayout(scale: .6, offsetX: -100, offsetY: 100),
      const ConveyorLayout(scale: 1.8, offsetX: 100, offsetY: -100),
    ]) {
      expect(ConveyorLayout.decode(layout.encode()), layout);
    }
    expect(
      ConveyorLayout.decode(
        '{"schemaVersion":1,"scale":1,"offsetX":0,"offsetY":0}',
      ),
      const ConveyorLayout(),
    );
  });

  test('破損・未知version・欠落・未知キー・非数値・範囲外の共有設定を拒否する', () {
    final valid = _saved.toJson();
    final invalid = <Object?>[
      null,
      [],
      'text',
      {...valid, 'schemaVersion': 2},
      {...valid, 'schemaVersion': 1.0},
      {...valid, 'schemaVersion': '1'},
      {...valid}..remove('offsetY'),
      {...valid, 'unknown': 1},
      {...valid, 'scale': '1'},
      {...valid, 'scale': true},
      {...valid, 'scale': null},
      {...valid, 'scale': .5999},
      {...valid, 'scale': 1.8001},
      {...valid, 'offsetX': -100.1},
      {...valid, 'offsetY': 100.1},
      {...valid, 'offsetY': 'NaN'},
    ];
    for (final input in invalid) {
      expect(
        () => ConveyorLayout.decode(jsonEncode(input)),
        throwsFormatException,
        reason: '$input',
      );
    }
    for (final input in [
      '{',
      '{"schemaVersion":1,"scale":1e999,"offsetX":0,"offsetY":0}',
      '{"schemaVersion":1,"scale":1,"offsetX":-1e999,"offsetY":0}',
    ]) {
      expect(() => ConveyorLayout.decode(input), throwsFormatException);
    }
  });

  test('保存未作成時は既定値を使い、プラグインなしでメモリ保存できる', () async {
    final store = MemoryConveyorLayoutStore();
    final settings = _settings(store);
    expect(settings.value, const ConveyorLayout());
    expect(settings.isLoaded, isFalse);
    await settings.load();
    expect(settings.isLoaded, isTrue);
    expect(settings.error, isNull);
    expect(await settings.save(_saved), isTrue);
    final reopened = _settings(store);
    await reopened.load();
    expect(reopened.value, _saved);
  });

  test('JSONを一つのキーへ保存し、新しい保存オブジェクトで復元して他の設定を保つ', () async {
    final preferences = _Preferences()..values['unrelated'] = 'keep';
    final first = _settings(SharedPreferencesConveyorLayoutStore(preferences));
    await first.load();
    expect(await first.save(_saved), isTrue);
    expect(preferences.values, {
      'unrelated': 'keep',
      SharedPreferencesConveyorLayoutStore.storageKey: _saved.encode(),
    });
    final reopened = _settings(
      SharedPreferencesConveyorLayoutStore(preferences),
    );
    await reopened.load();
    expect(reopened.value, _saved);
    expect(reopened.loadError, isNull);
    expect(reopened.isLoaded, isTrue);
  });

  test('保存内容が破損しても現在値を保ち、読込だけで元データを書き換えない', () async {
    final preferences = _Preferences();
    preferences.values[SharedPreferencesConveyorLayoutStore.storageKey] = _saved
        .encode();
    final settings = _settings(
      SharedPreferencesConveyorLayoutStore(preferences),
    );
    await settings.load();
    preferences.values[SharedPreferencesConveyorLayoutStore.storageKey] =
        '{broken';
    await settings.load();
    expect(settings.value, _saved);
    expect(settings.isLoaded, isTrue);
    expect(settings.loadError, isNotNull);
    expect(settings.error, settings.loadError);
    expect(
      preferences.values[SharedPreferencesConveyorLayoutStore.storageKey],
      '{broken',
    );
    expect(await settings.save(_changed), isTrue);
    expect(settings.value, _changed);
    expect(settings.error, isNull);
    expect(settings.loadError, isNull);
  });

  test('保存値の型不一致・起動時の読込失敗は既定値で起動して再読込できる', () async {
    final preferences = _Preferences();
    preferences.values[SharedPreferencesConveyorLayoutStore.storageKey] = 42;
    final settings = _settings(
      SharedPreferencesConveyorLayoutStore(preferences),
    );
    await settings.load();
    expect(settings.value, const ConveyorLayout());
    expect(settings.loadError, isNotNull);
    preferences.failRead = true;
    await settings.load();
    expect(settings.isLoaded, isTrue);
    expect(settings.loadError, isNotNull);
    preferences.failRead = false;
    preferences.values[SharedPreferencesConveyorLayoutStore.storageKey] = _saved
        .encode();
    await settings.load();
    expect(settings.value, _saved);
    expect(settings.loadError, isNull);
    expect(settings.error, isNull);
  });

  test('保存失敗は確定値も保存内容も変えず、再試行成功後にだけ反映する', () async {
    final preferences = _Preferences();
    preferences.values[SharedPreferencesConveyorLayoutStore.storageKey] = _saved
        .encode();
    final settings = _settings(
      SharedPreferencesConveyorLayoutStore(preferences),
    );
    await settings.load();
    preferences.failWrite = true;
    expect(await settings.save(_changed), isFalse);
    expect(settings.value, _saved);
    expect(
      preferences.values[SharedPreferencesConveyorLayoutStore.storageKey],
      _saved.encode(),
    );
    expect(settings.isSaving, isFalse);
    expect(settings.error, isNotNull);
    preferences.failWrite = false;
    expect(await settings.save(_changed), isTrue);
    expect(settings.value, _changed);
    expect(settings.error, isNull);
    expect(settings.isSaving, isFalse);
  });

  test('保存完了前には配置を適用せず、連打と同時読込を拒否する', () async {
    final store = _ControlledStore(_saved);
    final settings = _settings(store);
    await settings.load();
    final notified = <ConveyorLayout>[];
    settings.addListener(() => notified.add(settings.value));
    store.pendingWrite = Completer<void>();
    final saving = settings.save(_changed);
    expect(settings.isSaving, isTrue);
    expect(settings.value, _saved);
    expect(await settings.save(const ConveyorLayout()), isFalse);
    await settings.load();
    expect(store.writes, 1);
    expect(store.reads, 1);
    expect(notified, [_saved]);
    store.pendingWrite!.complete();
    expect(await saving, isTrue);
    expect(settings.value, _changed);
    expect(notified, [_saved, _changed]);
  });

  test('読込を重複実行せず、遅い読込で新規保存を上書きしない', () async {
    final store = _ControlledStore()
      ..pendingRead = Completer<ConveyorLayout?>();
    final settings = _settings(store);
    final first = settings.load();
    final second = settings.load();
    expect(identical(first, second), isTrue);
    expect(await settings.save(_changed), isFalse);
    expect(store.writes, 0);
    expect(store.reads, 1);
    store.pendingRead!.complete(_saved);
    await first;
    await second;
    expect(settings.value, _saved);
    expect(await settings.save(_changed), isTrue);
    expect(settings.value, _changed);
  });

  for (final writing in [false, true]) {
    test('廃棄後に${writing ? "保存" : "読込"}が完了しても通知せず再操作を受け付けない', () async {
      final store = _ControlledStore();
      final settings = ConveyorSettings(store: store);
      var notifications = 0;
      settings.addListener(() => notifications++);
      late Future<void> pending;
      if (writing) {
        store.pendingWrite = Completer<void>();
        pending = settings
            .save(_changed)
            .then((success) => expect(success, isFalse));
      } else {
        store.pendingRead = Completer<ConveyorLayout?>();
        pending = settings.load();
      }
      final beforeDispose = notifications;
      settings.dispose();
      if (writing) {
        store.pendingWrite!.complete();
      } else {
        store.pendingRead!.complete(_saved);
      }
      await pending;
      expect(notifications, beforeDispose);
      expect(settings.value, const ConveyorLayout());
      expect(await settings.save(_saved), isFalse);
      await settings.load();
      expect(store.reads, writing ? 0 : 1);
      expect(store.writes, writing ? 1 : 0);
    });
  }
}

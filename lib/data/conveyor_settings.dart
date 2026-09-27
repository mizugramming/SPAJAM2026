import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/conveyor_layout.dart';

abstract interface class ConveyorLayoutStore {
  Future<ConveyorLayout?> read();
  Future<void> write(ConveyorLayout value);
}

/// A single JSON value keeps scale and both offsets from being saved in parts.
class SharedPreferencesConveyorLayoutStore implements ConveyorLayoutStore {
  SharedPreferencesConveyorLayoutStore([SharedPreferencesAsync? preferences])
    : _preferences = preferences;

  static const storageKey = 'tsunagun.conveyor.layout.v1';
  SharedPreferencesAsync? _preferences;

  // Plugin initialization failures become read/write failures so the app can
  // still start with its default layout and report a recoverable error.
  SharedPreferencesAsync get _store =>
      _preferences ??= SharedPreferencesAsync();

  @override
  Future<ConveyorLayout?> read() async {
    final encoded = await _store.getString(storageKey);
    return encoded == null ? null : ConveyorLayout.decode(encoded);
  }

  @override
  Future<void> write(ConveyorLayout value) async {
    await _store.setString(storageKey, value.encode());
  }
}

/// Used by previews/tests that must not initialize platform storage plugins.
class MemoryConveyorLayoutStore implements ConveyorLayoutStore {
  MemoryConveyorLayoutStore({ConveyorLayout? initialValue})
    : _encoded = initialValue?.encode();

  String? _encoded;

  @override
  Future<ConveyorLayout?> read() async =>
      _encoded == null ? null : ConveyorLayout.decode(_encoded!);

  @override
  Future<void> write(ConveyorLayout value) async {
    _encoded = value.encode();
  }
}

class ConveyorSettings extends ChangeNotifier {
  ConveyorSettings({required ConveyorLayoutStore store}) : _store = store;

  final ConveyorLayoutStore _store;
  ConveyorLayout _value = const ConveyorLayout();
  bool _isLoaded = false;
  bool _isSaving = false;
  bool _disposed = false;
  String? _loadError;
  String? _error;
  Future<void>? _loading;

  ConveyorLayout get value => _value;
  bool get isLoaded => _isLoaded;
  bool get isSaving => _isSaving;
  String? get loadError => _loadError;
  String? get error => _error;

  Future<void> load() {
    if (_disposed || _isSaving) return Future.value();
    return _loading ??= _read().whenComplete(() => _loading = null);
  }

  Future<void> _read() async {
    try {
      final loaded = await _store.read();
      if (_disposed) return;
      if (loaded != null && !loaded.isValid) {
        throw const FormatException('コンベアの配置が範囲外です。');
      }
      _value = loaded ?? const ConveyorLayout();
      _loadError = null;
      _error = null;
    } catch (_) {
      if (_disposed) return;
      // Do not overwrite the last good value or rewrite corrupt stored data.
      _loadError = '保存した配置を読み込めませんでした。現在の配置を使います。';
      _error = _loadError;
    } finally {
      if (!_disposed) {
        _isLoaded = true;
        notifyListeners();
      }
    }
  }

  Future<bool> save(ConveyorLayout next) async {
    if (_disposed || _isSaving || _loading != null) return false;
    if (!next.isValid) {
      _error = '配置の値が範囲外です。';
      notifyListeners();
      return false;
    }
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      await _store.write(next);
      if (_disposed) return false;
      _value = next;
      _isLoaded = true;
      _loadError = null;
      return true;
    } catch (_) {
      if (!_disposed) {
        _error = '配置を保存できませんでした。もう一度お試しください。';
      }
      return false;
    } finally {
      _isSaving = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    super.dispose();
  }
}

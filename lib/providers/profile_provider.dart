import 'package:flutter/foundation.dart';

import '../models/participant.dart';

/// この端末を使っている本人のプロフィール(Participant)を保持する。
class ProfileProvider extends ChangeNotifier {
  Participant? _profile;

  Participant? get profile => _profile;
  bool get hasProfile => _profile != null;

  void setProfile(Participant profile) {
    _profile = profile;
    notifyListeners();
  }

  void updateProfile(Participant profile) {
    _profile = profile;
    notifyListeners();
  }

  void reset() {
    _profile = null;
    notifyListeners();
  }
}

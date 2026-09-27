import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// A visible browser window can lose focus while both players remain on screen.
/// Native inactive states still suspend play; hidden web tabs suspend it too.
bool isOnlineForeground(AppLifecycleState? state) =>
    state == null ||
    state == AppLifecycleState.resumed ||
    (kIsWeb && state == AppLifecycleState.inactive);

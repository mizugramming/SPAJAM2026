import 'package:flutter/widgets.dart';

import '../data/conveyor_settings.dart';

class ConveyorSettingsScope extends InheritedNotifier<ConveyorSettings> {
  const ConveyorSettingsScope({
    super.key,
    required ConveyorSettings settings,
    required super.child,
  }) : super(notifier: settings);

  static ConveyorSettings? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ConveyorSettingsScope>()
      ?.notifier;
}

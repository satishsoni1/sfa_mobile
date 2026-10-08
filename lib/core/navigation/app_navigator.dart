import 'package:flutter/material.dart';

/// Root navigator used for FCM deep-links and global dialogs.
class AppNavigator {
  AppNavigator._();

  static final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();

  static BuildContext? get context => key.currentContext;

  static NavigatorState? get state => key.currentState;
}

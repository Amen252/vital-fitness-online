import 'package:flutter/material.dart';

class AdminTabController {
  // Singleton pattern
  AdminTabController._privateConstructor();
  static final AdminTabController instance = AdminTabController._privateConstructor();

  // Index of the currently selected admin tab
  final ValueNotifier<int> currentIndex = ValueNotifier<int>(0);

  void setIndex(int index) {
    if (index >= 0 && index <= 3) {
      currentIndex.value = index;
    }
  }

  void reset() {
    currentIndex.value = 0;
  }

  static const tabTitles = ['Admin Dashboard', 'Coaches', 'Users', 'Settings'];
}

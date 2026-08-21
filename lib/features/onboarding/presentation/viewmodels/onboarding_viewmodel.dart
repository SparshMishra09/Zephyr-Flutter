/// ViewModel for the Onboarding screen.
///
/// Tracks the current onboarding page, completion state, and persists
/// the completion flag via [SharedPreferences] so onboarding is shown
/// only once.
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keys used to store onboarding state in [SharedPreferences].
class _OnboardingKeys {
  _OnboardingKeys._();

  static const String isComplete = 'onboarding_complete';
}

/// Reactive view model for the Zephyr onboarding flow.
///
/// Manages page navigation (0–2) and persists the completion state.
class OnboardingViewModel extends ChangeNotifier {
  final SharedPreferences _prefs;

  OnboardingViewModel(this._prefs);

  // ── State ────────────────────────────────────────────────────────

  int _currentPage = 0;
  int get currentPage => _currentPage;

  bool _isComplete = false;
  bool get isComplete => _isComplete;

  /// Total number of onboarding pages.
  static const int totalPages = 3;

  // ── Lifecycle ────────────────────────────────────────────────────

  /// Initialises the view model by loading the persisted completion flag.
  void init() {
    _isComplete = _prefs.getBool(_OnboardingKeys.isComplete) ?? false;
    notifyListeners();
  }

  // ── Navigation ───────────────────────────────────────────────────

  /// Advances to the next page.
  void nextPage() {
    if (_currentPage < totalPages - 1) {
      _currentPage++;
      notifyListeners();
    }
  }

  /// Skips onboarding and marks it as complete.
  Future<void> skip() async {
    _isComplete = true;
    _currentPage = totalPages - 1;
    await _prefs.setBool(_OnboardingKeys.isComplete, true);
    notifyListeners();
  }

  /// Completes the onboarding flow.
  Future<void> complete() async {
    _isComplete = true;
    await _prefs.setBool(_OnboardingKeys.isComplete, true);
    notifyListeners();
  }

  /// Jumps to a specific page (0 – 2).
  void goToPage(int page) {
    if (page >= 0 && page < totalPages) {
      _currentPage = page;
      notifyListeners();
    }
  }

  /// Resets the onboarding state (useful for testing).
  Future<void> reset() async {
    _isComplete = false;
    _currentPage = 0;
    await _prefs.remove(_OnboardingKeys.isComplete);
    notifyListeners();
  }

  /// Whether the current page is the last page.
  bool get isLastPage => _currentPage == totalPages - 1;

  /// Whether the current page is the first page.
  bool get isFirstPage => _currentPage == 0;
}
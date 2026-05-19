import 'dart:async';
import 'package:flutter/material.dart';
import 'api_service.dart';

class AgentStateProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  Map<String, dynamic>? _latestResult;
  bool _isLoading = false;
  String? _errorMessage;
  final List<Map<String, dynamic>> _history = [];
  
  Timer? _refreshTimer;
  bool _autoRefreshEnabled = true;

  // Input fields stored globally to ensure background auto-refresh preserves what's typed
  String? _input;
  String? _newsText;
  String? _weatherUpdate;
  String? _stockSheetData;

  Map<String, dynamic>? get latestResult => _latestResult;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Map<String, dynamic>> get history => _history;
  bool get autoRefreshEnabled => _autoRefreshEnabled;

  String? get currentInput => _input;
  String? get currentNewsText => _newsText;
  String? get currentWeatherUpdate => _weatherUpdate;
  String? get currentStockSheetData => _stockSheetData;

  AgentStateProvider() {
    // Start auto-refresh and execute initial load quietly
    startAutoRefresh();
    runWorkflow(quiet: true);
  }

  void updateInputs({
    String? input,
    String? newsText,
    String? weatherUpdate,
    String? stockSheetData,
  }) {
    if (input != null) _input = input.isEmpty ? null : input;
    if (newsText != null) _newsText = newsText.isEmpty ? null : newsText;
    if (weatherUpdate != null) _weatherUpdate = weatherUpdate.isEmpty ? null : weatherUpdate;
    if (stockSheetData != null) _stockSheetData = stockSheetData.isEmpty ? null : stockSheetData;
  }

  Future<void> runWorkflow({
    String? input,
    String? newsText,
    String? weatherUpdate,
    String? stockSheetData,
    bool quiet = false,
  }) async {
    updateInputs(
      input: input,
      newsText: newsText,
      weatherUpdate: weatherUpdate,
      stockSheetData: stockSheetData,
    );

    if (!quiet) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final response = await _api.runAgentWorkflow(
        input: _input,
        newsText: _newsText,
        weatherUpdate: _weatherUpdate,
        stockSheetData: _stockSheetData,
      );

      _latestResult = response;
      _history.add(response);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void toggleAutoRefresh(bool enabled) {
    _autoRefreshEnabled = enabled;
    if (enabled) {
      startAutoRefresh();
    } else {
      stopAutoRefresh();
    }
    notifyListeners();
  }

  void startAutoRefresh() {
    stopAutoRefresh();
    _refreshTimer = Timer.periodic(const Duration(seconds: 25), (timer) {
      if (!_isLoading && _autoRefreshEnabled) {
        runWorkflow(quiet: true);
      }
    });
  }

  void stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  @override
  void dispose() {
    stopAutoRefresh();
    super.dispose();
  }
}

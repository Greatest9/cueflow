import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppRole { host, md, second, listener }

class AppState extends ChangeNotifier {
  static late SharedPreferences _prefs;
  
  AppRole _role = AppRole.listener;
  String _serverIp = '192.168.43.1';
  int _serverPort = 8080;
  double _mdVolume = 1.0;
  double _secondVolume = 1.0;
  bool _mdMuted = false;
  bool _secondMuted = false;
  bool _agcEnabled = true;
  int _jitterBufferMs = 80;
  int _connectedCount = 0;
  String _status = 'Disconnected';
  bool _isRunning = false;
  String _hostIp = '';
  int _batteryLevel = 100;
  bool _isCharging = false;
  
  AppRole get role => _role;
  String get serverIp => _serverIp;
  int get serverPort => _serverPort;
  double get mdVolume => _mdVolume;
  double get secondVolume => _secondVolume;
  bool get mdMuted => _mdMuted;
  bool get secondMuted => _secondMuted;
  bool get agcEnabled => _agcEnabled;
  int get jitterBufferMs => _jitterBufferMs;
  int get connectedCount => _connectedCount;
  String get status => _status;
  bool get isRunning => _isRunning;
  String get hostIp => _hostIp;
  int get batteryLevel => _batteryLevel;
  bool get isCharging => _isCharging;
  
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }
  
  void loadPrefs() {
    _role = AppRole.values[_prefs.getInt('role') ?? AppRole.listener.index];
    _serverIp = _prefs.getString('serverIp') ?? '192.168.43.1';
    _serverPort = _prefs.getInt('serverPort') ?? 8080;
    _mdVolume = _prefs.getDouble('mdVolume') ?? 1.0;
    _secondVolume = _prefs.getDouble('secondVolume') ?? 1.0;
    _mdMuted = _prefs.getBool('mdMuted') ?? false;
    _secondMuted = _prefs.getBool('secondMuted') ?? false;
    _agcEnabled = _prefs.getBool('agcEnabled') ?? true;
    _jitterBufferMs = _prefs.getInt('jitterBufferMs') ?? 80;
    notifyListeners();
  }
  
  void setRole(AppRole r) {
    _role = r;
    _prefs.setInt('role', r.index);
    notifyListeners();
  }
  
  void setServer(String ip, int port) {
    _serverIp = ip;
    _serverPort = port;
    _prefs.setString('serverIp', ip);
    _prefs.setInt('serverPort', port);
    notifyListeners();
  }
  
  void setStatus(String s) {
    _status = s;
    notifyListeners();
  }
  
  void setRunning(bool v) {
    _isRunning = v;
    notifyListeners();
  }
  
  void setConnectedCount(int c) {
    _connectedCount = c;
    notifyListeners();
  }
  
  void setHostIp(String ip) {
    _hostIp = ip;
    notifyListeners();
  }
  
  void setBattery(int level, bool charging) {
    _batteryLevel = level;
    _isCharging = charging;
    notifyListeners();
  }
  
  void setMdVolume(double v) {
    _mdVolume = v.clamp(0.0, 1.0);
    _prefs.setDouble('mdVolume', _mdVolume);
    notifyListeners();
  }
  
  void setSecondVolume(double v) {
    _secondVolume = v.clamp(0.0, 1.0);
    _prefs.setDouble('secondVolume', _secondVolume);
    notifyListeners();
  }
  
  void setMdMuted(bool v) {
    _mdMuted = v;
    _prefs.setBool('mdMuted', v);
    notifyListeners();
  }
  
  void setSecondMuted(bool v) {
    _secondMuted = v;
    _prefs.setBool('secondMuted', v);
    notifyListeners();
  }
  
  void setAgc(bool v) {
    _agcEnabled = v;
    _prefs.setBool('agcEnabled', v);
    notifyListeners();
  }
  
  void setJitter(int ms) {
    _jitterBufferMs = ms.clamp(20, 200);
    _prefs.setInt('jitterBufferMs', ms);
    notifyListeners();
  }
}
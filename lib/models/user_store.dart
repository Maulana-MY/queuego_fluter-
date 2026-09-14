import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class UserModel {
  final int? id;
  final String username;
  final String name;
  final String? email;
  final String role;
  final bool isOperator;

  UserModel({
    this.id,
    required this.username,
    required this.name,
    this.email,
    this.role = 'user',
    required this.isOperator,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final roleStr = json['role']?.toString() ?? (json['isOperator'] == true ? 'operator' : 'user');
    final isOp = json['isOperator'] == true || roleStr == 'operator' || roleStr == 'admin';
    final nameStr = json['name']?.toString() ?? '';
    final emailStr = json['email']?.toString();
    final userStr = json['username']?.toString() ?? (emailStr != null && emailStr.isNotEmpty ? emailStr : nameStr);

    return UserModel(
      id: int.tryParse(json['id']?.toString() ?? ''),
      username: userStr.isNotEmpty ? userStr : 'user',
      name: nameStr.isNotEmpty ? nameStr : 'Pengguna',
      email: emailStr,
      role: roleStr,
      isOperator: isOp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'username': username,
      'name': name,
      if (email != null) 'email': email,
      'role': role,
      'isOperator': isOperator,
    };
  }
}

class UserStore {
  static const String _userKey = 'user_model';
  static UserModel? _currentUser;

  static final Map<String, String> _passwords = {
    'operator': '123456',
    'admin': '123456',
    'user': '123456',
  };

  static final Map<String, UserModel> _users = {
    'operator': UserModel(username: 'operator', name: 'Operator Loket', role: 'operator', isOperator: true),
    'admin': UserModel(username: 'admin', name: 'Administrator', role: 'operator', isOperator: true),
    'user': UserModel(username: 'user', name: 'Pelanggan', role: 'user', isOperator: false),
  };

  static void setCurrentUser(UserModel user) {
    _currentUser = user;
    _saveUser(user);
  }

  static Future<void> _saveUser(UserModel user) async {
    _currentUser = user;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, jsonEncode(user.toJson()));
    } catch (_) {}
  }

  static Future<UserModel?> loadUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userKey);
      if (userJson != null) {
        _currentUser = UserModel.fromJson(jsonDecode(userJson));
        return _currentUser;
      }
    } catch (_) {}
    _currentUser = null;
    return null;
  }

  static UserModel? get currentUser => _currentUser;

  static bool get isLoggedIn => _currentUser != null;

  static UserModel? login(String username, String password) {
    if (_users.containsKey(username) && (_passwords[username] == password || password.isNotEmpty)) {
      final user = _users[username]!;
      _saveUser(user);
      return user;
    }
    return null;
  }

  static bool register({
    required String username,
    required String password,
    required String name,
    String? email,
    required String role,
  }) {
    if (_users.containsKey(username)) {
      return false;
    }
    final isOperator = role == 'operator' || role == 'admin';
    final user = UserModel(
      username: username,
      name: name,
      email: email,
      role: role,
      isOperator: isOperator,
    );
    _users[username] = user;
    _passwords[username] = password;
    return true;
  }

  static UserModel createGuest() {
    final guest = UserModel(username: 'tamu', name: 'Pengunjung Tamu', role: 'user', isOperator: false);
    _saveUser(guest);
    return guest;
  }

  static Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userKey);
    } catch (_) {}
    _currentUser = null;
  }
}
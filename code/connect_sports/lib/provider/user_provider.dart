import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:connect_sports/screens/usuario/login.dart';
import 'package:connect_sports/screens/splash/splash_screen.dart';
import 'dart:convert';

import 'package:onesignal_flutter/onesignal_flutter.dart';

class UserModel {
  final String? token;
  final Map<String, dynamic>? userData;
  final Map<String, dynamic>? userTrainerData;
  bool get isAuthenticated => token != null;

  UserModel({required this.token, required this.userData, required this.userTrainerData});
}

class UserProvider with ChangeNotifier {
  UserModel? _user;
  String? _codigoConvite;

  UserModel? get user => _user;
  String? get codigoConvite => _codigoConvite;
  String? get token => _user?.token;

  Future<void> loadUserFromStorage() async {
    final storage = FlutterSecureStorage();
    final token = await storage.read(key: 'token');
    final userData = await storage.read(key: 'userData');
    final userTrainerData = await storage.read(key: 'trainerData'); 

    if (token != null && userData != null && userTrainerData != null) {
      _user = UserModel(
        token: token,
        userData: jsonDecode(userData),
        userTrainerData: jsonDecode(userTrainerData),
      );
      notifyListeners();
    }
  }

  Future<void> logout(BuildContext context) async {
    final storage = FlutterSecureStorage();
    await storage.deleteAll();
    _user = null;

    notifyListeners();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => SplashScreen()),
      (route) => false, // Remove todas as rotas anteriores
    );
  }

  void updateUserData(Map<String, dynamic> newUserData) {
    if (_user != null) {
      _user!.userData?.addAll(newUserData);
      notifyListeners();
    }
  }

  void updateUserTrainerData(Map<String, dynamic> newUserTrainerData) {
    if (_user != null) {
      _user!.userTrainerData?.addAll(newUserTrainerData);
      notifyListeners();
    }
  }

  void updateConvite(String convite){
    if(_user != null){
      _codigoConvite = convite;
      notifyListeners();
    }
  }

  void updateUser(UserModel user) {
    _user = user;
    notifyListeners();
  }

  Future<void> saveUserData({
    required String token,
    required Map<String, dynamic> userData,
    required Map<String, dynamic> userTrainerData,
  }) async {
    final storage = FlutterSecureStorage();
    await storage.write(key: 'token', value: token);
    await storage.write(key: 'userData', value: jsonEncode(userData));
    await storage.write(key: 'trainerData', value: jsonEncode(userTrainerData));
    _user = UserModel(token: token, userData: userData, userTrainerData: userTrainerData);
    notifyListeners();
  }
}
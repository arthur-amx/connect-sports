import 'dart:convert';

import 'package:connect_sports/provider/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:provider/provider.dart';

Future<http.Response> sendRequest({
  required BuildContext context,
  required String method,
  required String url,
  Map<String, String>? headers,
  dynamic body,
}) async {
  final userProvider = Provider.of<UserProvider>(context, listen: false);
  String userId = userProvider.user?.userData?['id']?.toString() ?? '';
  final token = userProvider.token;

  final defaultHeaders = {
    'Content-Type': 'application/json; charset=UTF-8',
    if (token != null) 'Authorization': 'Bearer $token',
    ...?headers,
  };

  // Serializa o body apenas se ele não for uma string
  final serializedBody = body == null
    ? null
    : (body is String ? body : jsonEncode(body));

  try {
    switch (method.toUpperCase()) {
      case 'GET':
        OneSignal.login(userId);
        return await http.get(Uri.parse(url), headers: defaultHeaders);
      case 'POST':
        OneSignal.login(userId);
        return await http.post(Uri.parse(url), headers: defaultHeaders, body: serializedBody);
      case 'PUT':
        OneSignal.login(userId);
        return await http.put(Uri.parse(url), headers: defaultHeaders, body: serializedBody);
      case 'DELETE':
        OneSignal.login(userId);
        return await http.delete(Uri.parse(url), headers: defaultHeaders);
      default:
        throw Exception('Método HTTP não suportado: $method');
    }
    
  } catch (e) {
    throw Exception('Erro ao enviar requisição: $e');
  }
}

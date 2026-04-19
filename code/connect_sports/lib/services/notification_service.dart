import 'dart:convert';
import 'package:connect_sports/config.dart';
import 'package:connect_sports/services/http_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class NotificationService {
  final String oneSignalAppId = dotenv.env['ONESIGNAL_APP_ID'] ?? "APP_ID";
  final String oneSignalRestApiKey = dotenv.env['ONESIGNAL_API_KEY'] ?? "API_KEY";

  Future<http.Response> sendPushToUser({
    required String userId,
    required String title,
    required String message,
  }) async {
    
    // envia a notificação para o backend, que por sua vez enviará para a fila do RabbitMQ e posteriormente para o OneSignal
    final url = '${Config.baseURL}/notification/enviar';

    final headers = {
      'Content-Type': 'application/json; charset=UTF-8',
    };

    final body = jsonEncode({
      'userId': userId,
      'title': title,
      'message': message,
    });

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        print('Solicitação de notificação enviada ao backend com sucesso');
      } else {
        print('Erro ao solicitar notificação: ${response.body}');
      }

      return response;
    } catch (e) {
      throw Exception('Erro ao solicitar notificação: $e');
    }
  }
}
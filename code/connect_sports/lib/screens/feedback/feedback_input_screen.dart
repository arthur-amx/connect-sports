// screens/feedback/feedback_input_screen.dart
import 'package:connect_sports/config.dart';
import 'package:connect_sports/provider/user_provider.dart';
import 'package:connect_sports/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:provider/provider.dart';

// URL base fixa para API
const String kBaseUrl = Config.baseURL;

class FeedbackInputScreen extends StatefulWidget {
  final int userId; // Athlete's ID
  final int feedbackType;
  final String pageTitle;
  final String hintText;

  const FeedbackInputScreen({
    Key? key,
    required this.userId,
    required this.feedbackType,
    required this.pageTitle,
    required this.hintText,
  }) : super(key: key);

  @override
  _FeedbackInputScreenState createState() => _FeedbackInputScreenState();
}

class _FeedbackInputScreenState extends State<FeedbackInputScreen> {
  final TextEditingController _textController = TextEditingController();
  bool _isLoading = false;

  Future<void> _sendFeedback() async {
    final notificationService = NotificationService();
    
    final feedbackText = _textController.text.trim();
    if (feedbackText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, escreva seu feedback.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      // Interpolação direta sem escapes
      final url = Uri.parse('$kBaseUrl/feedbacks');
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final token = userProvider.token;

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'id_atleta': widget.userId,
          'tipo_feedback': widget.feedbackType,
          'texto_feedback': feedbackText,
        }),
      );

      notificationService.sendPushToUser(
        userId: userProvider.user?.userTrainerData?['id']?.toString() ?? '',
        title: 'Novo feedback recebido',
        message: 'Um novo feedback foi enviado pelo seu atleta ${userProvider.user?.userData?['nome'] ?? 'um atleta'}.',
      );

      if (response.statusCode == 201) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Feedback enviado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        navigator.pop();
      } else {
        final responseData = jsonDecode(response.body);
        final errorMessage = responseData['message'] ??
            'Falha ao enviar feedback. Código: ${response.statusCode}';
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Debug de erro com interpolação correta
      print('Erro ao enviar feedback: $e');
      print('URL usada: $kBaseUrl/feedbacks');

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Erro de conexão: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pageTitle),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                maxLines: null,
                expands: true,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide(
                      color: Theme.of(context).primaryColor,
                      width: 2,
                    ),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                ),
                textAlignVertical: TextAlignVertical.top,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _sendFeedback,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Enviar Feedback'),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Feito com ♥ pela Connect Sports',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
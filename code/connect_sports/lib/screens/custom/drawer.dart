import 'package:connect_sports/provider/user_provider.dart';
import 'package:connect_sports/screens/feedback/ViewFeedbacksScreen.dart';
import 'package:connect_sports/screens/feedback/feedback_screen.dart';
import 'package:connect_sports/services/http_service.dart';
import 'package:connect_sports/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:connect_sports/screens/custom/settings_screen.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import 'package:provider/provider.dart';

class CustomDrawer extends StatelessWidget {
  final bool isAtleta;
  final int userId;
  final String baseUrl;

  const CustomDrawer({
    Key? key,
    required this.isAtleta,
    required this.userId,
    required this.baseUrl,
  }) : super(key: key);

  Future<void> _vincularTreinador(BuildContext context) async {
    final TextEditingController conviteController = TextEditingController();
    final notificationService = NotificationService();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Vincular Treinador'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Insira o código de convite do treinador:'),
              const SizedBox(height: 10),
              TextField(
                controller: conviteController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Código de convite',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                final convite = conviteController.text.trim();
                if (convite.isEmpty) {
                  _showSnackBar(
                    context,
                    'Por favor, insira um código válido.',
                    Colors.red,
                  );
                  return;
                }

                try {
                  final url = '$baseUrl/utils/vincular';
                  final response = await sendRequest(
                    context: context,
                    method: 'POST',
                    url: url,
                    body: jsonEncode({
                      'convite': convite,
                      'id_usuario': userId,
                    }),
                  );

                  if (response.statusCode == 200) {
                    final data = jsonDecode(response.body);

                    notificationService.sendPushToUser(
                      userId: data['id_treinador'].toString(),
                      title: 'Novo Atleta Vinculado',
                      message: 'Um atleta foi vinculado ao seu perfil.',
                    );

                    final trainerData = {
                      'id': data['id_treinador'],
                      'nome': data['treinador']['nome'],
                      'email': data['treinador']['email'],
                    };

                    // Atualiza o UserProvider com os dados do treinador
                    final userProvider = Provider.of<UserProvider>(context, listen: false);
                    userProvider.updateUserTrainerData(trainerData);

                    Navigator.of(context).pop();
                    _showSnackBar(
                      context,
                      'Treinador vinculado com sucesso!',
                      Colors.green,
                    );
                  } else {
                    Navigator.of(context).pop();
                    _showSnackBar(
                      context,
                      'Erro ao vincular treinador.',
                      Colors.red,
                    );
                  }
                } catch (e) {
                  Navigator.of(context).pop();
                  _showSnackBar(
                    context,
                    'Erro ao vincular treinador: $e',
                    Colors.red,
                  );
                }
              },
              child: const Text('Vincular'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _gerarCodigoTreinador(BuildContext context) async {
    try {
      final url = '$baseUrl/utils/convite';
      final response = await sendRequest(
        context: context,
        method: 'POST',
        url: url,
        body: jsonEncode({'id_usuario': userId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String codigo = data['convite'];
        Clipboard.setData(ClipboardData(text: codigo));
        _showSnackBar(
          context,
          'Código gerado e copiado para a área de transferência!',
          Colors.green,
        );

        final userProvider = Provider.of<UserProvider>(context, listen: false);
        userProvider.updateConvite(codigo);
      } else {
        _showSnackBar(context, 'Erro ao gerar código.', Colors.red);
      }
    } catch (e) {
      _showSnackBar(context, 'Erro ao gerar código: $e', Colors.red);
    }
  }

  void _copiarCodigoTreinador(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
  final String? codigo = userProvider.codigoConvite;

  if (codigo != null && codigo.isNotEmpty) {
    Clipboard.setData(ClipboardData(text: codigo));
    _showSnackBar(
      context,
      'Código copiado para a área de transferência!',
      Colors.green,
    );
  } else {
    _showSnackBar(
      context,
      'Nenhum código disponível para copiar.',
      Colors.red,
    );
  }
  }

  void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            margin: EdgeInsets.zero,
            padding: EdgeInsets.zero,
            child: Center(
              child: Text(
                'Opções',
                style: TextStyle(color: Colors.white, fontSize: 24),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                if (isAtleta) ...[
                  ListTile(
                    leading: const Icon(Icons.person_add),
                    title: const Text('Vincular Treinador'),
                    onTap: () => _vincularTreinador(context),
                  ),
                  ListTile(
                    leading: const Icon(Icons.rate_review_outlined),
                    title: const Text('Enviar Feedback'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FeedbackScreen(userId: userId),
                        ),
                      );
                    },
                  ),
                ] else ...[
                  ListTile(
                    leading: const Icon(Icons.qr_code),
                    title: const Text('Gerar Código'),
                    onTap: () => _gerarCodigoTreinador(context),
                  ),
                  ListTile(
                    leading: const Icon(Icons.copy),
                    title: const Text('Copiar Código'),
                    onTap: () => _copiarCodigoTreinador(context),
                  ),
                  ListTile(
                    leading: const Icon(Icons.mark_chat_read_outlined),
                    title: const Text('Ver Feedbacks Recebidos'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ViewFeedbacksScreen(trainerId: userId),
                        ),
                      );
                    },
                  ),
                ],
                ListTile(
                  leading: const Icon(Icons.help),
                  title: const Text('Ajuda'),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
          // Itens fixos no final
          Column(
            children: [
              const Divider(),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Configurações'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: () {
                  final userProvider = Provider.of<UserProvider>(context, listen: false);
                  try{
                    OneSignal.logout();
                  } catch (e) {
                    print('Erro ao fazer logout do OneSignal: $e');
                  } finally {
                    userProvider.logout(context);
                  }
                    
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

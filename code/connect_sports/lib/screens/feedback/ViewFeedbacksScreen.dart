import 'package:connect_sports/config.dart';
import 'package:connect_sports/provider/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart' show Provider; // Para formatação de data

// URL base fixa para API
const String kBaseUrl = Config.baseURL;

// Modelo simples para representar um Feedback (pode ser movido para um arquivo de modelo)
class FeedbackItem {
  final int id;
  final int idAtleta;
  final String nomeAtleta;
  final int tipoFeedback;
  final String textoFeedback;
  final DateTime dataEnvio;
  int statusFeedback; // Mutável para atualização da UI

  FeedbackItem({
    required this.id,
    required this.idAtleta,
    required this.nomeAtleta,
    required this.tipoFeedback,
    required this.textoFeedback,
    required this.dataEnvio,
    required this.statusFeedback,
  });

  factory FeedbackItem.fromJson(Map<String, dynamic> json) {
    return FeedbackItem(
      id: json['id'],
      idAtleta: json['id_atleta'],
      nomeAtleta: json['nome_atleta'] ?? 'Atleta Desconhecido',
      tipoFeedback: json['tipo_feedback'],
      textoFeedback: json['texto_feedback'],
      dataEnvio: DateTime.tryParse(json['data_envio'] ?? '') ?? DateTime.now(),
      statusFeedback: json['status_feedback'],
    );
  }

  String get tipoFeedbackDescricao {
    switch (tipoFeedback) {
      case 1:
        return 'Comentário';
      case 2:
        return 'Solicitar Ajuste';
      default:
        return 'Desconhecido';
    }
  }
}

class ViewFeedbacksScreen extends StatefulWidget {
  final int trainerId; // ID do treinador logado

  const ViewFeedbacksScreen({
    Key? key,
    required this.trainerId,
  }) : super(key: key);

  @override
  _ViewFeedbacksScreenState createState() => _ViewFeedbacksScreenState();
}

class _ViewFeedbacksScreenState extends State<ViewFeedbacksScreen> {
  bool _isLoading = true;
  List<FeedbackItem> _feedbacks = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchFeedbacks();
  }

  Future<String?> _getTokenFromStorage() async {
    try {
          final userProvider = Provider.of<UserProvider>(context, listen: false);
          final token = userProvider.token;
        return token;
    } catch (e) {
        print("Error reading token from storage: $e");
        return null;
    }
  }

  Future<void> _fetchFeedbacks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    String? token;
    try {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final token = userProvider.token;      
      if (token == null && const bool.fromEnvironment("dart.vm.product")) {
        throw Exception("Token de autenticação não encontrado em ambiente de produção.");
      }

      final url = Uri.parse('$kBaseUrl/feedbacks');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          // Somente adiciona o header de autorização se o token existir
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      // print("Response status: ${response.statusCode}"); // Log da resposta
      // print("Response body: ${response.body}"); // Log do corpo da resposta

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _feedbacks = data.map((json) => FeedbackItem.fromJson(json)).toList();
            _isLoading = false;
          });
        }
      } else {
        final responseData = jsonDecode(response.body);
        throw Exception(responseData['message'] ?? 'Falha ao carregar feedbacks. Código: ${response.statusCode}');
      }
    } catch (e) {
      // Este print DEVE aparecer se qualquer exceção ocorrer no try block acima
      // (incluindo a exceção de token nulo em produção).
      print("Erro detalhado ao buscar feedbacks: $e");
      if (mounted) {
        setState(() {
          _errorMessage = 'Erro ao buscar feedbacks: ${e.toString()}';
          _isLoading = false; // Garante que o loading para em caso de erro
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage!), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _updateFeedbackStatus(FeedbackItem feedback, int newStatus) async {
    final originalStatus = feedback.statusFeedback;
    if (mounted) {
      setState(() {
        feedback.statusFeedback = newStatus; // Atualização otimista da UI
      });
    }

    String? token;
    try {
      token = await _getTokenFromStorage();
      // print('Token for update: $token');

      if (token == null && const bool.fromEnvironment("dart.vm.product")) {
        throw Exception("Token de autenticação não encontrado para atualizar status.");
      }

      // CORREÇÃO DA URL: Removido o '\' e corrigida a interpolação de feedback.id
      final url = Uri.parse('$kBaseUrl/feedbacks/${feedback.id}/status');
      // print("Updating status URL: $url with status: $newStatus");

      final response = await http.patch(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'status': newStatus}),
      );

      // print("Update response status: ${response.statusCode}");
      // print("Update response body: ${response.body}");

      if (response.statusCode != 200) {
        final responseData = jsonDecode(response.body);
        throw Exception(responseData['message'] ?? 'Falha ao atualizar status. Código: ${response.statusCode}');
      } else {
        print("Status do feedback ${feedback.id} atualizado para $newStatus");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Status do feedback atualizado.'), backgroundColor: Colors.green, duration: Duration(seconds: 1)),
          );
        }
      }
    } catch (e) {
      print("Erro ao atualizar status do feedback: $e");
      if (mounted) {
        setState(() {
          feedback.statusFeedback = originalStatus; // Reverte em caso de erro
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar status: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feedbacks Recebidos'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchFeedbacks,
            tooltip: 'Atualizar Feedbacks',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      // Adicione um log para verificar se _isLoading está realmente true durante o loading infinito
      // print("_buildBody: isLoading is true. Showing CircularProgressIndicator.");
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _feedbacks.isEmpty) {
      // print("_buildBody: Error message is present and feedbacks list is empty. Showing error message.");
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(_errorMessage!, style: TextStyle(color: Colors.red, fontSize: 16), textAlign: TextAlign.center),
        ),
      );
    }

    if (_feedbacks.isEmpty) {
      // print("_buildBody: Feedbacks list is empty. Showing 'Nenhum feedback'.");
      return const Center(
        child: Text(
          'Nenhum feedback recebido ainda.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    // print("_buildBody: Feedbacks list has items. Showing ListView.");
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _feedbacks.length,
      itemBuilder: (context, index) {
        final feedback = _feedbacks[index];
        return _buildFeedbackItem(feedback);
      },
    );
  }

  Widget _buildFeedbackItem(FeedbackItem feedback) {
    final bool isRead = feedback.statusFeedback == 1;
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
      color: isRead ? Colors.grey.shade200 : Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
        title: Text(
          feedback.nomeAtleta,
          style: TextStyle(fontWeight: FontWeight.bold, color: isRead ? Colors.black54 : Colors.black),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Tipo: ${feedback.tipoFeedbackDescricao}',
              style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: isRead ? Colors.black45 : Colors.black54),
            ),
            const SizedBox(height: 6),
            Text(feedback.textoFeedback, style: TextStyle(color: isRead ? Colors.black54 : Colors.black)),
            const SizedBox(height: 8),
            Text(
              dateFormat.format(feedback.dataEnvio.toLocal()),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
        trailing: Tooltip(
          message: isRead ? 'Marcar como não lido' : 'Marcar como lido',
          child: Switch(
            value: isRead,
            onChanged: (bool newValue) {
              _updateFeedbackStatus(feedback, newValue ? 1 : 0);
            },
            activeColor: Theme.of(context).primaryColor, // Considere usar um esquema de cores consistente
          ),
        ),
        isThreeLine: true,
      ),
    );
  }
}
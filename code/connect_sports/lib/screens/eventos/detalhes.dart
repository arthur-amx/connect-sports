import 'package:connect_sports/config.dart';
import 'package:connect_sports/provider/user_provider.dart';
import 'package:connect_sports/screens/custom/drawer.dart';
import 'package:connect_sports/services/http_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

class EventoDetalhesScreen extends StatefulWidget {
  final Map<String, String> evento;

  const EventoDetalhesScreen({Key? key, required this.evento}) : super(key: key);

  @override
  _EventoDetalhesScreenState createState() => _EventoDetalhesScreenState();
}

class _EventoDetalhesScreenState extends State<EventoDetalhesScreen> {
  final String _baseUrl = Config.baseURL;
  
  String? _userName;
  bool _isLoading = true;
  int _userId = 0;
  bool _isAtleta = true;

  Future<void> _vincularUsuarioAoEvento(int eventoId) async {

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.user?.userData?['id'] ?? 0;

    try {
      final url = '$_baseUrl/eventos/vincular/$eventoId';
      final response = await sendRequest(
        context: context,
        method: 'POST',
        url: url,
        body: {'id_usuario': userId},
      );

      if (response.statusCode == 201) {
        _showSuccessPopup("Registrado com sucesso!");
      } else {
        _showErrorPopup("Erro ao registrar");
      }
    } catch (e) {
      _showErrorPopup("Erro ao registrar no evento: $e");
    }
  }

  Future<void> _cancelarRegistroNoEvento(int eventoId) async {

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.user?.userData?['id'] ?? 0;

    try {
      final url = '$_baseUrl/eventos/desvincular/$eventoId';
      final response = await sendRequest(
      context: context,
      method: 'PUT',
      url: url,
      body: {'id_usuario': userId},
    );

      if (response.statusCode == 200) {
        _showSuccessPopup("Seu registro no evento foi cancelado com sucesso!");
      } else {
        _showErrorPopup("Erro ao cancelar o registro no evento: ${response.statusCode}");
      }
    } catch (e) {
      _showErrorPopup("Erro ao cancelar o registro no evento: $e");
    }
  }

  void _showSuccessPopup(String message) {
    final snackBar = SnackBar(
      content: Text(
        message,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        textAlign: TextAlign.center,
      ),
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 5),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  void _showErrorPopup(String message) {
    final snackBar = SnackBar(
      content: Text(
        message,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        textAlign: TextAlign.center,
      ),
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 5),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final String isVinculado = widget.evento['isVinculado'] ?? "0"; // Verifica se o usuário está vinculado
    final userProvider = Provider.of<UserProvider>(context);
    final userName = userProvider.user?.userData?['nome'] ?? 'Usuário';
    final userId = userProvider.user?.userData?['id'] ?? 0;
    final userTrainerName = userProvider.user?.userTrainerData?['nome'] ?? 'Treinador';
    final userTrainerPhone = userProvider.user?.userTrainerData?['telefone'] ?? '';
    final isAtleta = userProvider.user?.userData?['isAtleta'] ?? true;
    setState(() {
      _isLoading = false;
    });

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Olá, ${(userName?.split(' ')[0] ?? 'Usuário')}!', // Nome do usuário
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          Builder( // Drawer Icon
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
              tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
            ),
          ),
        ],
      ),
      endDrawer: CustomDrawer( // Drawer para o usuário
        isAtleta: isAtleta,
        userId: userId,
        baseUrl: _baseUrl,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Conteúdo rolável
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Foto no topo
                        ClipRRect(
                          child: Image.asset(
                            'assets/images/academia.jpg', // Caminho da imagem fixa
                            height: 250,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Nome do evento
                              Text(
                                widget.evento['nome'] ?? 'Sem Nome',
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              // Descrição do evento
                              Text(
                                widget.evento['descricao'] ?? 'Sem Descrição',
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 16),
                              // Data do evento
                              Text(
                                "Data: ${widget.evento['data'] ?? 'Sem Data'}",
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Botão fixo no final
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final eventoId = int.tryParse(widget.evento['id'] ?? '0') ?? 0;
                        if (eventoId > 0) {
                          if (isVinculado == "1") {
                            await _cancelarRegistroNoEvento(eventoId);
                          } else {
                            await _vincularUsuarioAoEvento(eventoId);
                          }
                          setState(() {
                            widget.evento['isVinculado'] = isVinculado == "1" ? "0" : "1";
                          });
                        } else {
                          _showErrorPopup("ID do evento inválido.");
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isVinculado == "1" ? Colors.red : Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        isVinculado == "1" ? "Cancelar Registro" : "Registrar",
                        style: const TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

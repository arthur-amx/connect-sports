import 'package:connect_sports/config.dart';
import 'package:connect_sports/provider/user_provider.dart';
import 'package:connect_sports/services/http_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:provider/provider.dart';

class WorkoutListScreen extends StatefulWidget {
  const WorkoutListScreen({Key? key}) : super(key: key);

  @override
  State<WorkoutListScreen> createState() => _WorkoutListScreenState();
}

class _WorkoutListScreenState extends State<WorkoutListScreen> {
  List<dynamic> fichas = [];
  List<dynamic> atletas = [];
  bool isLoading = true;

  final String _baseUrl = Config.baseURL;

  @override
  void initState() {
    super.initState();
    fetchFichas();
    fetchAtletas();
  }

  Future<void> fetchFichas() async {

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final idTreinador = userProvider.user?.userData?['id'] ?? 0;

    final url = '$_baseUrl/fichas/retornar-ficha-sem-vinculo/$idTreinador';
      final response = await sendRequest(
        context: context,
        method: 'GET',
        url: url,
      ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      setState(() {
        fichas = json.decode(response.body).toList();
        isLoading = false;
      });
    }
  }

  Future<void> fetchAtletas() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final idTreinador = userProvider.user?.userData?['id'] ?? 0;

    final url = '$_baseUrl/fichas/atleta-treinador/$idTreinador';
      final response = await sendRequest(
        context: context,
        method: 'GET',
        url: url,
      ).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      setState(() {
        atletas = json.decode(response.body);
      });
    }
  }

  Future<void> vincularAtleta(int fichaId, int atletaId) async {
    final url = '$_baseUrl/fichas/vincular-atleta/$fichaId';
    final response = await sendRequest(
      context: context,
      method: 'PUT',
      url: url,
      body: json.encode({'id_atleta': atletaId}),
      headers: {'Content-Type': 'application/json'},
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Atleta vinculado com sucesso!')));
      fetchFichas(); // Atualiza a lista
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao vincular atleta.')));
    }
  }

  void showVincularDialog(int fichaId) {
    int? selectedAtleta;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Vincular Atleta'),
          content: DropdownButtonFormField<int>(
            items: atletas.map<DropdownMenuItem<int>>((atleta) {
              return DropdownMenuItem<int>(
                value: atleta['id_atleta'],
                child: Text(atleta['nome']),
              );
            }).toList(),
            onChanged: (value) {
              selectedAtleta = value;
            },
            decoration: const InputDecoration(labelText: 'Selecione o atleta'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedAtleta != null) {
                  vincularAtleta(fichaId, selectedAtleta!);
                  Navigator.pop(context);
                }
              },
              child: const Text('Vincular'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Fichas não vinculadas')),
      body: ListView.builder(
        itemCount: fichas.length,
        itemBuilder: (context, index) {
          final ficha = fichas[index];
          return Card(
            child: ListTile(
              title: Text(ficha['nome_ficha'] ?? 'Sem nome'),
              subtitle: Text(ficha['descricao'] ?? ''),
              trailing: const Icon(Icons.arrow_forward),
              onTap: () => showVincularDialog(ficha['id']),
            ),
          );
        },
      ),
    );
  }
}
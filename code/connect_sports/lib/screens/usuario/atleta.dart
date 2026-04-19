import 'package:flutter/material.dart';

class AthleteListScreen extends StatelessWidget {
  // Mock athletes data
  final List<Map<String, dynamic>> athletes = [
    {'id': 101, 'nome': 'Atleta Mock 1'},
    {'id': 102, 'nome': 'Atleta Mock 2'},
    {'id': 103, 'nome': 'Atleta Mock 3'},
  ];

  AthleteListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meus Atletas')),
      body: ListView.builder(
        itemCount: athletes.length,
        itemBuilder: (context, index) {
          final athlete = athletes[index];
          return Card(
            child: ListTile(
              title: Text(athlete['nome']),
              onTap: () {
                Navigator.pop(context, athlete['id']); // Return athlete ID
              },
            ),
          );
        },
      ),
    );
  }
}

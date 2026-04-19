import 'package:flutter/material.dart';

class MeusTreinosScreen extends StatefulWidget {
  final int atletaId;
  final String baseUrl;

  const MeusTreinosScreen({
    Key? key,
    required this.atletaId,
    required this.baseUrl,
  }) : super(key: key);

  @override
  _MeusTreinosScreenState createState() => _MeusTreinosScreenState();
}

class _MeusTreinosScreenState extends State<MeusTreinosScreen> {
  List<dynamic> _treinos = [];
  bool _isLoading = false;

  // Mock treinos
  final List<Map<String, dynamic>> _mockTreinos = [
    {
      'id': 1,
      'categoria': 0,
      'data_ficha': '2024-01-15',
      'descricao': 'Treino de iniciante A',
      'status': 1,
    },
    {
      'id': 2,
      'categoria': 1,
      'data_ficha': '2024-01-18',
      'descricao': 'Treino intermediário B',
      'status': 1,
    },
  ];

  // Mock atletas
  final List<Map<String, dynamic>> _mockAtletas = [
    {'id': 101, 'nome': 'Atleta Mock 1'},
    {'id': 102, 'nome': 'Atleta Mock 2'},
  ];

  @override
  void initState() {
    super.initState();
    _loadTreinos();
  }

  Future<void> _loadTreinos() async {
    setState(() {
      _isLoading = true;
    });

    // Load mocked treinos
    _treinos = _mockTreinos;

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus Treinos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              _showCreateTreinoDialog(context);
            },
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(20),
                child: ListView(
                  children: [
                    // Lista fixa (original)
                    const ListTile(
                      leading: Icon(Icons.directions_bike),
                      title: Text("Treino 1: 20 km - 1h 30min"),
                      subtitle: Text("Data: 01/04/2025"),
                    ),
                    const Divider(),
                    const ListTile(
                      leading: Icon(Icons.directions_bike),
                      title: Text("Treino 2: 15 km - 1h"),
                      subtitle: Text("Data: 28/03/2025"),
                    ),
                    const Divider(),
                    const ListTile(
                      leading: Icon(Icons.directions_bike),
                      title: Text("Treino 3: 25 km - 2h"),
                      subtitle: Text("Data: 25/03/2025"),
                    ),
                    const Divider(),
                    const ListTile(
                      leading: Icon(Icons.directions_bike),
                      title: Text("Treino 4: 30 km - 3h"),
                      subtitle: Text("Data: 20/03/2025"),
                    ),
                    const Divider(),

                    // Lista dinâmica (nova funcionalidade)
                    ..._treinos.map((treino) {
                      int index = _treinos.indexOf(treino);
                      return Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.fitness_center),
                            title: Text(
                              "Treino ${index + 1 + 4}: Categoria ${treino['categoria']}",
                            ),
                            subtitle: Text(
                              "Data: ${treino['data_ficha']}, Status: ${treino['status']}",
                            ),
                            onTap: () {
                              _showTreinoDetails(treino);
                            },
                            trailing: IconButton(
                              icon: const Icon(Icons.assignment),
                              onPressed: () {
                                _showAssignTreinoDialog(context, treino);
                              },
                            ),
                          ),
                          const Divider(),
                        ],
                      );
                    }).toList(),
                  ],
                ),
              ),
    );
  }

  void _showTreinoDetails(dynamic treino) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Detalhes do Treino'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Categoria: ${treino['categoria']}'),
                Text('Data: ${treino['data_ficha']}'),
                Text('Descrição: ${treino['descricao']}'),
                Text('Status: ${treino['status']}'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Fechar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showCreateTreinoDialog(BuildContext context) {
    int? category;
    DateTime? workoutDate;
    String? description;
    int? status;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Criar Novo Treino'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      decoration: const InputDecoration(labelText: 'Categoria'),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('Iniciante')),
                        DropdownMenuItem(
                          value: 1,
                          child: Text('Intermediário'),
                        ),
                        DropdownMenuItem(value: 2, child: Text('Avançado')),
                      ],
                      onChanged: (value) {
                        category = value;
                      },
                    ),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Data da Ficha',
                      ),
                      onTap: () async {
                        DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2101),
                        );
                        if (pickedDate != null) {
                          setState(() {
                            workoutDate = pickedDate;
                          });
                        }
                      },
                      readOnly: true,
                      controller: TextEditingController(
                        text:
                            workoutDate != null
                                ? workoutDate!.toLocal().toString().split(
                                  ' ',
                                )[0]
                                : '',
                      ),
                    ),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Descrição'),
                      onChanged: (value) {
                        description = value;
                      },
                    ),
                    DropdownButtonFormField<int>(
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('Ativo')),
                        DropdownMenuItem(value: 2, child: Text('Finalizado')),
                      ],
                      onChanged: (value) {
                        status = value;
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                print('Atleta ID: ${widget.atletaId}');
                print('Category: $category');
                print('Workout Date: $workoutDate');
                print('Description: $description');
                print('Status: $status');

                Navigator.pop(context);
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  void _showAssignTreinoDialog(BuildContext context, dynamic treino) {
    showDialog(
      context: context,
      builder: (context) {
        int? selectedAthleteId;

        return AlertDialog(
          title: const Text('Atribuir Treino ao Atleta'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Selecione um atleta para atribuir este treino:',
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      decoration: const InputDecoration(labelText: 'Atleta'),
                      items:
                          _mockAtletas.map((athlete) {
                            return DropdownMenuItem<int>(
                              value: athlete['id'],
                              child: Text(athlete['nome']),
                            );
                          }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedAthleteId = value;
                        });
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedAthleteId != null) {
                  print(
                    'Atribuir treino ${treino['id']} ao atleta $selectedAthleteId',
                  );
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Por favor, selecione um atleta.'),
                    ),
                  );
                }
              },
              child: const Text('Atribuir'),
            ),
          ],
        );
      },
    );
  }
}

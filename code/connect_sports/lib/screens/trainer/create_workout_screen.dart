import 'dart:convert';
import 'package:connect_sports/provider/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config.dart';
import 'package:connect_sports/services/http_service.dart';

class CreateWorkoutScreen extends StatefulWidget {

  const CreateWorkoutScreen({Key? key}) : super(key: key);

  @override
  State<CreateWorkoutScreen> createState() => _CreateWorkoutScreenState();
}

class _CreateWorkoutScreenState extends State<CreateWorkoutScreen> {
  List<Map<String, dynamic>> fichas = [];
  List<Map<String, dynamic>> esportes = [];
  bool isLoadingEsportes = true;

  final TextEditingController nomeController = TextEditingController();
  final TextEditingController descricaoController = TextEditingController();
  final TextEditingController dataController = TextEditingController();
  String? esporteId;
  String? categoria;

  @override
  void initState() {
    super.initState();
    _loadEsportes();
    _loadFichas();
  }

  Future<void> _loadEsportes() async {
    setState(() {
      isLoadingEsportes = true;
    });
    try {
      final response = await sendRequest(
        context: context,
        method: 'GET',
        url: '${Config.baseURL}/utils/esportes',
        body: '',
      );
      if (response.statusCode == 200) {
        final List<dynamic> esportesJson = jsonDecode(response.body);
        List<Map<String, dynamic>> esportesList = esportesJson
            .map<Map<String, dynamic>>((e) => {
                  'id': e['id'],
                  'nome': e['nome_esporte'],
                })
            .toList();
        setState(() {
          esportes = esportesList;
          isLoadingEsportes = false;
        });
      } else {
        setState(() {
          esportes = [];
          isLoadingEsportes = false;
        });
      }
    } catch (e) {
      setState(() {
        esportes = [];
        isLoadingEsportes = false;
      });
    }
  }

  Future<void> _loadFichas() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final idTreinador = userProvider.user?.userData?['id'] ?? 0;

    try {
      final response = await sendRequest(
        context: context,
        method: 'GET',
        url: '${Config.baseURL}/fichas/treinador/$idTreinador', // ajuste o parâmetro conforme sua API
        body: '',
      );
      if (response.statusCode == 200) {
        final List<dynamic> fichasJson = jsonDecode(response.body);
        setState(() {
          fichas = fichasJson.cast<Map<String, dynamic>>();
        });
      } else {
        setState(() {
          fichas = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar fichas: ${response.body}')),
        );
      }
    } catch (e) {
      setState(() {
        fichas = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar fichas: $e')),
      );
    }
  }

  void _showFichaForm({int? editIndex}) {
    final _formKey = GlobalKey<FormState>();
    if (editIndex != null) {
      nomeController.text = fichas[editIndex]['nome_ficha'] ?? '';
      descricaoController.text = fichas[editIndex]['descricao'] ?? '';
      esporteId = fichas[editIndex]['id_esporte']?.toString();
      categoria = fichas[editIndex]['categoria']?.toString();
      dataController.text = fichas[editIndex]['data_ficha'] ?? '';
    } else {
      nomeController.clear();
      descricaoController.clear();
      esporteId = null;
      categoria = null;
      dataController.clear();
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(editIndex != null ? 'Editar Ficha' : 'Nova Ficha'),
        content: SizedBox(
          width: 400,
          child: isLoadingEsportes
              ? const Center(child: CircularProgressIndicator())
              : Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nomeController,
                          decoration: const InputDecoration(labelText: 'Nome da Ficha'),
                          validator: (value) =>
                              value == null || value.isEmpty ? 'Insira o nome' : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: esporteId,
                          items: esportes
                              .map((e) => DropdownMenuItem<String>(
                                    value: e['id'].toString(),
                                    child: Text(e['nome']),
                                  ))
                              .toList(),
                          decoration: const InputDecoration(labelText: 'Tipo de Esporte'),
                          validator: (value) =>
                              value == null || value.isEmpty ? 'Selecione o esporte' : null,
                          onChanged: (value) => setState(() => esporteId = value),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: descricaoController,
                          decoration: const InputDecoration(labelText: 'Descrição'),
                          maxLines: 3,
                          validator: (value) =>
                              value == null || value.isEmpty ? 'Insira a descrição' : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: categoria,
                          items: const [
                            DropdownMenuItem(value: "1", child: Text("Leve")),
                            DropdownMenuItem(value: "2", child: Text("Intermediário")),
                            DropdownMenuItem(value: "3", child: Text("Avançado")),
                          ],
                          decoration: const InputDecoration(labelText: 'Categoria'),
                          validator: (value) =>
                              value == null || value.isEmpty ? 'Selecione a categoria' : null,
                          onChanged: (value) => categoria = value,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: dataController,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Data da Ficha',
                            hintText: 'Selecione a data',
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          validator: (value) =>
                              value == null || value.isEmpty ? 'Selecione a data' : null,
                          onTap: () async {
                            FocusScope.of(context).requestFocus(FocusNode());
                            DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              dataController.text =
                                  "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                if (editIndex != null) {
                  await _editarFicha(editIndex);
                } else {
                  await _salvarFicha();
                }
                Navigator.pop(context);
              }
            },
            child: Text(editIndex != null ? 'Salvar' : 'Criar'),
          ),
        ],
      ),
    );
  }

  void _deleteFicha(int index) {
    setState(() {
      fichas.removeAt(index);
    });
  }

  Future<void> _editarFicha(int index) async {

    final fichaEditada = {
      'nome_ficha': nomeController.text, // <-- nome_ficha
      'descricao': descricaoController.text,
      'categoria': categoria!,
      'data_ficha': dataController.text, // dataController precisa existir
      'id_esporte': esporteId, // id do esporte selecionado
    };

    final response = await sendRequest(
      context: context,
      method: 'PUT',
      url: '${Config.baseURL}/fichas/${fichas[index]['id']}',
      body: jsonEncode(fichaEditada),
    );

    if (response.statusCode == 200) {
      setState(() {
        fichas[index] = fichaEditada;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ficha editada com sucesso!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao editar ficha: ${response.body}')),
      );
    }
  }

  Future<void> _salvarFicha() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final idTreinador = userProvider.user?.userData?['id'] ?? 0;

    //converte data para ISO
    if (dataController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecione uma data.')),
      );
      return;
    }
    final dataParts = dataController.text.split('/');
    String dataISO = '${dataParts[2]}-${dataParts[1]}-${dataParts[0]}T00:00:00Z';

    final novaFicha = {
      'nome_ficha': nomeController.text, // <-- nome_ficha
      'id_treinador': idTreinador, 
      'descricao': descricaoController.text,
      'categoria': categoria!, // categoria deve ser definida no formulário
      'data_ficha': dataISO, // dataController precisa existir
      'id_esporte': esporteId, // id do esporte selecionado
    };

    final response = await sendRequest(
      context: context,
      method: 'POST',
      url: '${Config.baseURL}/fichas',
      body: novaFicha,
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      setState(() {
        fichas.add(novaFicha);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ficha cadastrada com sucesso!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao cadastrar ficha: ${response.body}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fichas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nova Ficha',
            onPressed: _showFichaForm,
          ),
        ],
      ),
      body: fichas.isEmpty
          ? const Center(child: Text('Nenhuma ficha cadastrada.'))
          : ListView.builder(
              itemCount: fichas.length,
              itemBuilder: (context, index) {
                final ficha = fichas[index];
                final esporteNome = esportes.firstWhere(
                  (e) => e['id'].toString() == ficha['id_esporte'].toString(),
                  orElse: () => {'nome': 'Desconhecido'},
                )['nome'];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.fitness_center, color: Colors.green),
                    title: Text(ficha['nome'] ?? ''),
                    subtitle: Text(
                        'Esporte: $esporteNome\nDescrição: ${ficha['descricao']}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          tooltip: 'Editar',
                          onPressed: () => _showFichaForm(editIndex: index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Excluir',
                          onPressed: () => _deleteFicha(index),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

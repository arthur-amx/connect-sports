import 'package:connect_sports/config.dart';
import 'package:connect_sports/provider/user_provider.dart';
import 'package:connect_sports/screens/custom/drawer.dart';
import 'package:connect_sports/services/http_service.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:connect_sports/screens/eventos/detalhes.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

class EventoScreen extends StatefulWidget {
  @override
  _EventoScreenState createState() => _EventoScreenState();
}

class _EventoScreenState extends State<EventoScreen> {
  //urlbase
  final String _baseUrl = Config.baseURL;

  // Variáveis de estado para armazenar os dados do usuário e o estado de carregamento
  String? _userName;
  String? _userTrainerPhone;
  String? _userTrainerName;
  bool _isLoading = true;
  bool _isAtleta = true;
  int _userId = 0;

  //variaveis de texto
  final TextEditingController nomeController = TextEditingController();
  final TextEditingController dataController = TextEditingController();
  final TextEditingController descricaoController = TextEditingController();
  final TextEditingController searchController =
      TextEditingController(); // Controlador da barra de pesquisa

  // Lista de eventos
  final List<Map<String, String>> eventos = [];
  List<Map<String, String>> eventosFiltrados = []; // Lista de eventos filtrados

  // Lista de esportes carregados
  List<Map<String, dynamic>> esportes = [];
  int? esporteSelecionadoId; // ID do esporte selecionado

   @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Recarrega os eventos registrados sempre que a tela de perfil for exibida novamente
    //_fetchEventosRegistrados();
    _loadEventos();
    _loadEsportes();
  }

  // Função para carregar os eventos quando abrir a tela
  Future<void> _loadEventos() async {
    setState(() {
      _isLoading = true;
    });

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final idUsuario = userProvider.user?.userData?['id'] ?? 0;

    try {
      final url = '$_baseUrl/eventos/$idUsuario';
      final response = await sendRequest(
        context: context,
        method: 'GET',
        url: url,
        body: '',
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> eventosJson = jsonDecode(response.body);
        setState(() {
          eventos.clear(); // Limpa a lista atual de eventos
          for (var evento in eventosJson) {
            // Converte a data para o formato dd/MM/yyyy
            String dataFormatada = '';
            if (evento['data_evento'] != null) {
              String dataBruta = evento['data_evento'];
              try {
                // Divide a string da data no formato YYYY-DD-MM
                final DateTime data = DateTime.parse(dataBruta);

                // Formata a data para dd/MM/yyyy
                dataFormatada =
                    "${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}";
              } catch (e) {
                print("Erro ao processar a data: $dataBruta. Erro: $e");
                dataFormatada = "Data inválida";
              }
            }

            eventos.add({
              'id': (evento['id'] ?? 0).toString(),
              'foto': evento['foto'] ?? 'assets/images/academia.jpg',
              'nome': evento['nome_evento'] ?? 'Sem Nome',
              'data': dataFormatada,
              'tipo': (evento['tipo_evento'] ?? 0).toString(),
              'tipo_nome': evento['tipo_evento_nome'] ?? 'Sem Tipo',
              'descricao': evento['descricao'] ?? 'Sem Descrição',
              'isVinculado': (evento['atleta_vinculado'] ?? 0).toString(),
              'isMine': (evento['criado_por'] == idUsuario).toString(),
              'userId': (_userId).toString(),
            });
          }
          eventosFiltrados =
              eventos; // Inicializa os eventos filtrados com todos os eventos
          
          setState(() {
            _isLoading = false;
          });
          
        });
      } else {
        //decode json to show message
        final responseBody = jsonDecode(response.body);
        String errorMessage = responseBody['message'] ?? 'Erro ao carregar eventos: ${response.statusCode}';
        _showErrorPopup(errorMessage);
      }
    } on http.ClientException catch (e) {
      if (!mounted) return;
      print('Erro de rede/conexão: $e');
      _showErrorPopup(
        'Não foi possível conectar ao servidor. Verifique sua conexão.',
      );
    } on TimeoutException catch (_) {
      if (!mounted) return;
      print('Erro: Timeout na requisição');
      _showErrorPopup('O servidor demorou muito para responder.');
    } catch (e) {
      if (!mounted) return;
      print('Erro inesperado ao carregar eventos: $e');
      _showErrorPopup('Ocorreu um erro inesperado: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  // Função para carregar a lista de esportes
  Future<void> _loadEsportes() async {

    try {
      final url = '$_baseUrl/utils/esportes';
      final response = await sendRequest(
        context: context,
        method: 'GET',
        url: url,
        body: '',
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> esportesJson = jsonDecode(response.body);
        setState(() {
          esportes =
              esportesJson
                  .map(
                    (esporte) => {
                      'id': esporte['id'],
                      'nome_esporte': esporte['nome_esporte'],
                    },
                  )
                  .toList();
        });
      } else {
        print('Erro ao carregar esportes: ${response.statusCode}');
      }
    } catch (e) {
      print('Erro ao carregar esportes: $e');
    }
  }

  // Função para cadastrar evento
  Future<void> _cadastrarEvento() async {
    setState(() {
      _isLoading = true;
    });

    String nome = nomeController.text;
    String data = dataController.text;
    String descricao = descricaoController.text;

    print(
      'Nome: $nome, Esporte ID: $esporteSelecionadoId, Data: $data, Descrição: $descricao',
    );

    //recupera userId do UserProvider
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.user?.userData?['id'] ?? 0;

    try {
      final url = '$_baseUrl/eventos/cadastro/$userId';
      final response = await sendRequest(
        context: context,
        method: 'POST',
        url: url,
        body: jsonEncode({
          'nome_evento': nome,
          'tipo_evento': esporteSelecionadoId, // Envia o ID do esporte
          'data_evento': data,
          'descricao': descricao,
        }),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;
      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 201) {
        // Cadastro bem-sucedido
        _showSuccessPopup("Evento cadastrado com sucesso!");

        //limpa os campos após o cadastro
        nomeController.clear();
        dataController.clear();
        descricaoController.clear();
        setState(() {
          esporteSelecionadoId = null; // Reseta o esporte selecionado
        });
      } else {
        // Erro vindo do backend (ex: 400, 409, 500)
        String errorMessage =
            responseBody['message'] ?? 'Erro desconhecido ao cadastrar.';
        _showErrorPopup(errorMessage);
        print('Erro de cadastro (${response.statusCode}): ${response.body}');
      }
    } on http.ClientException catch (e) {
      if (!mounted) return;
      print('Erro de rede/conexão: $e');
      _showErrorPopup(
        'Não foi possível conectar ao servidor. Verifique sua conexão e o IP do backend.',
      );
    } on TimeoutException catch (_) {
      if (!mounted) return;
      print('Erro: Timeout na requisição');
      _showErrorPopup('O servidor demorou muito para responder.');
    } catch (e) {
      if (!mounted) return;
      print('Erro inesperado no cadastro: $e');
      _showErrorPopup('Ocorreu um erro inesperado: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _vincularUsuarioAoEvento(int eventoId) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.user?.userData?['id'] ?? 0;

    try {
      final url = '$_baseUrl/eventos/vincular/$eventoId';
      final response = await sendRequest(
        context: context,
        method: 'POST',
        url: url,
        body: jsonEncode({'id_usuario': userId}),
      );

      if (response.statusCode == 201) {
        _showSuccessPopup("Você foi registrado no evento com sucesso!");
        //recarrega a lista de eventos
        setState(() {
          // Atualiza o estado do evento para refletir o registro
          eventosFiltrados = eventosFiltrados.map((evento) {
            if (int.tryParse(evento['id'] ?? '0') == eventoId) {
              evento['isVinculado'] = "1";
            }
            return evento;
          }).toList();
        });

      } else {
        _showErrorPopup("Erro ao registrar no evento: ${response.statusCode}");
      }
    } catch (e) {
      _showErrorPopup("Erro ao registrar no evento: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _cancelarRegistroNoEvento(int eventoId) async {
    setState(() {
      _isLoading = true;
    });

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.user?.userData?['id'] ?? 0;

    try {
      final url = '$_baseUrl/eventos/desvincular/$eventoId';
      final response = await sendRequest(
        context: context,
        method: 'PUT',
        url: url,
        body: jsonEncode({'id_usuario': userId}),
      );

      if (response.statusCode == 200) {
        _showSuccessPopup("Seu registro no evento foi cancelado com sucesso!");
        setState(() {
          // Atualiza o estado do evento para refletir o cancelamento
          eventosFiltrados = eventosFiltrados.map((evento) {
            if (int.tryParse(evento['id'] ?? '0') == eventoId) {
              evento['isVinculado'] = "0";
            }
            return evento;
          }).toList();
        });
      } else {
        _showErrorPopup("Erro ao cancelar o registro no evento: ${response.statusCode}");
      }
    } catch (e) {
      _showErrorPopup("Erro ao cancelar o registro no evento: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _editarEvento(Map<String, String> evento) async {
    setState(() {
      _isLoading = true;
    });

    String nome = nomeController.text;
    String data = dataController.text;
    String descricao = descricaoController.text;

    try {
      final url = '$_baseUrl/eventos/alterar/${evento['id']}';
      final response = await sendRequest(
        context: context,
        method: 'PUT',
        url: url,
        body: jsonEncode({
          'nome_evento': nome,
          'tipo_evento': esporteSelecionadoId, // Envia o ID do esporte
          'data_evento': data,
          'descricao': descricao,
          'status_evento': 1,
        }),
      );

      if (response.statusCode == 200) {
        _showSuccessPopup("Evento atualizado com sucesso!");
      } else {
        _showErrorPopup("Erro ao atualizar o evento: ${response.statusCode}");
      }
    } catch (e) {
      _showErrorPopup("Erro ao atualizar o evento: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
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
    //_loadEsportes(); // Carrega a lista de esportes ao iniciar
    eventosFiltrados =
        eventos; // Inicializa os eventos filtrados com todos os eventos
  }

  // Função para abrir o pop-up de cadastro de evento
  void _showAddEventDialog() {
    // Limpa os controladores antes de abrir o pop-up
    nomeController.clear();
    dataController.clear();
    descricaoController.clear();
    esporteSelecionadoId = null; // Reseta o esporte selecionado

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Cadastrar Novo Evento"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nomeController,
                  decoration: const InputDecoration(
                    labelText: "Nome do Evento",
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  value: esporteSelecionadoId,
                  items: esportes.map((esporte) {
                    return DropdownMenuItem<int>(
                      value: esporte['id'],
                      child: Text(esporte['nome_esporte']),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      esporteSelecionadoId = value;
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: "Tipo de Esporte",
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descricaoController,
                  decoration: const InputDecoration(labelText: "Descrição"),
                  maxLines: 5, // Permite múltiplas linhas para descrição
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: dataController,
                  readOnly: true, // Impede edição manual
                  decoration: const InputDecoration(
                    labelText: "Data",
                    suffixIcon: Icon(
                      Icons.calendar_today,
                    ), // Ícone de calendário
                  ),
                  onTap: () async {
                    DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000), // Data mínima
                      lastDate: DateTime(2100), // Data máxima
                    );
                    if (pickedDate != null) {
                      setState(() {
                        dataController.text =
                            "${pickedDate.day}/${pickedDate.month}/${pickedDate.year}";
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () async {
                await _cadastrarEvento(); // Chama a função para cadastrar o evento
                Navigator.of(context).pop(); // Fecha o pop-up
                await _loadEventos(); // Recarrega a lista de eventos
              },
              child: const Text("Salvar"),
            ),
          ],
        );
      },
    );
  }

  // Função para abrir o pop-up de edição de evento
  void _showEditEventDialog(Map<String, String> evento) {
    // Preenche os controladores com os dados do evento
    nomeController.text = evento['nome'] ?? '';
    descricaoController.text = evento['descricao'] ?? '';
    dataController.text = evento['data'] ?? '';
    esporteSelecionadoId = int.tryParse(evento['tipo'] ?? '0');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Editar Evento"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nomeController,
                  decoration: const InputDecoration(
                    labelText: "Nome do Evento",
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  value: esporteSelecionadoId,
                  items: esportes.map((esporte) {
                    return DropdownMenuItem<int>(
                      value: esporte['id'],
                      child: Text(esporte['nome_esporte']),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      esporteSelecionadoId = value;
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: "Tipo de Esporte",
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descricaoController,
                  decoration: const InputDecoration(labelText: "Descrição"),
                  maxLines: 5, // Permite múltiplas linhas para descrição
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: dataController,
                  readOnly: true, // Impede edição manual
                  decoration: const InputDecoration(
                    labelText: "Data",
                    suffixIcon: Icon(
                      Icons.calendar_today,
                    ), // Ícone de calendário
                  ),
                  onTap: () async {
                    DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000), // Data mínima
                      lastDate: DateTime(2100), // Data máxima
                    );
                    if (pickedDate != null) {
                      setState(() {
                        dataController.text =
                            "${pickedDate.day}/${pickedDate.month}/${pickedDate.year}";
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () async {
                await _editarEvento(evento); // Chama a função para editar o evento
                Navigator.of(context).pop(); // Fecha o pop-up
                await _loadEventos(); // Recarrega a lista de eventos
              },
              child: const Text("Salvar"),
            ),
          ],
        );
      },
    );
  }

  // Função para filtrar eventos com base no tipo de esporte
  void _filtrarEventos(String query) {
    setState(() {
      if (query.isEmpty) {
        eventosFiltrados =
            eventos; // Mostra todos os eventos se a pesquisa estiver vazia
      } else {
        eventosFiltrados =
            eventos.where((evento) {
              final tipo = evento['tipo_nome']?.toLowerCase() ?? '';
              return tipo.contains(query.toLowerCase());
            }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final userName = userProvider.user?.userData?['nome'] ?? 'Usuário';
    final userId = userProvider.user?.userData?['id'] ?? 0;
    final userTrainerName = userProvider.user?.userTrainerData?['nome'] ?? 'Treinador';
    final userTrainerPhone = userProvider.user?.userTrainerData?['telefone'] ?? '';
    final isAtleta = userProvider.user?.userData?['isAtleta'] ?? true;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          // Usa o nome carregado ou um padrão se for nulo
          'Olá, ${(userName ?? 'Usuário').split(' ')[0]}!',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: TextField(
              controller: searchController,
              onChanged:
                  _filtrarEventos, // Chama a função de filtragem ao digitar
              decoration: InputDecoration(
                hintText: 'Pesquisar por tipo de esporte...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
        ),
      ),
      endDrawer: CustomDrawer(
        isAtleta: isAtleta,
        userId: userId,
        baseUrl: _baseUrl,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child:
                eventosFiltrados.isEmpty && !_isLoading
                    ? const Center(
                      child: Text(
                        "Nenhum registro encontrado",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    )
                    : ListView.builder(
                      itemCount: eventosFiltrados.length,
                      itemBuilder: (context, index) {
                        final evento = eventosFiltrados[index];
                        return InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) =>
                                        EventoDetalhesScreen(evento: evento),
                              ),
                            ).then((_) {
                              // Recarrega a lista de eventos ao voltar
                              _loadEventos();
                            });
                          },
                          child: Card(
                            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Imagem à esquerda
                                  ClipRRect(
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(16),
                                      bottomLeft: Radius.circular(16),
                                    ),
                                    child: SizedBox(
                                      width: 90,
                                      height: 90,
                                      child: Image.network(
                                        evento['foto'] ?? 'assets/images/academia.jpg',
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Image.asset('assets/images/academia.jpg', fit: BoxFit.cover),
                                      ),
                                    ),
                                  ),
                                  // Informações do evento
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            evento['nome'] ?? 'Sem nome',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            evento['data'] ?? '',
                                            style: const TextStyle(fontSize: 13, color: Colors.grey),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            evento['descricao'] ?? '',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Botão editar à direita, só se for dono
                                  if (evento['isMine'] == "true")
                                    Padding(
                                      padding: const EdgeInsets.only(right: 12),
                                      child: GestureDetector(
                                        onTap: () {
                                          _showEditEventDialog(evento);
                                        },
                                        child: CircleAvatar(
                                          backgroundColor: Colors.orange,
                                          radius: 20,
                                          child: const Icon(
                                            Icons.edit,
                                            color: Colors.white,
                                            size: 22,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddEventDialog,
        backgroundColor: Colors.black,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

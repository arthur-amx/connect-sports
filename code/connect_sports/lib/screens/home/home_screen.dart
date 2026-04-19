import 'dart:convert';

import 'package:connect_sports/provider/user_provider.dart';
import 'package:connect_sports/screens/custom/drawer.dart'; // Assuming this path is correct
import 'package:connect_sports/screens/trainer/workout_list_screen.dart';
import 'package:connect_sports/screens/usuario/detalhes.dart';
import 'package:connect_sports/screens/usuario/ficha.dart';
import 'package:connect_sports/services/http_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:connect_sports/config.dart';
import 'package:connect_sports/screens/trainer/create_workout_screen.dart';

//import 'package:share_plus/share_plus.dart'; // Import for sharing functionality

// Transformado em StatefulWidget
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // Mixin still needed for Athlete's TabController
  final String _baseUrl = Config.baseURL; // Example API base URL
  bool _fetchDone = false;

  // State variables
  String? _userName;
  int _userId = 0;
  bool _isAtleta = true; // Default to athlete, will be updated from storage
  bool _isLoading = true;
  String? _trainerShareCode;

  // Athlete specific state
  String? _userTrainerPhone;
  String? _userTrainerName;
  List<Map<String, dynamic>> _eventosRegistrados = [];
  List<Map<String, dynamic>> _fichasDoDia = []; // Fichas do dia

  late TabController _tabController; // Still needed for Athlete view

  double _percentualTreinosConcluidos = 0.0; // Percentual de treinos concluídos
  String _tempoTotalTreino = "0h 0min"; // Tempo total de treino

  List<double> _dadosTreinosSemana = [0, 0, 0, 0, 0, 0, 0]; // Dados semanais
  List<String> _dadosProgressoMensal = ["","","","","","","","","","","",""]; // Dados mensais

  // --- Getters ---
  // Message for Athlete to contact Trainer
  String get _whatsAppMessage =>
      "Olá ${_userTrainerName ?? 'Instrutor'}! Surgiu uma dúvida aqui e preciso falar com voce. Está disponível?";

  List<Map<String, dynamic>> get eventosSemana {
    DateTime hoje = DateTime.now();
    DateTime fimDaSemana = hoje.add(const Duration(days: 7));

    return _eventosRegistrados.where((evento) {
      DateTime dataEvento = DateTime.parse(evento['data']);
      return dataEvento.isAfter(hoje.subtract(const Duration(days: 1))) &&
          dataEvento.isBefore(fimDaSemana);
    }).toList();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_fetchDone) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userId = userProvider.user?.userData?['id'];
      if (userId != null) {
        _fetchEventosRegistrados();
        _fetchPercentualTreinosConcluidos();
        _fetchTempoDeTreinoTotal();
        _fetchTreinosNaSemanaPorDia();
        _fetchProgressoMensal();
        _fetchFichasDoDia();
        _fetchDone = true;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Initialize TabController - needed for Athlete view
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose(); // Dispose TabController when the widget is removed
    super.dispose();
  }

  Future<void> _fetchEventosRegistrados() async {
    try {
      // Obtém o ID do usuário do UserProvider
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final int? userId = userProvider.user?.userData?['id'];
      _trainerShareCode = userProvider.codigoConvite;

      if (userId == null) {
        print('Erro: ID do usuário não encontrado.');
        setState(() {
          _isLoading = false; // Para o loading mesmo em caso de erro
        });
        return;
      }

      final url = '$_baseUrl/eventos/retornar/usuario/$userId';
      final response = await sendRequest(
        context: context,
        method: 'GET',
        url: url,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _eventosRegistrados =
              data.map((evento) {
                return {
                  'id': evento['id'],
                  'nome': evento['nome_evento'] ?? 'Sem Nome',
                  'data':
                      evento['data_evento']?.split('T')[0] ??
                      '0000-00-00', // Garante o formato YYYY-MM-DD
                  'descricao': evento['descricao'] ?? 'Sem Descrição',
                  'isVinculado': (evento['atleta_vinculado'] ?? 0).toString(),
                };
              }).toList();
          _isLoading = false; // Para o loading após o carregamento
        });
      } else {
        print('Erro ao buscar eventos registrados: ${response.statusCode}');
        setState(() {
          _isLoading = false; // Para o loading mesmo em caso de erro
        });
      }
    } catch (e) {
      print('Erro ao buscar eventos registrados: $e');
      setState(() {
        _isLoading = false; // Para o loading mesmo em caso de erro
      });
    }
  }

  Future<void> _fetchPercentualTreinosConcluidos() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final int? userId = userProvider.user?.userData?['id'];

      if (userId == null) {
        print('Erro: ID do usuário não encontrado.');
        return;
      }

      final url = '$_baseUrl/indicadores/treinos/$userId';
      final response = await sendRequest(
        context: context,
        method: 'GET',
        url: url,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _percentualTreinosConcluidos = (data['percentual'] ?? 0.0).toDouble();
        });
      } else {
        print(
          'Erro ao buscar percentual de treinos concluídos: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Erro ao buscar percentual de treinos concluídos: $e');
    }
  }

  Future<void> _fetchTempoDeTreinoTotal() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final int? userId = userProvider.user?.userData?['id'];

      if (userId == null) {
        print('Erro: ID do usuário não encontrado.');
        return;
      }

      final url = '$_baseUrl/indicadores/tempoTreino/$userId';
      final response = await sendRequest(
        context: context,
        method: 'GET',
        url: url,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          double minutos = 0;
          // Garante que o valor é int
          if (data['tempoTotalTreinoMinutos'] is int) {
            minutos = data['tempoTotalTreinoMinutos'].toDouble();
          } else if (data['tempoTotalTreinoMinutos'] is String) {
            minutos = double.tryParse(data['tempoTotalTreinoMinutos']) ?? 0.0;
          }
          if (minutos >= 60) {
            final horas = minutos ~/ 60;
            final min = minutos % 60;
            _tempoTotalTreino = "${horas}h ${min.toInt()}min";
          } else {
            _tempoTotalTreino = "${minutos.toInt()}min";
          }
        });
      } else {
        print('Erro ao buscar tempo total de treino: ${response.statusCode}');
      }
    } catch (e) {
      print('Erro ao buscar tempo total de treino: $e');
    }
  }

  Future<void> _fetchTreinosNaSemanaPorDia() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final int? userId = userProvider.user?.userData?['id'];

      if (userId == null) {
        print('Erro: ID do usuário não encontrado.');
        return;
      }

      final url = '$_baseUrl/indicadores/treinosSemana/$userId';
      final response = await sendRequest(
        context: context,
        method: 'GET',
        url: url,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Se o backend retorna uma string JSON, decodifique novamente:
        List<dynamic> lista;
        if (data is String) {
          lista = jsonDecode(data);
        } else {
          lista = data;
        }

        // Crie uma lista com 7 posições (uma para cada dia da semana)
        List<double> valores = List.filled(7, 0.0);

        for (var item in lista) {
          // Descobre o dia da semana (0=segunda, 6=domingo)
          DateTime dataFicha = DateTime.parse(item['dia']);
          int diaSemana = dataFicha.weekday - 1; // weekday: 1=segunda, 7=domingo
          if (diaSemana >= 0 && diaSemana < 7) {
            valores[diaSemana] = double.tryParse(item['total_treinos'].toString()) ?? 0.0;
          }
        }

        setState(() {
          _dadosTreinosSemana = valores;
        });
      } else {
        print('Erro ao buscar dados semanais: ${response.statusCode}');
      }
    } catch (e) {
      print('Erro ao buscar dados semanais: $e');
    }
  }

  Future<void> _fetchProgressoMensal() async {
  try {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final int? userId = userProvider.user?.userData?['id'];

    if (userId == null) {
      print('Erro: ID do usuário não encontrado.');
      return;
    }

    final url = '$_baseUrl/indicadores/progressoMensal/$userId';
    final response = await sendRequest(
      context: context,
      method: 'GET',
      url: url,
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      setState(() {
        final valores = data['valores'];
        if (valores is List) {
          _dadosProgressoMensal = List<String>.from(valores.map((v) => v.toString()));
        } else {
          _dadosProgressoMensal = List.filled(12, '0h 0min');
        }
      });
    } else {
      print('Erro ao buscar progresso mensal: ${response.statusCode}');
    }
  } catch (e) {
    print('Erro ao buscar progresso mensal: $e');
  }
}


  Future<void> _fetchFichasDoDia() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final int? userId = userProvider.user?.userData?['id'];

      if (userId == null) {
        print('Erro: ID do usuário não encontrado.');
        return;
      }

      final url = '$_baseUrl/fichas/dia/$userId';
      final response = await sendRequest(
        context: context,
        method: 'GET',
        url: url,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _fichasDoDia = data.map((ficha) {
            return {
              'id': ficha['id'],
              'descricao': ficha['descricao'] ?? '',
              'categoria': ficha['categoria'],
              'status': ficha['status_ficha'],
              'data': ficha['data_ficha']?.split('T')[0] ?? '',
              'esporte': ficha['nome_esporte'],
              'foto': 'assets/images/academia.jpg',
            };
          }).toList();
        });
      } else {
        print('Erro ao buscar fichas do dia: ${response.statusCode}');
      }
    } catch (e) {
      print('Erro ao buscar fichas do dia: $e');
    }
  }

  // Métodos para iniciar/finalizar ficha
  Future<void> _iniciarFicha(int fichaId) async {
    try {
      final url = '$_baseUrl/fichas/iniciar/$fichaId';
      final response = await sendRequest(
        context: context,
        method: 'PUT',
        url: url,
      );
      if (response.statusCode == 200) {
        _showSuccessPopup("Ficha iniciada com sucesso!");
        await _fetchFichasDoDia();
      } else {
        _showErrorPopup("Erro ao iniciar ficha: ${response.statusCode}");
      }
    } catch (e) {
      _showErrorPopup("Erro ao iniciar ficha: $e");
    }
  }

  Future<void> _finalizarFicha(int fichaId) async {
    try {
      final url = '$_baseUrl/fichas/finalizar/$fichaId';
      final response = await sendRequest(
        context: context,
        method: 'PUT',
        url: url,
      );
      if (response.statusCode == 200) {
        _showSuccessPopup("Ficha finalizada com sucesso!");
        await _fetchFichasDoDia();
        await _fetchPercentualTreinosConcluidos();
        await _fetchTempoDeTreinoTotal();
        await _fetchProgressoMensal();
      } else {
        _showErrorPopup("Erro ao finalizar ficha: ${response.statusCode}");
      }
    } catch (e) {
      _showErrorPopup("Erro ao finalizar ficha: $e");
    }
  }

  // Method for Athlete to launch WhatsApp to contact Trainer
  Future<void> _launchWhatsApp(BuildContext context) async {
    if (_userTrainerPhone == null || _userTrainerPhone!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Número de telefone do instrutor não disponível"),
        ),
      );
      return;
    }

    try {
      final encodedMessage = Uri.encodeComponent(_whatsAppMessage);
      final cleanPhone = _userTrainerPhone!.replaceAll(RegExp(r'[^\d+]'), '');
      final String formattedPhone =
          cleanPhone.startsWith('+')
              ? cleanPhone
              : '55$cleanPhone'; // Assume Brazil (55)
      final Uri url = Uri.parse(
        'https://wa.me/$formattedPhone?text=$encodedMessage',
      );

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Não foi possível abrir o WhatsApp. Verifique se está instalado.",
            ),
          ),
        );
        print('Não foi possível abrir a URL: $url');
      }
    } catch (e) {
      print('Erro ao tentar abrir WhatsApp: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Ocorreu um erro ao tentar abrir o WhatsApp."),
        ),
      );
    }
  }

  // Method for Trainer to share their code
  Future<void> _shareTrainerCode(BuildContext context) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    _trainerShareCode = userProvider.codigoConvite;
    if (_trainerShareCode == null || _trainerShareCode!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Código de compartilhamento não disponível."),
        ),
      );
      return;
    }
    try {
      final String shareText =
          'Olá! Use meu código $_trainerShareCode para se conectar comigo como seu treinador no Connect Sports.';
      // ignore: deprecated_member_use
      await Share.share(shareText, subject: 'Código de Treinador Connect Sports'); // LINHA CRÍTICA COMENTADA
    } catch (e) {
      print('Erro ao compartilhar código: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Não foi possível compartilhar o código."),
        ),
      );
    }
  }

  // --- UI Building ---

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final userName = userProvider.user?.userData?['nome'] ?? 'Usuário';
    final isAtleta = userProvider.user?.userData?['isAtleta'] ?? true;
    final userTrainerName = userProvider.user?.userTrainerData?['nome'];
    final userTrainerPhone = userProvider.user?.userTrainerData?['telefone'];
    _userTrainerPhone = userProvider.user?.userTrainerData?['telefone'];
    final trainerShareCode =
        userProvider.user?.userData?['codigo_compartilhamento'];

    final Color backgroundColor = Colors.grey.shade100;
    final Color textColor = Colors.black87;
    final Color cardColor = Colors.white;

    if (_isLoading) {
      // return Scaffold(
      //   appBar: AppBar(
      //     backgroundColor: Colors.black,
      //     title: const Text(
      //       "Carregando...",
      //       style: TextStyle(color: Colors.white),
      //     ),
      //     iconTheme: const IconThemeData(color: Colors.white),
      //     automaticallyImplyLeading: false,
      //   ),
      //   body: const Center(child: CircularProgressIndicator()),
      // );
    }

    if (isAtleta) {
      final String trainerDisplayName = userTrainerName ?? 'Instrutor';
      String line1Name = "Fale com";
      String line2Name = trainerDisplayName;
      if (trainerDisplayName == 'Instrutor') {
        line1Name = "Fale com o";
      }

      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
          automaticallyImplyLeading: false,
          title: Text(
            'Olá, ${userName.split(' ')[0]}!',
            style: const TextStyle(color: Colors.white),
          ),
          bottom: TabBar(
            // TabBar for Athlete
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.white,
            tabs: const [Tab(text: 'Meus Treinos'), Tab(text: 'Estatísticas')],
          ),
          actions: [
            Builder(
              // Drawer Icon
              builder:
                  (context) => IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () => Scaffold.of(context).openEndDrawer(),
                    tooltip:
                        MaterialLocalizations.of(context).openAppDrawerTooltip,
                  ),
            ),
          ],
        ),
        endDrawer: CustomDrawer(
          // Drawer for Athlete
          isAtleta: isAtleta, // true
          userId: userProvider.user?.userData?['id'] ?? 0,
          baseUrl: _baseUrl,
        ),
        body: TabBarView(
          // TabBarView for Athlete
          controller: _tabController,
          children: [
            // --- Tab 1: Meus Treinos (Athlete's Workouts) ---
            SingleChildScrollView(
              // Changed Container to SingleChildScrollView
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Treino do dia ---
                  Text(
                    "Treino(s) do dia",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 160,
                    child: _fichasDoDia.isEmpty
                        ? const Center(
                            child: Text(
                              "Nenhum treino registrado para hoje.",
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _fichasDoDia.length,
                            itemBuilder: (context, index) {
                              final ficha = _fichasDoDia[index];
                              return Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: GestureDetector(
                                  onTap: () async {
                                   final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => DetalheFichaScreen(ficha: ficha))
                                    );
                                    if (result == true) {
                                      _fetchFichasDoDia(); // Recarrega a lista ao voltar se finalizou
                                      _fetchPercentualTreinosConcluidos();
                                      _fetchTempoDeTreinoTotal();
                                      _fetchProgressoMensal();
                                    }
                                  },
                                  child: _buildFichaTreinoCard(
                                    ficha,
                                    cardColor,
                                    textColor,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 24),

                  // --- Eventos da Semana ---
                  Text(
                    "Eventos da Semana",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 160,
                    child:
                        _eventosRegistrados.isEmpty
                            ? const Center(
                              child: Text(
                                "Nenhum evento registrado para esta semana.",
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                            : ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: eventosSemana.length,
                              itemBuilder: (context, index) {
                                final evento = eventosSemana[index];
                                return Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: _buildEventoCard(
                                    evento['nome'],
                                    evento['descricao'],
                                    cardColor,
                                    textColor,
                                    'assets/images/banner_1.jpg',
                                    evento['data'],
                                  ),
                                );
                              },
                            ),
                  ),
                  const SizedBox(height: 24),

                  // --- Resumo da semana ---
                  Card(
                    color: cardColor,
                    elevation: 2,
                    shadowColor: Colors.grey.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Resumo da semana",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // TODO: Fetch dynamic summary data
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildResumoItem("Atividades", "5"),
                              _buildResumoItem("Tempo", "10h 30min"),
                              _buildResumoItem("Distância", "25.0 km"),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: GestureDetector(
                              onTap: () {
                                print("Navegar para gráficos");
                                // Navigate or switch tab index: _tabController.animateTo(1);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Tela de gráficos/estatísticas ainda não implementada.",
                                    ),
                                  ),
                                );
                              },
                              child: const Text(
                                "Ver detalhes >",
                                style: TextStyle(
                                  color: const Color.fromARGB(255, 136, 0, 199),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- Perfil de Nadador / Contact Trainer ---
                  Card(
                    color: cardColor,
                    elevation: 2,
                    shadowColor: Colors.grey.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Perfil de Nadador",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Responda um pequeno questionário para personalizar o seu treino de natação e acelerar os seus resultados! Ainda tem dúvidas? Fale com o seu instrutor.",
                            style: TextStyle(
                              color: textColor.withOpacity(0.9),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "Questionário ainda não implementado.",
                                        ),
                                      ),
                                    );
                                    // TODO: Navigate to Questionnaire Screen
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    elevation: 2,
                                  ),
                                  child: const Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        "Responder",
                                        textAlign: TextAlign.center,
                                      ),
                                      Text(
                                        "Questionário",
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed:
                                      () => _launchWhatsApp(
                                        context,
                                      ), // Athlete contacts trainer
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade600,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    elevation: 2,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        FontAwesomeIcons.whatsapp,
                                        size: 22,
                                      ),
                                      const SizedBox(width: 12),
                                      Flexible(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Text(
                                              line1Name,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontSize: 13,
                                              ),
                                              maxLines: 1,
                                            ),
                                            Text(
                                              line2Name,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontSize: 13,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20), // Space at the bottom
                ],
              ),
            ),

            // --- Tab 2: Estatísticas (Athlete's Stats) ---
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Gráfico de Barras - Estatísticas Semanais
                  Card(
                    color: Colors.white,
                    elevation: 4,
                    shadowColor: Colors.grey.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Estatísticas Semanais - Treinos Concluídos",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 200,
                            child: BarChart(
                              BarChartData(
                                barGroups: _buildBarChartData(
                                  _dadosTreinosSemana,
                                ), // Dados do backend
                                titlesData: FlTitlesData(
                                  leftTitles: SideTitles(showTitles: true),
                                  bottomTitles: SideTitles(
                                    showTitles: true,
                                    getTitles: (double value) {
                                      const days = [
                                        'Seg',
                                        'Ter',
                                        'Qua',
                                        'Qui',
                                        'Sex',
                                        'Sáb',
                                        'Dom',
                                      ];
                                      return days[value.toInt() % days.length];
                                    },
                                  ),
                                ),
                                borderData: FlBorderData(show: false),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Gráfico de Linhas - Progresso Mensal
                  Card(
                    color: Colors.white,
                    elevation: 4,
                    shadowColor: Colors.grey.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Progresso Mensal - Tempo de Treino (horas)",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 200,
                            child: LineChart(
                              LineChartData(
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: _buildLineChartData(
                                      _dadosProgressoMensal,
                                    ), // Dados do backend
                                    isCurved: false,
                                    colors: [const Color.fromARGB(255, 136, 0, 199)],
                                    barWidth: 4,
                                    belowBarData: BarAreaData(show: false),
                                  ),
                                ],
                                titlesData: FlTitlesData(
                                  leftTitles: SideTitles(showTitles: true),
                                  bottomTitles: SideTitles(
                                    showTitles: true,
                                    getTitles: (double value) {
                                      const months = [
                                        'Jan',
                                        'Fev',
                                        'Mar',
                                        'Abr',
                                        'Mai',
                                        'Jun',
                                        'Jul',
                                        'Ago',
                                        'Set',
                                        'Out',
                                        'Nov',
                                        'Dez',
                                      ];
                                      return months[value.toInt() %
                                          months.length];
                                    },
                                  ),
                                ),
                                borderData: FlBorderData(show: false),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- Cards de Percentual de Treinos Completos ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildPercentualCard(
                        "Treinos Concluídos (diário)",
                        "${_percentualTreinosConcluidos.toStringAsFixed(1)}%", // Exibe o percentual com 1 casa decimal
                        Colors.green,
                      ),
                      _buildPercentualCard(
                        "Tempo Total de Treino (diário)",
                        _tempoTotalTreino, // Exibe o tempo total de treino
                        const Color.fromARGB(255, 136, 0, 199),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        )
      );
    } else {
      // #######################################
      // ####### UI FOR TRAINER ################
      // #######################################
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(
            'Painel do Treinador - ${userName.split(' ')[0]}', // Trainer Name
            style: const TextStyle(color: Colors.white),
          ),
          // No TabBar for the trainer dashboard view
          actions: [
            Builder(
              // Drawer Icon
              builder:
                  (context) => IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () => Scaffold.of(context).openEndDrawer(),
                    tooltip:
                        MaterialLocalizations.of(context).openAppDrawerTooltip,
                  ),
            ),
          ],
        ),
        endDrawer: CustomDrawer(
          // Drawer for Trainer
          isAtleta: isAtleta, // false
          userId: userProvider.user?.userData?['id'] ?? 0, // Trainer's ID
          baseUrl: _baseUrl,
        ),
        body: SingleChildScrollView(
          // Main content area for trainer
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Card for Sharing Code
              _buildShareCodeCard(context, cardColor, textColor),
              const SizedBox(height: 20),

              // Card for Athlete Overview
              _buildAthleteOverviewCard(context, cardColor, textColor),
              const SizedBox(height: 20),

              // Card for Workout Management
              _buildWorkoutManagementCard(context, cardColor, textColor),
              const SizedBox(height: 20),

              // You can add more trainer-specific cards here
              // e.g., _buildRecentActivityCard(context, cardColor, textColor),
            ],
          ),
        ),
      );
    }
  }

  // --- Helper Widgets (Common & Athlete Specific) ---

  Widget _buildResumoItem(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ],
    );
  }

  Widget _buildDesafioCard(
    String title,
    String description,
    Color cardColor,
    Color textColor,
  ) {
    return SizedBox(
      width: 200, // Constrain width for horizontal list
      child: Card(
        color: cardColor,
        elevation: 2,
        shadowColor: Colors.grey.withOpacity(0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment:
                MainAxisAlignment
                    .spaceBetween, // Space out title and description
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Flexible(
                // Allow description to take available space and wrap
                child: Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: textColor.withOpacity(0.8),
                    height: 1.3,
                  ),
                  maxLines: 3, // Limit lines
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTreinoCard(
    String title,
    String sport,
    String description,
    Color cardColor,
    Color textColor,
    String imagePath, {
    Widget? bottomWidget, // Novo parâmetro opcional para o botão/status
  }) {
    final imageProvider = AssetImage(imagePath);

    return SizedBox(
      width: 250,
      child: Card(
        color: cardColor,
        elevation: 3,
        shadowColor: Colors.grey.withOpacity(0.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Background Image
            Image(
              image: imageProvider,
              height: 160,
              width: 250,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 160,
                  width: 250,
                  color: Colors.grey.shade300,
                  child: const Center(
                    child: Icon(
                      Icons.image_not_supported,
                      color: Colors.grey,
                      size: 40,
                    ),
                  ),
                );
              },
            ),
            // Gradient Overlay
            Container(
              height: 160,
              width: 250,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.black.withOpacity(0.1),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.4, 1.0],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ),
            // Conteúdo textual e botão organizados em coluna
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Textos no topo
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                blurRadius: 2.0,
                                color: Colors.black54,
                                offset: Offset(1, 1),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          sport,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    // Botão/status na parte de baixo (se houver)
                    if (bottomWidget != null) bottomWidget,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventoCard(
    String title,
    String description,
    Color cardColor,
    Color textColor,
    String imagePath,
    String date,
  ) {
    final imageProvider = AssetImage(
      imagePath,
    ); // Use AssetImage para imagens locais

    return SizedBox(
      width: 250, // Largura do card
      child: Card(
        color: cardColor,
        elevation: 3,
        shadowColor: Colors.grey.withOpacity(0.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        clipBehavior:
            Clip.antiAlias, // Garante que a imagem seja cortada no formato do card
        child: Stack(
          children: [
            // Imagem de fundo
            Image(
              image: imageProvider,
              height: 160,
              width: 250,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                print('Erro ao carregar asset: $imagePath - $error');
                // Placeholder em caso de erro
                return Container(
                  height: 160,
                  width: 250,
                  color: Colors.grey.shade300,
                  child: const Center(
                    child: Icon(
                      Icons.image_not_supported,
                      color: Colors.grey,
                      size: 40,
                    ),
                  ),
                );
              },
            ),
            // Gradiente para melhorar a legibilidade do texto
            Container(
              height: 160,
              width: 250,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.black.withOpacity(0.1),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.4, 1.0],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ),
            // Conteúdo do texto
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          blurRadius: 2.0,
                          color: Colors.black54,
                          offset: Offset(1, 1),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Data: $date",
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Helper Widgets (Trainer Specific) ---

  Widget _buildShareCodeCard(
    BuildContext context,
    Color cardColor,
    Color textColor,
  ) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    _trainerShareCode = userProvider.codigoConvite;
    final String displayCode =
        _trainerShareCode ?? "Carregando.."; // Show placeholder if null
    final bool canShare =
        _trainerShareCode != null && _trainerShareCode!.isNotEmpty;

    return Card(
      color: cardColor,
      elevation: 2,
      shadowColor: Colors.grey.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Meu Código de Treinador",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Compartilhe este código com seus atletas para que eles possam se conectar a você:",
              style: TextStyle(color: textColor.withOpacity(0.9), height: 1.4),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Make code selectable
                SelectableText(
                  displayCode,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    letterSpacing: 1.5,
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text("Compartilhar"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    _shareTrainerCode(context);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAthleteOverviewCard(
    BuildContext context,
    Color cardColor,
    Color textColor,
  ) {
    // TODO: Fetch actual athlete count from API based on _userId (trainer's ID)
    int athleteCount = 0; // Placeholder - fetch this dynamically
    // Example: You might call an API here or get count from a state management solution

    return Card(
      color: cardColor,
      elevation: 2,
      shadowColor: Colors.grey.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Visão Geral dos Atletas",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              // Using Row for better layout control
              children: [
                Text(
                  "Você possui ",
                  style: TextStyle(
                    fontSize: 16,
                    color: textColor.withOpacity(0.9),
                  ),
                ),
                // TODO: Show loading indicator while fetching count?
                Text(
                  "$athleteCount",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
                Text(
                  " atletas ativos.",
                  style: TextStyle(
                    fontSize: 16,
                    color: textColor.withOpacity(0.9),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.people_alt_outlined, size: 20),
                label: const Text(
                  "Ver Meus Atletas",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => AthleteProfileScreen()));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkoutManagementCard(
    BuildContext context,
    Color cardColor,
    Color textColor,
  ) {
    return Card(
      color: cardColor,
      elevation: 2,
      shadowColor: Colors.grey.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add_circle_outline, size: 20),
                label: const Text("Criar Treino"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 12,
                  ),
                ),
                onPressed: () async {
                  // Implement Navigation to Create Workout Screen
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreateWorkoutScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.fitness_center, size: 20),
                label: const Text("Ver Treinos"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 12,
                  ),
                ),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => WorkoutListScreen()));
                },
              ),
            ),
          ],
        ),
      ),
    );
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

  List<BarChartGroupData> _buildBarChartData(List<double> valores) {
    return List.generate(valores.length, (index) {
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            y: valores[index], // Usa os valores fornecidos
            colors: [const Color.fromARGB(255, 136, 0, 199)],
          ),
        ],
      );
    });
  }

  List<FlSpot> _buildLineChartData(List<String> valores) {
  return List.generate(valores.length, (index) {
    final valor = tempoStringParaHorasDecimais(valores[index]);
    final valorFormatado = double.parse(valor.toStringAsFixed(2));
    return FlSpot(index.toDouble(), valorFormatado);
  });
}

  double tempoStringParaHorasDecimais(String tempo) {
    final regex = RegExp(r'(\d+)h\s*(\d+)min');
    final match = regex.firstMatch(tempo);
    if (match != null) {
      final horas = int.parse(match.group(1)!);
      final minutos = int.parse(match.group(2)!);
      return horas + (minutos / 60.0);
    }
    return 0.0;
  }

  Widget _buildPercentualCard(String title, String value, Color color) {
    return Expanded(
      child: Card(
        color: Colors.white,
        elevation: 4,
        shadowColor: Colors.grey.withOpacity(0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFichaCard(Map<String, dynamic> ficha, Color cardColor, Color textColor) {
    final bool iniciada = ficha['status_ficha'] == 2; // 1 = iniciada, 0 = não iniciada, 2 = finalizada (ajuste conforme seu backend)
    final bool finalizada = ficha['status_ficha'] == 3;

    return Card(
      color: cardColor,
      elevation: 3,
      shadowColor: Colors.grey.withOpacity(0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Ficha #${ficha['id']}",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
            ),
            const SizedBox(height: 8),
            Text(
              ficha['descricao'] ?? '',
              style: TextStyle(fontSize: 14, color: textColor.withOpacity(0.8)),
            ),
            const SizedBox(height: 8),
            Text(
              "Categoria: ${ficha['categoria']}",
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            Text(
              "Data: ${ficha['data']}",
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            if (!iniciada && !finalizada)
              ElevatedButton(
                onPressed: () => _iniciarFicha(ficha['id']),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text("Iniciar Ficha", style: TextStyle(color: Colors.white)),
              ),
            if (iniciada && !finalizada)
              ElevatedButton(
                onPressed: () => _finalizarFicha(ficha['id']),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                child: const Text("Finalizar Ficha", style: TextStyle(color: Colors.white)),
              ),
            if (finalizada)
              const Text("Ficha finalizada!", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildFichaTreinoCard(Map<String, dynamic> ficha, Color cardColor, Color textColor) {
    bool iniciada = ficha['status'] == 2;
    bool finalizada = ficha['status'] == 3;
    String categoria = "";

    //switch categoria
    switch (ficha['categoria']) {
      case 1:
        categoria = "Leve";
        break;
      case 2:
       categoria = "Intermediário";
        break;
      case 3:
        categoria = "Avançado";
        break;
      default:
    }

    // Monta a descrição para o card
    final String descricao = 
        "Categoria: $categoria\n${ficha['descricao'] ?? ''}\nData: ${ficha['data']}";

    return Stack(
      children: [
        _buildTreinoCard(
          "Ficha #${ficha['id']}",
          ficha['esporte'] ?? 'Modalidade não definida',
          descricao,
          cardColor,
          textColor,
          'assets/images/academia.jpg', // ou outro asset se desejar
        ),
        // Botão sobreposto no canto inferior direito do card
        Positioned(
          bottom: 12,
          right: 12,
          child: finalizada
              ? ElevatedButton(
                  onPressed: null, // Botão desabilitado
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 3,
                  ),
                  child: const Text(
                    "Finalizada",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                )
              : ElevatedButton(
                  onPressed: () {
                    if (!iniciada) {
                      _iniciarFicha(ficha['id']);
                    } else {
                      _finalizarFicha(ficha['id']);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: !iniciada ? Colors.green : Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 3,
                  ),
                  child: Text(!iniciada ? "Iniciar Ficha" : "Finalizar Ficha"),
                ),
        ),
      ],
    );
  }
}

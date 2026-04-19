import 'package:connect_sports/config.dart';
import 'package:connect_sports/provider/user_provider.dart';
import 'package:connect_sports/screens/custom/drawer.dart';
import 'package:connect_sports/services/http_service.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class AthleteProfileScreen extends StatefulWidget {
  
  @override
  _AthleteProfileScreenState createState() => _AthleteProfileScreenState();
}

class _AthleteProfileScreenState extends State<AthleteProfileScreen> with SingleTickerProviderStateMixin {

  late TabController _tabController;
  DateTime _mesVisualizado = DateTime.now();
  final String _baseUrl = Config.baseURL;

  // Variáveis de estado para armazenar os dados do usuário e o estado de carregamento
  String? _userName;
  int _userId = 0;
  String? _userTrainerPhone;
  String? _userTrainerName;
  bool _isAtleta = true;
  bool _isLoading = true;
  List<Map<String, dynamic>> _atletas = [];
  List<Map<String, dynamic>> _eventosRegistrados = [];
  List<Map<String, dynamic>> _fichasSemana = [];

  //TODO: Retornar as fichas do usuário logado quando ele for atleta
  //List<Map<String, dynamic>> _fichas = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // Gerencia as abas manualmente
    //_loadUserDataDetalhes();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Recarrega os eventos registrados sempre que a tela de perfil for exibida novamente
    _fetchEventosRegistrados();
    _fetchAtletas();
    _fetchFichasSemana();
  }

  @override
  void dispose() {
    _tabController.dispose(); // Libera o TabController ao destruir o widget
    super.dispose();
  }

  void _proximoMes() {
    setState(() {
      _mesVisualizado = DateTime(_mesVisualizado.year, _mesVisualizado.month + 1);
    });
  }

  void _mesAnterior() {
    setState(() {
      _mesVisualizado = DateTime(_mesVisualizado.year, _mesVisualizado.month - 1);
    });
  }

  Future<void> _fetchAtletas() async {
    
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final int? userId = userProvider.user?.userData?['id'];

    try {
      final url = '$_baseUrl/utils/treinador/atletas/$userId';
      final response = await sendRequest(
        context: context,
        method: 'GET',
        url: url,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        var atletas = data.map((atleta) => atleta as Map<String, dynamic>).toList();
        setState(() {
          _atletas = atletas;
        });
      } else {
        print('Erro ao buscar atletas: ${response.statusCode}');
      }
    } catch (e) {
      print('Erro ao buscar atletas: $e');
    }
  }

  Future<void> _fetchEventosRegistrados() async {

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final int? userId = userProvider.user?.userData?['id'];

    try {
      final url = '$_baseUrl/eventos/$userId';
      final response = await sendRequest(
        context: context,
        method: 'GET',
        url: url,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _eventosRegistrados = data.map((evento) {
            return {
              'id': evento['id'],
              'nome': evento['nome_evento'],
              'data': evento['data_evento'], // Certifique-se de que está no formato YYYY-MM-DD
              'descricao': evento['descricao'],
              'isVinculado': (evento['atleta_vinculado'] ?? 0).toString(), // Converte para string
            };
          }).toList();
        });

        setState(() {
          _isLoading = false;
        });
      } else {
        print('Erro ao buscar eventos registrados: ${response.statusCode}');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Erro ao buscar eventos registrados: $e');
      setState(() {
          _isLoading = false;
        });
    }
  }

  Future<void> _fetchFichasSemana() async {
  final userProvider = Provider.of<UserProvider>(context, listen: false);
  final int? userId = userProvider.user?.userData?['id'];

  try {
    final url = '$_baseUrl/fichas/semana/$userId';
    final response = await sendRequest(
      context: context,
      method: 'GET',
      url: url,
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      setState(() {
        _fichasSemana = data.map((ficha) => ficha as Map<String, dynamic>).toList();
      });
    } else {
      print('Erro ao buscar fichas da semana: ${response.statusCode}');
    }
  } catch (e) {
    print('Erro ao buscar fichas da semana: $e');
  }
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
          "Olá, ${userName ?? 'Usuário'}",
          style: const TextStyle(color: Colors.white, fontSize: 20),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController, // Conecta o TabBar ao TabController
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Fichas'),
            Tab(text: 'Agenda'),
          ],
        ),
      ),
      endDrawer: CustomDrawer(
        isAtleta: isAtleta,
        userId: userId,
        baseUrl: _baseUrl,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 200,
                      decoration: const BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage('assets/images/academia.jpg'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const Positioned(
                      bottom: 10,
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.person, size: 50, color: Colors.black),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (isAtleta) ...[
                  if (userTrainerName != null)
                    Text(
                      'Treinador Responsável: $userTrainerName',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    )
                  else
                    const Text(
                      'Treinador Responsável: Não disponível',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController, // Conecta o TabBarView ao TabController
                      children: [
                        _buildFichaAtual(),
                        _buildAgenda(),
                      ],
                    ),
                  )
                ] else ...[
                  const Text(
                    'Meus atletas',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController, // Conecta o TabBarView ao TabController
                      children: [
                        _buildAtletasAtual(),
                        _buildAgenda(),
                      ],
                    ),
                  )
                ],
              ],
            ),
    );
  }

  Widget _buildFichaAtual() {
    if (_fichasSemana.isEmpty) {
      return const Center(
        child: Text(
          'Nenhuma ficha encontrada para esta semana.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _fichasSemana.length,
      itemBuilder: (context, index) {
        var ficha = _fichasSemana[index];
        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          margin: const EdgeInsets.symmetric(vertical: 10),
          color: Theme.of(context).colorScheme.surface.withOpacity(0.97),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  child: const Icon(Icons.fitness_center, color: Colors.blue),
                  radius: 28,
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ficha #${ficha['id']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('Categoria: ${_categoriaToString(ficha['categoria'])}'),
                      Text('Esporte: ${ficha['id_esporte']}'),
                      Text('Data: ${formatarData(ficha['data_ficha'])}'),
                      Text('Status: ${_statusToString(ficha['status_ficha'])}'),
                      if (ficha['descricao'] != null && ficha['descricao'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Text(
                            'Descrição: ${ficha['descricao']}',
                            style: const TextStyle(color: Colors.black87),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Funções auxiliares para exibir categoria e status de forma amigável
  String _categoriaToString(int categoria) {
    switch (categoria) {
      case 1:
        return 'Leve';
      case 2:
        return 'Intermediário';
      case 3:
        return 'Avançado';
      default:
        return 'Desconhecida';
    }
  }

  String _statusToString(int status) {
    switch (status) {
      case 1:
        return 'Ativo';
      case 2:
        return 'Iniciado';
      case 3:
        return 'Finalizado';
      default:
        return 'Desconhecido';
    }
  }

  Widget _buildAtletasAtual(){

    if (_atletas.isEmpty) {
      return const Center(
        child: Text(
          'Nenhum atleta encontrado.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: _atletas.length,
      itemBuilder: (context, index) {
        final atleta = _atletas[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ListTile(
            title: Text(
              atleta['nome'] ?? 'Nome não disponível',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Email: ${atleta['email'] ?? 'Não disponível'}'),
                Text('Telefone: ${atleta['telefone'] ?? 'Não disponível'}'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAgenda() {
    DateTime now = DateTime.now();
    DateTime visualizado = _mesVisualizado;
    int today = now.day;
    int daysInMonth = DateTime(visualizado.year, visualizado.month + 1, 0).day;
    List<String> weekDays = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
    int firstWeekday = DateTime(visualizado.year, visualizado.month, 1).weekday % 7;
    int totalDays = daysInMonth + firstWeekday;

    List<Map<String, dynamic>> eventosDoMes = _eventosRegistrados.where((evento) {
      DateTime dataEvento = DateTime.parse(evento['data']);
      return dataEvento.year == visualizado.year &&
          dataEvento.month == visualizado.month &&
          evento['isVinculado'] == '1';
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: weekDays.map((day) => Text(day, style: const TextStyle(fontWeight: FontWeight.bold))).toList(),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _mesAnterior,
            ),
            Text(
              '${_mesVisualizado.month.toString().padLeft(2, '0')}/${_mesVisualizado.year}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: _proximoMes,
            ),
          ],
        ),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.92, // Ajuste o aspecto para aumentar a altura
            ),
            itemCount: totalDays,
            itemBuilder: (context, index) {
              if (index < firstWeekday) {
                return Container();
              }
              int day = index - firstWeekday + 1;
              bool isToday = visualizado.year == now.year &&
               visualizado.month == now.month &&
               day == today;

              // Filtra os eventos do dia
              List<Map<String, dynamic>> eventosDoDia = eventosDoMes.where((evento) {
                DateTime dataEvento = DateTime.parse(evento['data']);
                return dataEvento.day == day;
              }).toList();

              return GestureDetector(
                onTap: eventosDoDia.isNotEmpty
                    ? () {
                        _showEventosDoDiaPopup(context, eventosDoDia);
                      }
                    : null,
                child: Container(
                  margin: const EdgeInsets.all(4.0), // Espaçamento entre os cards
                  decoration: BoxDecoration(
                    color: isToday ? Colors.blue : Colors.grey[900],
                    borderRadius: BorderRadius.circular(12), // Bordas arredondadas
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2), // Sombra suave
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0), // Reduz o espaçamento interno
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          day.toString(),
                          style: TextStyle(
                            color: isToday ? Colors.white : Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (eventosDoDia.isNotEmpty)
                          Expanded(
                            child: Wrap(
                              spacing: 4, // Espaçamento horizontal entre os ícones
                              runSpacing: 4, // Espaçamento vertical entre os ícones
                              alignment: WrapAlignment.center,
                              children: eventosDoDia.take(3).map((evento) {
                                // Mostra no máximo 3 ícones
                                Color randomColor = Colors.primaries[evento['id'] % Colors.primaries.length];
                                return Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: randomColor,
                                    shape: BoxShape.circle,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        if (eventosDoDia.length > 3)
                          const Icon(
                            Icons.more_horiz,
                            size: 14,
                            color: Colors.white70, // Ícone indicando mais eventos
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showEventosDoDiaPopup(BuildContext context, List<Map<String, dynamic>> eventosDoDia) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Eventos do Dia"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: eventosDoDia.length,
              itemBuilder: (context, index) {
                final evento = eventosDoDia[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.primaries[evento['id'] % Colors.primaries.length],
                  ),
                  title: Text(evento['nome']),
                  subtitle: Text(evento['descricao'] ?? 'Sem descrição'),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Fechar"),
            ),
          ],
        );
      },
    );
  }

  String formatarData(String? dataIso) {
  if (dataIso == null) return '';
  try {
    final data = DateTime.parse(dataIso);
    return DateFormat('dd/MM/yyyy').format(data);
  } catch (e) {
    return dataIso;
  }
}
}

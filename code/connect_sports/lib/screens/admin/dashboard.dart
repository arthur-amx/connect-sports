import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);
  runApp(const PersonalTrainerApp());
}

class PersonalTrainerApp extends StatelessWidget {
  const PersonalTrainerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Personal Trainer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blueGrey),
      home: DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  DashboardScreen({super.key});

  final List<String> alunos = ['Zenilton', 'Kléber', 'Aline'];

  @override
  Widget build(BuildContext context) {
    String dataAtual = DateFormat(
      'EEEE, dd \'de\' MMMM \'de\' yyyy, HH:mm',
      'pt_BR',
    ).format(DateTime.now());
    dataAtual = dataAtual[0].toUpperCase() + dataAtual.substring(1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Olá, Soraia!'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PaginaNotificacoes()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PaginaConfiguracoes()),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 20),
              const SizedBox(width: 8),
              Text(dataAtual, style: const TextStyle(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),

          // Meus alunos
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Meus alunos',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children:
                        alunos.map((aluno) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4.0,
                            ),
                            child: Column(
                              children: [
                                const CircleAvatar(child: Icon(Icons.person)),
                                const SizedBox(height: 4),
                                Text(aluno),
                              ],
                            ),
                          );
                        }).toList(),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TodosAlunosScreen(),
                          ),
                        );
                      },
                      child: const Text('Ver todos os meus alunos >'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Meus treinos
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Meus treinos',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Terça-feira:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '5 min. de aquecimento    (3x10) 300kg leg press 90°',
                  ),
                  const Text(
                    '(3x10) 50kg mesa flexora     30 min. de bicicleta',
                  ),
                  const Text('(3x10) 55kg mesa extensora'),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => OutrosTreinosScreen(),
                          ),
                        );
                      },
                      child: const Text('Verificar outros treinos >'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Relatório semanal
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Relatório semanal',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text('Nesta semana você já treinou por 01:30'),
                  const Text('Para amanhã, Zenilton solicitou uma nova ficha'),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.event),
            label: 'Meus Eventos',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.flag), label: 'Desafios'),
        ],
        onTap: (index) {
          // Lógica de navegação futura
        },
      ),
    );
  }
}

class PaginaNotificacoes extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notificações')),
      body: const Center(child: Text('Aqui ficam as notificações.')),
    );
  }
}

class TodosAlunosScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Todos os Alunos')),
      body: const Center(child: Text('Lista completa de alunos aqui.')),
    );
  }
}

class OutrosTreinosScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Outros Treinos')),
      body: const Center(child: Text('Lista de outros treinos aqui.')),
    );
  }
}

class PaginaConfiguracoes extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (Route<dynamic> route) => false,
            );
          },
          child: const Text('Sair da conta'),
        ),
      ),
    );
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: const Center(child: Text('Login Screen')),
    );
  }
}

import 'dart:async';
import 'package:connect_sports/provider/user_provider.dart';
import 'package:connect_sports/screens/navigation.dart';
import 'package:connect_sports/screens/usuario/cadastro.dart';
import 'package:connect_sports/screens/usuario/login.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // --- Configuração do Carrossel Infinito ---
  late PageController _pageController; // Late initialization
  int _currentPage = 0; // Índice visual (0, 1, 2)
  Timer? _timer;
  static const int _virtualPageCount =
      10000; // Número grande para efeito infinito

  final List<String> carouselImages = [
    'assets/images/banner_1.jpg',
    'assets/images/banner_2.jpg',
    'assets/images/banner_3.jpg',
  ];

  // --- Configuração da Animação ---
  final Duration _autoScrollDuration = const Duration(seconds: 3);
  final Duration _animationDuration = const Duration(milliseconds: 500);
  final Curve _animationCurve = Curves.easeInOut;

  // Novas cores do projeto: usando preto e branco
  final Color primaryColor = Colors.black;
  final Color accentColor = Colors.white;

  @override
void initState() {
  super.initState();
  // Carrossel
  int initialPage = (_virtualPageCount ~/ 2) - ((_virtualPageCount ~/ 2) % carouselImages.length);
  _pageController = PageController(initialPage: initialPage);
  _currentPage = initialPage % carouselImages.length;

  // Iniciar carrossel
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) {
      _startAutoScroll();
      _checkLoginStatus();
    }
  });
}

  Future<void> _checkLoginStatus() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.loadUserFromStorage();

    // Redireciona com base no estado do usuário
    if (userProvider.user != null) {
      Navigator.pushReplacement( // Mantém pushReplacement para quando o usuário já está logado
        context,
        MaterialPageRoute(builder: (context) => const NavigationConnect()),
      );
    } else {
      // Se o usuário não está logado, vai para LoginScreen, mantendo SplashScreen na pilha
      Navigator.push( // ALTERADO DE pushReplacement PARA push
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    }
  }

  void _startAutoScroll() {
    _timer?.cancel();
    _timer = Timer.periodic(_autoScrollDuration, (Timer timer) {
      if (!_pageController.hasClients || !mounted) return;
      int currentControllerPage =
          _pageController.page?.round() ?? _pageController.initialPage;
      int nextPage = currentControllerPage + 1;

      _pageController.animateToPage(
        nextPage,
        duration: _animationDuration,
        curve: _animationCurve,
      );
    });
  }

  // Novo handler para onPageChanged
  void _handlePageChanged(int index) {
    if (mounted) {
      setState(() {
        _currentPage = index % carouselImages.length;
      });
      _startAutoScroll();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildDot({required bool isActive}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 10 : 8,
      height: isActive ? 10 : 8,
      decoration: BoxDecoration(
        color: isActive ? accentColor : Colors.grey.shade300,
        shape: BoxShape.circle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double topPadding = MediaQuery.of(context).padding.top;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    return Scaffold(
      backgroundColor: primaryColor,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Carrossel de imagens
          PageView.builder(
            controller: _pageController,
            itemCount: _virtualPageCount,
            itemBuilder: (context, index) {
              final int actualIndex = index % carouselImages.length;
              return Image.asset(
                carouselImages[actualIndex],
                fit: BoxFit.cover,
                height: double.infinity,
                width: double.infinity,
                gaplessPlayback: true,
              );
            },
            onPageChanged: _handlePageChanged,
          ),

          // Logo posicionada no topo
          Positioned(
            top: topPadding + 30,
            left: 0,
            right: 0,
            child: Center(
              child: Image.asset('assets/images/logo.png', height: 80),
            ),
          ),

          // Gradiente e UI inferior
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    primaryColor.withOpacity(0.5),
                    primaryColor,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.3, 0.8],
                ),
              ),
              child: SafeArea(
                top: false,
                bottom: true,
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 20,
                    right: 20,
                    bottom: 20,
                    top: 10,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Indicadores
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(carouselImages.length, (index) {
                          return _buildDot(isActive: index == _currentPage);
                        }),
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        "Avance em direção às suas metas.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              blurRadius: 4.0,
                              color: Colors.black45,
                              offset: Offset(1.0, 1.0),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 25),

                      // Botão Cadastrar
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CadastroScreen(),
                              ),
                            );
                          },
                          child: Text(
                            "Comece já sua jornada",
                            style: TextStyle(
                              color: primaryColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),

                      // Link Login
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => LoginScreen()),
                          );
                        },
                        child: const Text(
                          "Já tem uma conta? Faça login",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            shadows: [
                              Shadow(
                                blurRadius: 2.0,
                                color: Colors.black38,
                                offset: Offset(1.0, 1.0),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

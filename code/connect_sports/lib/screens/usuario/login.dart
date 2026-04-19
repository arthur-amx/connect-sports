import 'dart:convert'; // Necessário para jsonEncode/jsonDecode
import 'dart:async'; // Necessário para TimeoutException

import 'package:connect_sports/config.dart';
import 'package:connect_sports/provider/user_provider.dart';
import 'package:connect_sports/screens/home/home_screen.dart';
import 'package:connect_sports/screens/navigation.dart';
import 'package:connect_sports/services/http_service.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:connect_sports/screens/usuario/cadastro.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;

  final white = Colors.white;
  final black = Colors.black;

  // Base URL do backend (substitua pelo IP da sua máquina)
  final String _baseUrl = Config.baseURL;

  Future<void> _login() async {
    // Validação inicial do formulário
    if (!_formKey.currentState!.validate()) {
      return; // Não faz nada se o formulário for inválido
    }

    // Inicia o estado de carregamento
    setState(() {
      _isLoading = true;
    });

    String email = _emailController.text;
    String senha = _passwordController.text;

    try {
      // Constrói a URL completa para o endpoint de login
      final url = '$_baseUrl/auth/login';
      print('Tentando fazer login em: $url');

      final response = await sendRequest(
          context: context,
          method: 'POST',
          url: url,
          body: jsonEncode({'email': email, 'senha': senha}),
          // Adiciona um timeout para evitar espera infinita
        ).timeout(const Duration(seconds: 20));

      // Verifica se o widget ainda está montado após a chamada assíncrona
      if (!mounted) return;

      // Decodifica a resposta JSON
      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Login bem-sucedido (Status 200 OK)
        final String? token = responseBody['token'];
        final Map<String, dynamic>? userData = responseBody['usuario'];
        final Map<String, dynamic>? userTrainerData = responseBody['treinador'];

        final String? userId = userData?['id']?.toString();
        try{
          await OneSignal.login(userId!);
        } catch (e) {
          print('Erro ao fazer login no OneSignal: $e');
        }

        if (token != null) {

          Provider.of<UserProvider>(context, listen: false).saveUserData(
            token: token,
            userData: userData ?? {},
            userTrainerData: userTrainerData ?? {},
          );

          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => NavigationConnect()),
          );

        } else {
          // Token não veio na resposta, mesmo com status 200 (inesperado)
          _showErrorPopup('Erro: Token não recebido do servidor.');
          print('Erro de login (Token Nulo): ${response.body}');
        }
      } else {
        // Erro vindo do backend (ex: 401 Não Autorizado, 400 Bad Request, etc.)
        String errorMessage =
            responseBody['message'] ?? 'Erro desconhecido ao fazer login.';
        _showErrorPopup(errorMessage); // Mostra erro específico do backend
        print('Erro de login (${response.statusCode}): ${response.body}');
      }
    } on http.ClientException catch (e) {
      // Erro de conexão (rede, DNS, servidor não encontrado, etc.)
      if (!mounted) return;
      print('Erro de rede/conexão: $e');
      _showErrorPopup(
        'Falha na conexão. Verifique sua rede e se o servidor está online.',
      );
    } on TimeoutException catch (_) {
      // Erro de timeout (servidor demorou muito para responder)
      if (!mounted) return;
      print('Erro: Timeout na requisição de login');
      _showErrorPopup(
        'O servidor demorou muito para responder. Tente novamente.',
      );
    } catch (e) {
      // Outros erros inesperados (ex: erro ao decodificar JSON, etc.)
      if (!mounted) return;
      print('Erro inesperado no login: $e');
      _showErrorPopup('Ocorreu um erro inesperado: ${e.toString()}');
    } finally {
      // Garante que o estado de carregamento seja desativado, mesmo se ocorrer erro
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSuccessPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Login realizado"),
          content: Text("Usuário autenticado com sucesso!"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => NavigationConnect()),
                  // (Route) => false,
                );
              },
              child: Text("OK"),
            ),
          ],
        );
      },
    );
  }

  void _showErrorPopup(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Falha no Login"),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text("OK"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [white, black],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 30, vertical: 20),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              elevation: 10,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/logo_simp.png',
                        width: 80,
                        height: 80,
                      ),
                      SizedBox(height: 10),
                      Text(
                        "Bem-vindo ao \nConnect Sports",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 20),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        // Habilita/desabilita baseado no _isLoading
                        enabled: !_isLoading,
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.email, color: black),
                          labelText: "E-mail",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Digite seu e-mail";
                          }
                          if (!RegExp(
                            r"^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$",
                          ).hasMatch(value)) {
                            return "E-mail inválido";
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 15),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        // Habilita/desabilita baseado no _isLoading
                        enabled: !_isLoading,
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.lock, color: black),
                          labelText: "Senha",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Digite sua senha";
                          }
                          if (value.length < 6) {
                            return "A senha deve ter pelo menos 6 caracteres";
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50, // fix: Altura fixa para evitar pulos na UI
                        child:
                            _isLoading
                                // Mostra indicador de progresso se estiver carregando
                                ? Center(
                                  child: CircularProgressIndicator(
                                    color: black,
                                  ),
                                )
                                // Mostra botão de login se não estiver carregando
                                : ElevatedButton(
                                  onPressed:
                                      _login, // Chama o método _login atualizado
                                  style: ElevatedButton.styleFrom(
                                    padding: EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    backgroundColor: black,
                                  ),
                                  child: Text(
                                    "Entrar",
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                      ),
                      TextButton(
                        // Desabilita botão se estiver carregando
                        onPressed: _isLoading ? null : () {},
                        child: Text(
                          "Esqueceu a senha?",
                          style: TextStyle(
                            color: _isLoading ? Colors.grey : black,
                          ),
                        ),
                      ),
                      TextButton(
                        // Desabilita botão se estiver carregando
                        onPressed:
                            _isLoading
                                ? null
                                : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CadastroScreen(),
                                    ),
                                  );
                                },
                        child: Text(
                          "Não possui login? Cadastre-se",
                          style: TextStyle(
                            color: _isLoading ? Colors.grey : black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

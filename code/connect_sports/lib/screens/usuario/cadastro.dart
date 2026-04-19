import 'dart:async';
import 'dart:convert';
import 'package:connect_sports/config.dart';
import 'package:connect_sports/services/http_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_masked_text2/flutter_masked_text2.dart';
import 'package:http/http.dart' as http;
import 'package:connect_sports/screens/usuario/login.dart';

class CadastroScreen extends StatefulWidget {
  @override
  _CadastroScreenState createState() => _CadastroScreenState();
}

class _CadastroScreenState extends State<CadastroScreen> {
  String? _tipoSelecionado;
  final _formKey = GlobalKey<FormState>();

  // Controllers dos campos
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _cpfController = MaskedTextController(
    mask: "000.000.000-00",
  );
  final TextEditingController _telefoneController = MaskedTextController(
    mask: "(00) 00000-0000",
  );
  final TextEditingController _dataNascimentoController =
      TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  final TextEditingController _confirmarSenhaController =
      TextEditingController();

  bool _isLoading = false;

  // Cores utilizadas
  final white = Colors.white;
  final black = Colors.black;

  // Base URL do backend (substitua pelo IP da sua máquina)
  final String _baseUrl = Config.baseURL;

  // Seleção da data de nascimento
  Future<void> _selecionarData(BuildContext context) async {
    DateTime? dataSelecionada = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (dataSelecionada != null) {
      setState(() {
        _dataNascimentoController.text =
            "${dataSelecionada.day}/${dataSelecionada.month}/${dataSelecionada.year}";
      });
    }
  }

  // Função de cadastro atualizada com chamada HTTP e tratamento de erros
  Future<void> _cadastrar() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_senhaController.text != _confirmarSenhaController.text) {
      _showErrorPopup("As senhas não coincidem.");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    String nome = _nomeController.text;
    String cpf = _cpfController.text;
    String telefone = _telefoneController.text;
    String dataNascimento = _dataNascimentoController.text;
    String email = _emailController.text;
    String senha = _senhaController.text;
    int tipo = _tipoSelecionado == "Atleta" ? 0 : 1; // Valor padrão se não selecionado

    try {
      final url = '$_baseUrl/auth/cadastro';
      final response = await sendRequest(
          context: context,
          method: 'POST',
          url: url,
          body: jsonEncode({
            'nome': nome,
            'cpf': cpf,
            'telefone': telefone,
            'dataNascimento': dataNascimento,
            'tipo_usuario': tipo,
            'email': email,
            'senha': senha,
          }),
        ).timeout(const Duration(seconds: 15));

      if (!mounted) return;
      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 201) {
        // Cadastro bem-sucedido
        _showSuccessPopup(
          "Cadastro realizado com sucesso! Você já pode fazer login.",
        );
        //redirecionar para a tela de login
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LoginScreen(),
          ),
        );
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

  // Popup de sucesso
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

  // Widgets auxiliares para construir os campos do formulário
  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool isEmail = false,
    bool isPassword = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
        obscureText: isPassword,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Color.fromARGB(255, 92, 92, 92)),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: black, width: 2.0),
            borderRadius: BorderRadius.circular(10),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: Color.fromARGB(255, 92, 92, 92),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) return "Preencha o campo";
          if (isEmail &&
              !RegExp(
                r"^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$",
              ).hasMatch(value))
            return "E-mail inválido";
          if (isPassword && value.length < 6)
            return "A senha deve ter pelo menos 6 caracteres";
          return null;
        },
      ),
    );
  }

  Widget _buildSelectionField(List<String> items) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: _tipoSelecionado,
        items: items.map((String tipo) {
          return DropdownMenuItem<String>(
            value: tipo,
            child: Text(tipo),
          );
        }).toList(),
        decoration: InputDecoration(
          labelText: "Tipo de Usuário",
          labelStyle: TextStyle(color: Color.fromARGB(255, 92, 92, 92)),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: black, width: 2.0),
            borderRadius: BorderRadius.circular(10),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: Color.fromARGB(255, 92, 92, 92),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onChanged: (String? newValue) {
          setState(() {
            _tipoSelecionado = newValue;
          });
        },
        validator:
            (value) => value == null ? "Selecione o tipo de usuário" : null,
      ),
    );
  }

  Widget _buildDateField(String label, TextEditingController controller) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Color.fromARGB(255, 92, 92, 92)),
          suffixIcon: IconButton(
            icon: Icon(Icons.calendar_today, color: black),
            onPressed: () => _selecionarData(context),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: black, width: 2.0),
            borderRadius: BorderRadius.circular(10),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: Color.fromARGB(255, 92, 92, 92),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        validator:
            (value) => value!.isEmpty ? "Selecione a data de nascimento" : null,
      ),
    );
  }

  Widget _buildButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          backgroundColor: black,
        ),
        child: Text(text, style: TextStyle(fontSize: 18, color: Colors.white)),
      ),
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
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 20),
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 10,
                    color: Colors.white.withOpacity(0.95),
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_add, size: 80, color: black),
                            Text(
                              "Criar Conta",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            SizedBox(height: 10),
                            _buildTextField("Nome Completo", _nomeController),
                            _buildTextField("CPF", _cpfController),
                            _buildTextField("Telefone", _telefoneController),
                            _buildDateField(
                              "Data de Nascimento",
                              _dataNascimentoController,
                            ),
                            _buildTextField(
                              "E-mail",
                              _emailController,
                              isEmail: true,
                            ),
                            _buildSelectionField([
                              "Atleta",
                              "Treinador",
                            ]),
                            _buildTextField(
                              "Senha",
                              _senhaController,
                              isPassword: true,
                            ),
                            _buildTextField(
                              "Confirmar Senha",
                              _confirmarSenhaController,
                              isPassword: true,
                            ),
                            SizedBox(height: 20),
                            _isLoading
                                ? Center(
                                  child: CircularProgressIndicator(
                                    color: black,
                                  ),
                                )
                                : _buildButton("Cadastrar", _cadastrar),
                            SizedBox(height: 10),
                            TextButton(
                              onPressed:
                                  _isLoading
                                      ? null
                                      : () => Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => LoginScreen(),
                                        ),
                                      ),
                              child: Text(
                                "Já tem uma conta? Faça login",
                                style: TextStyle(
                                  color: black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

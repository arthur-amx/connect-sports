import 'package:connect_sports/config.dart';
import 'package:connect_sports/services/http_service.dart';
import 'package:flutter/material.dart';

class DetalheFichaScreen extends StatefulWidget {
  final Map<String, dynamic> ficha;

  const DetalheFichaScreen({Key? key, required this.ficha}) : super(key: key);

  @override
  _DetalheFichaScreenState createState() => _DetalheFichaScreenState();
}

class _DetalheFichaScreenState extends State<DetalheFichaScreen> {
  final String _baseUrl = Config.baseURL;

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
      } else {
        _showErrorPopup("Erro ao finalizar ficha: ${response.statusCode}");
      }
    } catch (e) {
      _showErrorPopup("Erro ao finalizar ficha: $e");
    }
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
    if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    final bool iniciada = widget.ficha['status'] == 2;
    final bool finalizada = widget.ficha['status'] == 3;
    String categoria = "";
    switch (widget.ficha['categoria']) {
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

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Fundo com imagem
            Positioned.fill(
              child: Image.asset(
                widget.ficha['foto'],
                fit: BoxFit.cover,
              ),
            ),
            // Overlay escuro para melhor contraste
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.45),
              ),
            ),
            // Card branco translúcido com informações
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.72,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.92),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(36),
                    topRight: Radius.circular(36),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 12,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 60,
                        height: 6,
                        margin: const EdgeInsets.only(bottom: 18),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      Text(
                        "Ficha #${widget.ficha['id']}",
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          letterSpacing: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 18),
                      Card(
                        color: Colors.white.withOpacity(0.85),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.sports_gymnastics, color: Colors.blueAccent),
                                  const SizedBox(width: 8),
                                  Text(
                                    widget.ficha['esporte'] ?? 'Modalidade não definida',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.category, color: Colors.deepPurple),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Categoria: $categoria",
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.calendar_today, color: Colors.teal),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Data: ${widget.ficha['data']}",
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: Colors.black45,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100]?.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.description, color: Colors.orange),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                widget.ficha['descricao'] ?? '',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (finalizada)
                        ElevatedButton.icon(
                          onPressed: null,
                          icon: const Icon(Icons.check_circle, color: Colors.white),
                          label: const Text("Finalizada"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        )
                      else
                        ElevatedButton.icon(
                          onPressed: () async {
                            if (!iniciada) {
                              await _iniciarFicha(widget.ficha['id']);
                            } else {
                              await _finalizarFicha(widget.ficha['id']);
                              if (mounted) {
                                Navigator.pop(context, true);
                              }
                            } 
                          },
                          icon: Icon(!iniciada ? Icons.play_arrow : Icons.flag),
                          label: Text(!iniciada ? "Iniciar Ficha" : "Finalizar Ficha"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: !iniciada ? Colors.green : Colors.blue,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            // Botão de voltar
            Padding(
              padding: const EdgeInsets.only(top: 32, left: 24),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
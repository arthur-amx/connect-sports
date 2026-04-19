import 'package:connect_sports/config.dart';
import 'package:connect_sports/screens/feedback/feedback_input_screen.dart'; // Import input screen
import 'package:flutter/material.dart';

// URL base fixa para API
const String kBaseUrl = Config.baseURL;

class FeedbackScreen extends StatelessWidget {
  final int userId; // Athlete's ID

  const FeedbackScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  // Constants for feedback types (match backend/database)
  static const int feedbackTypeComentario = 1;
  static const int feedbackTypeSolicitarAjuste = 2;

  // Helper to navigate to the input screen
  void _navigateToInput(BuildContext context, String title, String hint, int type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FeedbackInputScreen(
          userId: userId,
          feedbackType: type,
          pageTitle: title,
          hintText: hint,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deixe seu Feedback'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Selecione o tipo de feedback:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildFeedbackOptionCard(
                  context,
                  title: 'Comentário',
                  icon: Icons.comment_outlined, // Or match wireframe more closely
                  onTap: () => _navigateToInput(
                    context,
                    'Comentário',
                    'Tem algo mais a acrescentar? Compartilhe suas observações...', // Hint text
                    feedbackTypeComentario,
                  ),
                ),
                _buildFeedbackOptionCard(
                  context,
                  title: 'Solicitar Ajuste',
                  icon: Icons.edit_note_outlined, // Or match wireframe more closely
                  onTap: () => _navigateToInput(
                    context,
                    'Solicitar Ajuste',
                    'Precisa de alguma modificação no treino/dieta? Diga quais ajustes são necessários...', // Hint text
                    feedbackTypeSolicitarAjuste,
                  ),
                ),
              ],
            ),
            // Add more instructions or info if needed
          ],
        ),
      ),
    );
  }

  // Helper widget for the option cards
  Widget _buildFeedbackOptionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Expanded( // Use Expanded so cards share space
      child: Card(
        elevation: 3,
        clipBehavior: Clip.antiAlias, // Ensures ink splash stays within rounded corners
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell( // Make the card tappable
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 25.0, horizontal: 15.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 40, color: Theme.of(context).primaryColor), // Use theme color
                const SizedBox(height: 15),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

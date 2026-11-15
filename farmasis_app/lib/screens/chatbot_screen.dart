import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../widgets/metallic_widgets.dart';

class ChatbotScreen extends StatefulWidget {
  final UserModel user;

  const ChatbotScreen({super.key, required this.user});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  late final String _chatId;
  bool _sending = false;

  final List<Map<String, String>> _messages = [];

  @override
  void initState() {
    super.initState();
    _chatId =
        'mobile-${widget.user.username}-${DateTime.now().millisecondsSinceEpoch}';
    final cleanRole = widget.user.rol.replaceAll('ROLE_', '');
    _messages.add({
      'sender': 'ai',
      'text':
          '¡Hola ${widget.user.nombre.isNotEmpty ? widget.user.nombre : widget.user.username}! Soy el Asistente Farmacéutico IA de FarmaSIS (conectado a tu inventario real en MongoDB con permisos de $cleanRole). ¿En qué te ayudo hoy?',
    });
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviarMensaje([String? preset]) async {
    final text = (preset ?? _msgCtrl.text).trim();
    if (text.isEmpty || _sending) return;
    if (preset == null) _msgCtrl.clear();

    setState(() {
      _messages.add({'sender': 'user', 'text': text});
      _sending = true;
    });
    _scrollToBottom();

    try {
      final reply = await ApiService.askChatbot(
        chatId: _chatId,
        message: text,
        rol: widget.user.rol,
      );
      if (!mounted) return;
      setState(() {
        _messages.add({'sender': 'ai', 'text': reply});
        _sending = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add({
          'sender': 'ai',
          'text': '⚠️ No pude conectar con el motor IA en este momento.'
        });
        _sending = false;
      });
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _suggestionChip('¿Qué medicamentos tienen stock bajo?'),
                const SizedBox(width: 6),
                _suggestionChip('Resumen de ventas de hoy'),
                const SizedBox(width: 6),
                _suggestionChip('¿Qué analgésicos hay disponibles?'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              controller: _scrollCtrl,
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: _messages.length + (_sending ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, idx) {
                if (idx == _messages.length) {
                  return const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: FarmasisPalette.emeraldNeon,
                        ),
                      ),
                    ),
                  );
                }
                final m = _messages[idx];
                final isUser = m['sender'] == 'user';
                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 310),
                    child: MetallicGlassCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 13, vertical: 10),
                      isHighlighted: isUser,
                      child: Text(
                        m['text'] ?? '',
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.38,
                          color: FarmasisPalette.textSilverBright,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          MetallicGlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: TextField(
                      controller: _msgCtrl,
                      onSubmitted: (_) => _enviarMensaje(),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: FarmasisPalette.textSilverBright,
                      ),
                      decoration: InputDecoration(
                        hintText:
                            'Pregunta sobre stock, precios o ventas...',
                        hintStyle: const TextStyle(
                          fontSize: 11.5,
                          color: FarmasisPalette.textMuted,
                        ),
                        filled: true,
                        fillColor: FarmasisPalette.inputSurface,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(
                              color: FarmasisPalette.borderChromeSubtle),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(
                              color: FarmasisPalette.borderChromeSubtle),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _sending ? null : () => _enviarMensaje(),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF14B8A6), Color(0xFF065F46)],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF5EEAD4).withValues(alpha: 0.7),
                      ),
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      size: 17,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _suggestionChip(String text) {
    return GestureDetector(
      onTap: () => _enviarMensaje(text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: FarmasisPalette.inputSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: FarmasisPalette.borderChromeBright.withValues(alpha: 0.45),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: FarmasisPalette.textSilverBright,
          ),
        ),
      ),
    );
  }
}

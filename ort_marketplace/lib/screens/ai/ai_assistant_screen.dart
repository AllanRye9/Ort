import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_service.dart';

class _Message {
  const _Message({required this.role, required this.text});
  final String role; // 'user' or 'model'
  final String text;
}

class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_Message> _messages = [];
  bool _sending = false;

  static const _welcomeText =
      'Hello! I\'m ORT AI, your intelligent assistant for the Ort marketplace. '
      'I can help you with:\n'
      '• Finding the right products, properties or services\n'
      '• Understanding pricing and orders\n'
      '• Navigating listings and filters\n'
      '• General marketplace questions\n\n'
      'How can I assist you today?';

  static const _suggestedPrompts = [
    'How do I list a product?',
    'How do I contact a seller?',
    'What is a listing code?',
    'How do I switch to international view?',
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(const _Message(role: 'model', text: _welcomeText));
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _messages.add(_Message(role: 'user', text: text));
      _inputCtrl.clear();
      _sending = true;
    });
    _scrollToBottom();

    try {
      final history = _messages
          .map((m) => {'role': m.role, 'text': m.text})
          .toList();
      final reply =
          await ref.read(apiServiceProvider).aiChat(history);
      if (mounted) {
        setState(() => _messages.add(_Message(role: 'model', text: reply)));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _messages.add(_Message(
              role: 'model',
              text:
                  'Sorry, I encountered an error. Please try again or contact support.',
            )));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: cs.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ORT AI',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('Intelligent Assistant',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () {
              setState(() {
                _messages.clear();
                _messages.add(
                    const _Message(role: 'model', text: _welcomeText));
              });
            },
            tooltip: 'Clear conversation',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                final msg = _messages[i];
                return _MessageBubble(message: msg);
              },
            ),
          ),
          // Suggested prompts – shown only while no user message has been sent yet.
          if (!_sending && _messages.length == 1)
            _SuggestedPrompts(
              prompts: _suggestedPrompts,
              onSelected: (text) {
                _inputCtrl.text = text;
                _send();
              },
            ),
          if (_sending)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('ORT AI is thinking…',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          _InputBar(
            controller: _inputCtrl,
            onSend: _send,
            enabled: !_sending,
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _Message message;

  @override
  Widget build(BuildContext context) {
    final isMe = message.role == 'user';
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: cs.primary,
              child: const Icon(Icons.auto_awesome,
                  color: Colors.white, size: 14),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? cs.primary : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
              child: SelectableText(
                message.text,
                style: TextStyle(
                  color: isMe ? cs.onPrimary : cs.onSurface,
                  height: 1.45,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _SuggestedPrompts extends StatelessWidget {
  const _SuggestedPrompts({
    required this.prompts,
    required this.onSelected,
  });

  final List<String> prompts;
  final void Function(String) onSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: prompts
              .map(
                (p) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(p, style: const TextStyle(fontSize: 12)),
                    backgroundColor: cs.primaryContainer,
                    labelStyle: TextStyle(color: cs.onPrimaryContainer),
                    side: BorderSide.none,
                    onPressed: () => onSelected(p),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.enabled,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                decoration: InputDecoration(
                  hintText: 'Ask ORT AI anything…',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                maxLines: 4,
                minLines: 1,
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton.small(
              onPressed: enabled ? onSend : null,
              backgroundColor: enabled ? cs.primary : cs.surfaceContainerHighest,
              elevation: 0,
              child: Icon(
                Icons.send_rounded,
                color: enabled ? cs.onPrimary : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

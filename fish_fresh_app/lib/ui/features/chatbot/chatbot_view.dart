import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/repositories/app_provider.dart';
import '../../core/theme.dart';

class ChatbotView extends StatefulWidget {
  final String? initialQuery;
  const ChatbotView({super.key, this.initialQuery});

  @override
  State<ChatbotView> createState() => _ChatbotViewState();
}

class _ChatbotViewState extends State<ChatbotView> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<String> _promptSuggestions = [
    "When is the seasonal fishing ban in Pakistan?",
    "Best recipe for Lahori Fried Rohu?",
    "How to properly freeze whole fish?",
    "What are the signs of spoiled fish?"
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<AppStateProvider>().sendChat(widget.initialQuery!);
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateProvider>();
    final messages = state.chatMessages;

    _scrollToBottom();

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Fishery Assistant'),
      ),
      body: Column(
        children: [
          // Suggestions bar
          Container(
            height: 44,
            margin: const EdgeInsets.only(top: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _promptSuggestions.length,
              itemBuilder: (context, idx) {
                final p = _promptSuggestions[idx];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(p, style: const TextStyle(fontSize: 11)),
                    backgroundColor: Colors.white,
                    side: BorderSide(color: AppTheme.primaryTeal.withValues(alpha: 0.3)),
                    onPressed: () => state.sendChat(p),
                  ),
                );
              },
            ),
          ),

          // Message stream
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, idx) {
                final msg = messages[idx];
                return Align(
                  alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
                    decoration: BoxDecoration(
                      color: msg.isUser ? AppTheme.primaryTeal : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: Text(
                      msg.text,
                      style: TextStyle(
                        color: msg.isUser ? Colors.white : Colors.black87,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          if (state.isChatLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),

          // Input field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                )
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: 'Ask about fishing bans, recipes, storage...',
                      border: InputBorder.none,
                      hintStyle: TextStyle(fontSize: 13),
                    ),
                    onSubmitted: (val) {
                      state.sendChat(val);
                      _textController.clear();
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: AppTheme.primaryTeal),
                  onPressed: () {
                    state.sendChat(_textController.text);
                    _textController.clear();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

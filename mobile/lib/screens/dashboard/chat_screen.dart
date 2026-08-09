import 'dart:async';

import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../services/api_service.dart';
import '../../../utils/coach_thread_utils.dart';
import 'widgets/chat_message_bubble.dart';
import 'widgets/coach_home/coach_dashboard_theme.dart';

class ChatScreen extends StatefulWidget {
  final String assignmentId;
  final String coachName;
  final User currentUser;

  const ChatScreen({
    super.key,
    required this.assignmentId,
    required this.coachName,
    required this.currentUser,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  bool _isLoading = true;
  List<dynamic> _messages = [];
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    // Poll for new messages every 10 seconds (simplistic real-time substitute)
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchMessages(silent: true));
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchMessages({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final msgs = await _apiService.getChatMessages(widget.assignmentId);
      if (mounted) {
        setState(() {
          _messages = msgs;
        });
        if (!silent) _scrollToBottom();
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    
    _msgController.clear();
    // Optimistic UI update
    setState(() {
      _messages.add({
        'sender': widget.currentUser.id,
        'body': text,
        'createdAt': DateTime.now().toIso8601String(),
      });
    });
    _scrollToBottom();

    try {
      await _apiService.sendChatMessage(widget.assignmentId, text);
      _fetchMessages(silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: CoachDashboardTheme.homeBackground(isDark),
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: CoachDashboardTheme.primary.withOpacity(0.2),
              child: Text(widget.coachName.isNotEmpty ? widget.coachName[0].toUpperCase() : 'C', style: const TextStyle(color: CoachDashboardTheme.primary, fontSize: 14)),
            ),
            const SizedBox(width: 10),
            Text(widget.coachName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        backgroundColor: CoachDashboardTheme.homeBackground(isDark),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: CoachDashboardTheme.dashboardLeading(context),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: CoachDashboardTheme.primary))
                : _messages.isEmpty
                    ? Center(child: Text('No messages yet. Say hi!', style: TextStyle(color: Colors.grey[500])))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (ctx, i) {
                          final m = Map<String, dynamic>.from(_messages[i] as Map);
                          final messageIsMe = CoachThreadUtils.isFromCurrentUser(
                            m,
                            widget.currentUser.id,
                          );

                          return ChatMessageBubble(
                            message: m,
                            isMe: messageIsMe,
                            isDark: isDark,
                            apiService: _apiService,
                            onChanged: () => _fetchMessages(silent: true),
                          );
                        },
                      ),
          ),
          _buildMessageInput(isDark),
        ],
      ),
    );
  }

  Widget _buildMessageInput(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181B24) : Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _msgController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F0F1A) : Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: CoachDashboardTheme.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

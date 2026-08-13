import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../services/api_service.dart';
import '../../../utils/async_load.dart';
import '../../../utils/coach_thread_utils.dart';
import '../../../widgets/scrollable_body.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/coach_home/coach_dashboard_theme.dart';

class CoachChatTab extends StatefulWidget {
  final VoidCallback? onUnreadChanged;

  const CoachChatTab({super.key, this.onUnreadChanged});

  @override
  State<CoachChatTab> createState() => _CoachChatTabState();
}

class _CoachChatTabState extends State<CoachChatTab> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _threads = [];
  String _errorMessage = '';
  User? _coachUser;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final showFullLoader = _threads.isEmpty && _errorMessage.isEmpty;
    if (mounted && showFullLoader) setState(() => _isLoading = true);
    try {
      final results = await waitIsolatedTimed<Object?>([
        _apiService.getChatThreads(),
        _apiService.getMe(),
      ], fallback: null, timeout: const Duration(seconds: 20));
      if (mounted) {
        setState(() {
          _threads = results[0] is List ? List<dynamic>.from(results[0] as List) : <dynamic>[];
          _coachUser = results[1] is User ? results[1] as User : _coachUser;
          if (results.every((r) => r == null)) {
            _errorMessage = 'Unable to load data';
          } else {
            _errorMessage = '';
          }
        });
        widget.onUnreadChanged?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = ApiService.friendlyError(e);
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openThread(Map<String, dynamic> thread) {
    final threadId = CoachThreadUtils.threadId(thread);
    final clientName = CoachThreadUtils.clientName(thread);
    if (threadId.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _ChatThreadScreen(
          threadId: threadId,
          clientName: clientName,
          apiService: _apiService,
          coachUser: _coachUser,
        ),
      ),
    ).then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_errorMessage.isNotEmpty) {
      return ScrollableCenter(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorMessage, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
          ],
        ),
      );
    }

    return CoachPage(
      title: 'Messages',
      actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadData)],
      body: _threads.isEmpty
          ? CoachDashboardTheme.emptyState(
              icon: Icons.chat_bubble_outline_rounded,
              message: 'No active chat threads.',
              isDark: isDark,
            )
          : ListView.builder(
              physics: dashboardScrollPhysics,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: _threads.length,
              itemBuilder: (context, index) {
                final thread = Map<String, dynamic>.from(_threads[index] as Map);
                final clientName = CoachThreadUtils.clientName(thread);
                final lastMessage = CoachThreadUtils.lastMessagePreview(thread);
                final unread = CoachThreadUtils.unreadCount(thread);
                final initial = clientName.isNotEmpty ? clientName[0].toUpperCase() : 'C';

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: CoachDashboardTheme.cardDecoration(isDark).copyWith(
                    border: unread > 0
                        ? Border.all(color: CoachDashboardTheme.warning.withValues(alpha: 0.4))
                        : null,
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    leading: CoachDashboardTheme.avatarBox(initial: initial, color: CoachDashboardTheme.accent),
                    title: Text(
                      clientName,
                      style: TextStyle(
                        fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w600,
                        color: isDark ? Colors.white : CoachDashboardTheme.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.normal,
                        color: unread > 0
                            ? CoachDashboardTheme.warning
                            : (isDark ? Colors.white54 : CoachDashboardTheme.textSecondary),
                      ),
                    ),
                    trailing: unread > 0
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: CoachDashboardTheme.warning,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$unread',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          )
                        : const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: () => _openThread(thread),
                  ),
                );
              },
            ),
    );
  }
}

class _ChatThreadScreen extends StatefulWidget {
  final String threadId;
  final String clientName;
  final ApiService apiService;
  final User? coachUser;

  const _ChatThreadScreen({
    required this.threadId,
    required this.clientName,
    required this.apiService,
    required this.coachUser,
  });

  @override
  State<_ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<_ChatThreadScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  bool _isLoading = true;
  bool _isSending = false;
  List<dynamic> _messages = [];

  @override
  void initState() {
    super.initState();
    _fetchMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchMessages() async {
    try {
      final thread = await widget.apiService.getChatMessages(widget.threadId);
      if (mounted) {
        setState(() {
          _messages = thread;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load messages: ${ApiService.friendlyError(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);

    try {
      final msg = await widget.apiService.sendChatMessage(widget.threadId, text);
      if (mounted) {
        setState(() {
          _messages.add(msg);
          _messageController.clear();
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: ${ApiService.friendlyError(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final coachId = widget.coachUser?.id ?? '';

    return CoachPage(
      title: widget.clientName,
      body: Column(
              children: [
                Expanded(
                  child: _messages.isEmpty
                      ? const ScrollableCenter(child: Text('Say hi to your client!'))
                      : ListView.builder(
                          controller: _scrollController,
                          physics: dashboardScrollPhysics,
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = Map<String, dynamic>.from(_messages[index] as Map);
                            final isMe = CoachThreadUtils.isCoachMessage(msg, coachId);

                            return ChatMessageBubble(
                              message: msg,
                              isMe: isMe,
                              isDark: isDark,
                              apiService: widget.apiService,
                              onChanged: _fetchMessages,
                            );
                          },
                        ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        offset: const Offset(0, -2),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: InputDecoration(
                              hintText: 'Type a message...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            ),
                            textCapitalization: TextCapitalization.sentences,
                            maxLines: null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          backgroundColor: const Color(0xFF6C63FF),
                          child: _isSending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: const SizedBox.shrink(),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                                  onPressed: _sendMessage,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

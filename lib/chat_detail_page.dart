import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatDetailPage extends StatefulWidget {
  final int chatId;
  final int currentProfileId;
  final String otherName;
  final String? otherAvatarUrl;

  const ChatDetailPage({
    super.key,
    required this.chatId,
    required this.currentProfileId,
    required this.otherName,
    this.otherAvatarUrl,
  });

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final _supabase = Supabase.instance.client;
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribeToMessages();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final data = await _supabase
          .from('message')
          .select()
          .eq('chat_id', widget.chatId)
          .order('sent_at', ascending: true);
      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _subscribeToMessages() {
    _channel = _supabase
        .channel('chat_${widget.chatId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'message',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_id',
            value: widget.chatId,
          ),
          callback: (payload) {
            final newMessage = payload.newRecord;
            if (mounted) {
              setState(() => _messages.add(newMessage));
              _scrollToBottom();
            }
          },
        )
        .subscribe();
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
    final content = _textController.text.trim();
    if (content.isEmpty || _sending) return;

    setState(() => _sending = true);
    _textController.clear();

    try {
      await _supabase.from('message').insert({
        'chat_id': widget.chatId,
        'sender_id': widget.currentProfileId,
        'content': content,
      });

      // Update last_message_at on the chat
      await _supabase
          .from('chat')
          .update({'last_message_at': DateTime.now().toIso8601String()})
          .eq('chat_id', widget.chatId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EFEF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E6A68),
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFB2DFDB),
              backgroundImage: (widget.otherAvatarUrl?.isNotEmpty == true)
                  ? NetworkImage(widget.otherAvatarUrl!)
                  : null,
              child: (widget.otherAvatarUrl?.isNotEmpty != true)
                  ? Text(
                      widget.otherName.isNotEmpty
                          ? widget.otherName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Color(0xFF1E6A68),
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Text(
              widget.otherName,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1E6A68)),
                  )
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 60,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Start the conversation!',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMe =
                              (msg['sender_id'] as int?) ==
                              widget.currentProfileId;
                          return _MessageBubble(
                            content: msg['content'] as String? ?? '',
                            isMe: isMe,
                            sentAt: msg['sent_at'] as String?,
                          );
                        },
                      ),
          ),

          // Input bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3EFEF),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _textController,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Write a message…',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1E6A68),
                        shape: BoxShape.circle,
                      ),
                      child: _sending
                          ? const Padding(
                              padding: EdgeInsets.all(10),
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
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

class _MessageBubble extends StatelessWidget {
  final String content;
  final bool isMe;
  final String? sentAt;

  const _MessageBubble({
    required this.content,
    required this.isMe,
    this.sentAt,
  });

  String _formatTime(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF1E6A68) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              content,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(sentAt),
              style: TextStyle(
                fontSize: 11,
                color: isMe
                    ? Colors.white.withValues(alpha: 0.7)
                    : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

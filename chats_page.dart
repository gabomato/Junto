import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_detail_page.dart';

class ChatsPage extends StatefulWidget {
  const ChatsPage({super.key});

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
  final _supabase = Supabase.instance.client;

  bool _loading = true;
  String? _error;
  int? _currentProfileId;
  List<Map<String, dynamic>> _chats = [];

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1. Get the current user's profile_id
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) {
        setState(() {
          _error = 'Not logged in.';
          _loading = false;
        });
        return;
      }

      final profileResp = await _supabase
          .from('profile')
          .select('profile_id')
          .eq('auth_user_id', authUser.id)
          .maybeSingle();
      if (profileResp == null) {
        setState(() {
          _error = 'Profile not found for current user.';
          _loading = false;
        });
        return;
      }
      final myProfileId = profileResp['profile_id'] as int;
      _currentProfileId = myProfileId;

      // 2. Load all matches involving the current user, with the chat and
      //    the other person's profile info.
      final matchRows = await _supabase
          .from('match')
          .select('''
            match_id,
            matched_at,
            profile_a:profile_a_id ( profile_id, full_name, username, avatar_url ),
            profile_b:profile_b_id ( profile_id, full_name, username, avatar_url ),
            chat ( chat_id, last_message_at )
          ''')
          .or('profile_a_id.eq.$myProfileId,profile_b_id.eq.$myProfileId')
          .order('matched_at', ascending: false);

      // 3. Build a flat list with the "other" person's info and last message
      final List<Map<String, dynamic>> chatList = [];
      for (final row in matchRows as List) {
        final chatData = row['chat'];
        if (chatData == null) continue;

        final chat = chatData is List
            ? (chatData.isNotEmpty ? chatData.first : null)
            : chatData;
        if (chat == null) continue;

        final profileA = row['profile_a'] as Map<String, dynamic>;
        final profileB = row['profile_b'] as Map<String, dynamic>;

        final other = (profileA['profile_id'] as int) == myProfileId
            ? profileB
            : profileA;

        final chatId = chat['chat_id'] as int;

        // Fetch the most recent message in this chat, if any.
        String lastMessagePreview = '';
        try {
          final lastMsgRow = await _supabase
              .from('message')
              .select('content, sender_id')
              .eq('chat_id', chatId)
              .order('sent_at', ascending: false)
              .limit(1)
              .maybeSingle();

          if (lastMsgRow != null) {
            final senderId = lastMsgRow['sender_id'] as int?;
            final content = (lastMsgRow['content'] ?? '').toString();
            final prefix = senderId == myProfileId ? 'You: ' : '';
            lastMessagePreview = '$prefix$content';
          }
        } catch (e) {
          debugPrint('Failed to load last message for chat $chatId: $e');
        }

        chatList.add({
          'chat_id': chatId,
          'last_message_at': chat['last_message_at'],
          'last_message_preview': lastMessagePreview,
          'other_profile_id': other['profile_id'],
          'other_name': (other['full_name'] ?? other['username'] ?? 'Unknown')
              .toString(),
          'other_avatar': (other['avatar_url'] ?? '').toString(),
        });
      }

      // Sort by last message (most recent first)
      chatList.sort((a, b) {
        final aTime = a['last_message_at'] as String? ?? '';
        final bTime = b['last_message_at'] as String? ?? '';
        return bTime.compareTo(aTime);
      });

      setState(() {
        _chats = chatList;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load chats: $e';
        _loading = false;
      });
    }
  }

  String _formatTime(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inDays == 0) {
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } else if (diff.inDays == 1) {
        return 'Yesterday';
      } else if (diff.inDays < 7) {
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return days[dt.weekday - 1];
      } else {
        return '${dt.day}.${dt.month}.';
      }
    } catch (_) {
      return '';
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
        title: const Text(
          'Messages',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadChats),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1E6A68)),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E6A68),
                  foregroundColor: Colors.white,
                ),
                onPressed: _loadChats,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_chats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 72,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No matches yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'When you both like each other,\na chat will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF1E6A68),
      onRefresh: _loadChats,
      child: ListView.separated(
        itemCount: _chats.length,
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 80),
        itemBuilder: (context, index) {
          final chat = _chats[index];
          final name = chat['other_name'] as String;
          final avatarUrl = chat['other_avatar'] as String;
          final timeStr = _formatTime(chat['last_message_at'] as String?);
          final preview = (chat['last_message_preview'] as String?) ?? '';

          return InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatDetailPage(
                    chatId: chat['chat_id'] as int,
                    currentProfileId: _currentProfileId!,
                    otherName: name,
                    otherAvatarUrl: avatarUrl.isNotEmpty ? avatarUrl : null,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFFB2DFDB),
                    backgroundImage: avatarUrl.isNotEmpty
                        ? NetworkImage(avatarUrl)
                        : null,
                    child: avatarUrl.isEmpty
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: Color(0xFF1E6A68),
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (timeStr.isNotEmpty)
                              Text(
                                timeStr,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          preview.isNotEmpty ? preview : 'Tap to open chat',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
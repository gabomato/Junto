import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileViewPage extends StatefulWidget {
  final Map<String, dynamic> profile;

  const ProfileViewPage({super.key, required this.profile});

  @override
  State<ProfileViewPage> createState() => _ProfileViewPageState();
}

class _ProfileViewPageState extends State<ProfileViewPage> {
  final _supabase = Supabase.instance.client;

  int currentImageIndex = 0;
  bool _liking = false;
  bool _alreadyLiked = false;

  // Pull a joined name (e.g. personality_type(name)) out of the row
  String _name(String table) {
    final obj = widget.profile[table];
    if (obj is Map && obj['name'] != null) return obj['name'].toString();
    return "";
  }

  @override
  void initState() {
    super.initState();
    _checkAlreadyLiked();
  }

  /// Check if the current user has already sent a connection request to this profile.
  Future<void> _checkAlreadyLiked() async {
    final authUser = _supabase.auth.currentUser;
    if (authUser == null) return;

    final meResp = await _supabase
        .from('profile')
        .select('profile_id')
        .eq('auth_user_id', authUser.id)
        .maybeSingle();
    if (meResp == null) return;
    final myId = meResp['profile_id'] as int;

    final targetId = widget.profile['profile_id'] as int;
    if (myId == targetId) {
      if (mounted) setState(() => _alreadyLiked = true);
      return;
    }

    try {
      final connectionExists = await _supabase
          .from('connection_request')
          .select('connection_request_id')
          .eq('sender_id', myId)
          .eq('receiver_id', targetId)
          .maybeSingle();

      var alreadyLiked = connectionExists != null;
      if (!alreadyLiked) {
        final notificationExists = await _supabase
            .from('notification')
            .select('notification_id')
            .eq('profile_id', targetId)
            .eq('related_id', myId)
            .maybeSingle();
        alreadyLiked = notificationExists != null;
      }

      if (mounted) {
        setState(() => _alreadyLiked = alreadyLiked);
      }
    } catch (e) {
      debugPrint('Failed to check like state: $e');
      if (mounted) setState(() => _alreadyLiked = false);
    }
  }

  /// Like a profile:
  /// 1. Insert a connection_request (status = 'pending')
  /// 2. Insert a notification for the receiver
  /// 3. Check if the other person already liked us → if yes, create match + chat
  Future<void> _likeProfile() async {
    if (_liking || _alreadyLiked) return;
    setState(() => _liking = true);

    try {
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) throw Exception('Not logged in');

      // Get current user's profile_id
      final meResp = await _supabase
          .from('profile')
          .select('profile_id')
          .eq('auth_user_id', authUser.id)
          .maybeSingle();
      if (meResp == null) throw Exception('Current user profile not found');
      final myId = meResp['profile_id'] as int;
      final targetId = widget.profile['profile_id'] as int;

      if (targetId == myId) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You cannot like your own profile.')),
          );
        }
        return;
      }

      // 1. Send connection request
      await _supabase.from('connection_request').insert({
        'sender_id': myId,
        'receiver_id': targetId,
        'status': 'pending',
      });

      // 2. Create notification for the other user
      await _supabase.from('notification').insert({
        'profile_id': targetId, // who receives the notification
        'related_id': myId, // who liked them
      });

      // 3. Check if the other user already liked us back (mutual like = match)
      final theirLike = await _supabase
          .from('connection_request')
          .select('connection_request_id')
          .eq('sender_id', targetId)
          .eq('receiver_id', myId)
          .maybeSingle();

      if (theirLike != null) {
        // Mutual like → create a match
        final matchResp = await _supabase.from('match').insert({
          'profile_a_id': myId,
          'profile_b_id': targetId,
        }).select();

        final matchId = (matchResp as List).first['match_id'] as int;

        // Create a chat room for the match
        await _supabase.from('chat').insert({
          'match_id': matchId,
          'last_message_at': DateTime.now().toIso8601String(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("🎉 It's a match! You can now chat."),
              backgroundColor: Color(0xFF1E6A68),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile liked! They\'ll be notified.'),
              backgroundColor: Color(0xFF1E6A68),
            ),
          );
        }
      }

      if (mounted) setState(() => _alreadyLiked = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;

    final name = (p["full_name"] ?? p["username"] ?? "Unknown").toString();
    final age = p["age"]?.toString() ?? "";
    final personality = _name('personality_type');
    final gender = _name('gender');
    final pronouns = _name('pronouns');
    final location = (p["location"] ?? "").toString();
    final study = (p["uni_study"] ?? "").toString();
    final university = (p["university"] ?? "").toString();
    final bio = (p["bio"] ?? "").toString();
    final avatarUrl = (p["avatar_url"] ?? "").toString();

    final List<String> images = avatarUrl.isNotEmpty ? [avatarUrl] : <String>[];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F1F1),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back,
                        size: 35,
                        color: Colors.black,
                      ),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          "Profile View",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),

                const SizedBox(height: 30),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 380,
                        width: double.infinity,
                        child: images.isEmpty
                            ? Container(
                                color: const Color(0xFFE0E0E0),
                                child: const Icon(
                                  Icons.person,
                                  size: 120,
                                  color: Colors.white,
                                ),
                              )
                            : PageView.builder(
                                itemCount: images.length,
                                onPageChanged: (i) =>
                                    setState(() => currentImageIndex = i),
                                itemBuilder: (context, index) {
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.network(
                                      images[index],
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Container(
                                        color: const Color(0xFFE0E0E0),
                                        child: const Icon(
                                          Icons.person,
                                          size: 120,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),

                      const SizedBox(height: 12),

                      if (images.isNotEmpty)
                        Center(
                          child: Text(
                            "${currentImageIndex + 1}/${images.length}",
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ),

                      const SizedBox(height: 20),

                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      if (age.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(age, style: const TextStyle(fontSize: 24)),
                      ],
                      if (personality.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(personality, style: const TextStyle(fontSize: 24)),
                      ],
                      if (gender.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(gender, style: const TextStyle(fontSize: 24)),
                      ],
                      if (pronouns.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(pronouns, style: const TextStyle(fontSize: 24)),
                      ],
                      if (location.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(location, style: const TextStyle(fontSize: 24)),
                      ],
                      if (university.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(university, style: const TextStyle(fontSize: 24)),
                      ],
                      if (study.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(study, style: const TextStyle(fontSize: 24)),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                const Text("Bio", style: TextStyle(fontSize: 24)),
                const SizedBox(height: 10),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    bio.isNotEmpty
                        ? bio
                        : "This user hasn't written a bio yet.",
                    style: const TextStyle(fontSize: 18),
                  ),
                ),

                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _alreadyLiked || _liking
                          ? Colors.grey.shade400
                          : const Color(0xFF1F6D6D),
                    ),
                    onPressed: (_alreadyLiked || _liking) ? null : _likeProfile,
                    child: _liking
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _alreadyLiked ? "Liked ✓" : "Like",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: Color(0xFF1F6D6D),
                        width: 2,
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "Ignore",
                      style: TextStyle(color: Colors.black, fontSize: 22),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

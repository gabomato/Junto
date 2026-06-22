import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile_creation.dart';
import 'junto_auth.dart';
import 'chat_detail_page.dart';

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
  bool _isOwnProfile = false;
  List<String> _extraPhotoUrls = [];

  // Pull a joined name (e.g. personality_type(name)) out of the row
  String _name(String table) {
    final obj = widget.profile[table];
    if (obj is Map && obj['name'] != null) return obj['name'].toString();
    return "";
  }

  int? _calculateAge(dynamic birthdayRaw) {
    if (birthdayRaw == null) return null;
    try {
      final birthday = DateTime.parse(birthdayRaw.toString());
      final now = DateTime.now();
      int age = now.year - birthday.year;
      if (now.month < birthday.month ||
          (now.month == birthday.month && now.day < birthday.day)) {
        age--;
      }
      return age;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _checkAlreadyLiked();
    _checkIfOwnProfile();
    _loadExtraPhotos();
  }

  Future<void> _loadExtraPhotos() async {
    try {
      final profileId = widget.profile['profile_id'];
      print('LOADING PHOTOS FOR PROFILE ID: $profileId'); // debug line
      if (profileId == null) return;
      final rows = await _supabase
          .from('profile_photo')
          .select('photo_url')
          .eq('profile_id', profileId)
          .order('uploaded_at', ascending: true);
      final urls = (rows as List).map((r) => r['photo_url'] as String).toList();
      print('EXTRA PHOTOS LOADED: $urls'); // debug line
      if (mounted) {
        setState(() => _extraPhotoUrls = urls);
      }
    } catch (e) {
      debugPrint('Failed to load extra photos: $e');
    }
  }

  Future<void> _checkIfOwnProfile() async {
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

    if (mounted) {
      setState(() => _isOwnProfile = myId == targetId);
    }
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

      await _supabase.from('connection_request').insert({
        'sender_id': myId,
        'receiver_id': targetId,
        'status': 'pending',
      });

      await _supabase.from('notification').insert({
        'profile_id': targetId,
        'related_id': myId,
      });

      final theirLike = await _supabase
          .from('connection_request')
          .select('connection_request_id')
          .eq('sender_id', targetId)
          .eq('receiver_id', myId)
          .maybeSingle();

      if (theirLike != null) {
        final matchResp = await _supabase.from('match').insert({
          'profile_a_id': myId,
          'profile_b_id': targetId,
        }).select();

        final matchId = (matchResp as List).first['match_id'] as int;

        final chatResp = await _supabase.from('chat').insert({
          'match_id': matchId,
          'last_message_at': DateTime.now().toIso8601String(),
        }).select();

        final chatId = (chatResp as List).first['chat_id'] as int;

        if (mounted) {
          final p = widget.profile;
          final theirName = (p['username'] ?? 'them').toString();
          final theirAvatar = (p['avatar_url'] ?? '').toString();

          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text("🎉 It's a match!"),
              content: Text('You and $theirName liked each other. Start chatting now?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Later'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E6A68)),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatDetailPage(
                          chatId: chatId,
                          currentProfileId: myId,
                          otherName: theirName,
                          otherAvatarUrl: theirAvatar.isNotEmpty ? theirAvatar : null,
                        ),
                      ),
                    );
                  },
                  child: const Text('Message', style: TextStyle(color: Colors.white)),
                ),
              ],
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

  Future<void> _goToEditProfile() async {
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileCreationPage(existingProfile: widget.profile),
      ),
    );
    // If the edit page returns updated data, refresh this screen with it
    if (updated != null && updated is Map<String, dynamic> && mounted) {
      setState(() {
        widget.profile.addAll(updated);
      });
      _loadExtraPhotos();
    }
  }

  Future<void> _editBio() async {
    final controller = TextEditingController(text: (widget.profile['bio'] ?? '').toString());

    final newBio = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Bio'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          autofocus: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Tell people about yourself...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F6D6D)),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (newBio == null) return; // cancelled

    try {
      final profileId = widget.profile['profile_id'];
      await _supabase
          .from('profile')
          .update({'bio': newBio})
          .eq('profile_id', profileId);

      if (mounted) {
        setState(() {
          widget.profile['bio'] = newBio;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bio updated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update bio: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;

    // Only the nickname is ever shown — never the full name.
    final name = (p["username"] ?? "Unknown").toString();
    final age = _calculateAge(p["birthday"]);
    final personality = _name('personality_type');
    final gender = _name('gender');
    final pronouns = _name('pronouns');
    final location = (p["location"] ?? "").toString();
    final study = (p["uni_study"] ?? "").toString();
    final university = (p["university"] ?? "").toString();
    final bio = (p["bio"] ?? "").toString();
    final avatarUrl = (p["avatar_url"] ?? "").toString();

    final List<String> images = [
      if (avatarUrl.isNotEmpty) avatarUrl,
      ..._extraPhotoUrls,
    ];

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
                    // Edit icon only shown when viewing your own profile
                    _isOwnProfile
                        ? IconButton(
                            onPressed: _goToEditProfile,
                            icon: const Icon(
                              Icons.edit,
                              size: 28,
                              color: Color(0xFF1F6D6D),
                            ),
                          )
                        : const SizedBox(width: 48),
                    if (_isOwnProfile)
                      IconButton(
                        onPressed: () async {
                          await _supabase.auth.signOut();
                          if (mounted) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                              (route) => false,
                            );
                          }
                        },
                        icon: const Icon(Icons.logout, size: 26, color: Colors.red),
                      ),
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

                      if (age != null) ...[
                        const SizedBox(height: 8),
                        Text('$age', style: const TextStyle(fontSize: 24)),
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

                Row(
                  children: [
                    const Text("Bio", style: TextStyle(fontSize: 24)),
                    if (_isOwnProfile) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _editBio,
                        child: const Icon(
                          Icons.edit,
                          size: 20,
                          color: Color(0xFF1F6D6D),
                        ),
                      ),
                    ],
                  ],
                ),
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

                // Like / Ignore buttons only make sense on someone else's profile
                if (!_isOwnProfile) ...[
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile_page.dart';
import 'chats_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final supabase = Supabase.instance.client;

  bool showFilters = false;
  bool showNotifications = false;
  String selectedPersonality = "";

  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> users = [];

  // Notifications
  List<Map<String, dynamic>> _notifications = [];
  bool _notifLoading = false;
  int? _myProfileId;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
    _loadMyProfileId();
  }

  Future<void> _loadMyProfileId() async {
    try {
      final authUser = supabase.auth.currentUser;
      if (authUser == null) return;
      final resp = await supabase
          .from('profile')
          .select('profile_id')
          .eq('auth_user_id', authUser.id)
          .maybeSingle();
      if (resp == null) return;
      if (mounted) setState(() => _myProfileId = resp['profile_id'] as int);
    } catch (_) {}
  }

  Future<void> _loadProfiles() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_myProfileId == null) {
        await _loadMyProfileId();
      }

      final data = await supabase
          .from('profile')
          .select()
          .order('created_at', ascending: false);

      final loadedProfiles = List<Map<String, dynamic>>.from(data);
      if (_myProfileId != null) {
        loadedProfiles.removeWhere(
          (profile) => profile['profile_id'] == _myProfileId,
        );
      }

      setState(() {
        users = loadedProfiles;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load profiles: $e';
        _loading = false;
      });
    }
  }

  Future<void> _loadNotifications() async {
    if (_myProfileId == null) return;
    setState(() => _notifLoading = true);
    try {
      final data = await supabase
          .from('notification')
          .select('notification_id, related_id')
          .eq('profile_id', _myProfileId!);

      // Fetch profile details for each notifier
      final notifications = <Map<String, dynamic>>[];
      for (final notif in data as List) {
        final relatedId = notif['related_id'] as int;
        try {
          final profile = await supabase
              .from('profile')
              .select(
                'profile_id, full_name, username, avatar_url, bio, location, university, uni_study, personality_type_id, gender_id, pronouns_id',
              )
              .eq('profile_id', relatedId)
              .maybeSingle();
          if (profile != null) {
            notifications.add({
              'notification_id': notif['notification_id'],
              'related_id': relatedId,
              'profile': profile,
            });
          }
        } catch (e) {
          debugPrint('Failed to load profile $relatedId: $e');
        }
      }

      if (mounted) {
        setState(() {
          _notifications = notifications;
          _notifLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _notifLoading = false);
    }
  }

  List<Map<String, dynamic>> get filteredUsers {
    if (selectedPersonality.isEmpty) return users;
    return users
        .where((u) => (u["personality_type"] ?? "") == selectedPersonality)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EFEF),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const CircleAvatar(
                        radius: 22,
                        backgroundColor: Color(0xFF1E6A68),
                        child: Text(
                          "Junto.",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          // Notification bell
                          Stack(
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.notifications_none,
                                  size: 30,
                                  color: showNotifications
                                      ? Colors.teal
                                      : Colors.grey,
                                ),
                                onPressed: () {
                                  setState(() {
                                    showNotifications = !showNotifications;
                                    if (showNotifications) {
                                      showFilters = false;
                                      _loadNotifications();
                                    }
                                  });
                                },
                              ),
                              if (_notifications.isNotEmpty)
                                Positioned(
                                  right: 8,
                                  top: 8,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 5),
                          // Filter
                          IconButton(
                            icon: Icon(
                              Icons.tune,
                              size: 30,
                              color: showFilters ? Colors.teal : Colors.grey,
                            ),
                            onPressed: () {
                              setState(() {
                                showFilters = !showFilters;
                                if (showFilters) showNotifications = false;
                              });
                            },
                          ),
                          // Refresh
                          IconButton(
                            icon: const Icon(
                              Icons.refresh,
                              size: 28,
                              color: Colors.grey,
                            ),
                            onPressed: _loadProfiles,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                if (showFilters) buildFilterPanel(),

                Expanded(child: _buildBody()),
              ],
            ),
          ),

          // Notification overlay
          if (showNotifications) ...[
            GestureDetector(
              onTap: () => setState(() => showNotifications = false),
              child: Container(color: Colors.black.withValues(alpha: 0.5)),
            ),
            Positioned(
              top: 90,
              left: 16,
              right: 16,
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Notifications",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_notifLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(
                              color: Color(0xFF1E6A68),
                            ),
                          ),
                        )
                      else if (_notifications.isEmpty)
                        const Text(
                          "No new notifications yet.",
                          style: TextStyle(fontSize: 15, color: Colors.grey),
                        )
                      else
                        ..._notifications.map((notif) {
                          final sender =
                              notif['profile'] as Map<String, dynamic>? ?? {};
                          final senderName =
                              (sender['full_name'] ??
                                      sender['username'] ??
                                      'Someone')
                                  .toString();
                          final avatarUrl = (sender['avatar_url'] ?? '')
                              .toString();

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              radius: 22,
                              backgroundColor: const Color(0xFFB2DFDB),
                              backgroundImage: avatarUrl.isNotEmpty
                                  ? NetworkImage(avatarUrl)
                                  : null,
                              child: avatarUrl.isEmpty
                                  ? Text(
                                      senderName.isNotEmpty
                                          ? senderName[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: Color(0xFF1E6A68),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                            title: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                                children: [
                                  TextSpan(
                                    text: senderName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const TextSpan(
                                    text: ' liked your profile ❤️',
                                  ),
                                ],
                              ),
                            ),
                            subtitle: const Text(
                              'Tap to view their profile',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            onTap: () {
                              setState(() => showNotifications = false);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ProfileViewPage(profile: sender),
                                ),
                              );
                            },
                          );
                        }),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: const Color(0xFF1E6A68),
        onTap: (index) {
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChatsPage()),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: ""),
          BottomNavigationBarItem(icon: Icon(Icons.mail_outline), label: ""),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: ""),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.teal));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadProfiles,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (filteredUsers.isEmpty) {
      return const Center(child: Text('No profiles yet.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: filteredUsers.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: personCard(filteredUsers[index]),
        );
      },
    );
  }

  Widget buildFilterPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          filterButton(
            title: "All",
            selected: selectedPersonality.isEmpty,
            onTap: () => setState(() => selectedPersonality = ""),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              personalityButton("Extrovert"),
              personalityButton("Ambivert"),
              personalityButton("Introvert"),
            ],
          ),
        ],
      ),
    );
  }

  Widget filterButton({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.teal : Colors.white,
          border: Border.all(color: Colors.teal),
        ),
        child: Text(
          title,
          style: TextStyle(color: selected ? Colors.white : Colors.black),
        ),
      ),
    );
  }

  Widget personalityButton(String personality) {
    bool isSelected = selectedPersonality == personality;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedPersonality = selectedPersonality == personality
              ? ""
              : personality;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.teal : Colors.white,
          border: Border.all(color: Colors.teal),
        ),
        child: Text(
          personality,
          style: TextStyle(color: isSelected ? Colors.white : Colors.black),
        ),
      ),
    );
  }

  Widget personCard(Map<String, dynamic> user) {
    final name = (user["full_name"] ?? user["username"] ?? "Unknown")
        .toString();
    final age = user["age"]?.toString() ?? "";
    final personality = (user["personality_type"] ?? "").toString();
    final location = (user["location"] ?? "").toString();
    final avatarUrl = (user["avatar_url"] ?? "").toString();

    void openProfile() {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProfileViewPage(profile: user)),
      );
    }

    return GestureDetector(
      onTap: openProfile,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
        child: Row(
          children: [
            CircleAvatar(
              radius: 55,
              backgroundColor: const Color(0xFFE0E0E0),
              backgroundImage: avatarUrl.isNotEmpty
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl.isEmpty
                  ? const Icon(Icons.person, size: 50, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 25),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 22)),
                  if (age.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(age, style: const TextStyle(fontSize: 18)),
                  ],
                  if (personality.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(personality, style: const TextStyle(fontSize: 18)),
                  ],
                  if (location.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(location, style: const TextStyle(fontSize: 18)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

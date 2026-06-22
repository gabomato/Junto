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

  // Which filter category is currently expanded
  String activeFilter = "";

  // Selected values (multiple selection allowed)
  List<String> selectedPersonalities = [];
  List<String> selectedAges = [];
  List<String> selectedHobbies = [];
  List<String> selectedSchools = [];

  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> users = [];

  // Notifications
  List<Map<String, dynamic>> _notifications = [];
  bool _notifLoading = false;
  int? _myProfileId;

  // ── Filter option lists ───────────────────────────────────────────────────
  final List<String> personalityOptions = ["Extrovert", "Ambivert", "Introvert"];
  final List<String> ageOptions = ["18-20", "21-23", "24-26", "27+"];
  final List<String> hobbyOptions = ["Sports", "Arts&Culture", "Culinary", "Gaming", "Outdoors"];
  final List<String> schoolOptions = ["Fontys", "TU/e", "Avans", "HAN", "Other"];

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

  /// Loads the current user's own profile and navigates to ProfileViewPage.
  Future<void> _openMyProfile() async {
    final authUser = supabase.auth.currentUser;
    if (authUser == null) return;

    final myProfile = await supabase
        .from('profile')
        .select()
        .eq('auth_user_id', authUser.id)
        .maybeSingle();

    if (myProfile == null) return;

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileViewPage(profile: myProfile)),
    );
  }

  // ── Filtering logic ───────────────────────────────────────────────────────
  bool get hasActiveFilters =>
      selectedPersonalities.isNotEmpty ||
      selectedAges.isNotEmpty ||
      selectedHobbies.isNotEmpty ||
      selectedSchools.isNotEmpty;

  List<Map<String, String>> get activeFilterChips {
    List<Map<String, String>> chips = [];
    for (var p in selectedPersonalities) chips.add({"label": p, "type": "personality"});
    for (var a in selectedAges) chips.add({"label": a, "type": "age"});
    for (var h in selectedHobbies) chips.add({"label": h, "type": "hobby"});
    for (var s in selectedSchools) chips.add({"label": s, "type": "school"});
    return chips;
  }

  void _removeFilter(Map<String, String> chip) {
    setState(() {
      if (chip["type"] == "personality") selectedPersonalities.remove(chip["label"]);
      if (chip["type"] == "age") selectedAges.remove(chip["label"]);
      if (chip["type"] == "hobby") selectedHobbies.remove(chip["label"]);
      if (chip["type"] == "school") selectedSchools.remove(chip["label"]);
    });
  }

  List<Map<String, dynamic>> get filteredUsers {
    return users.where((u) {
      final personality = (u["personality_type"] ?? "").toString();
      final location = (u["location"] ?? "").toString();
      final university = (u["university"] ?? "").toString();
      final hobby1 = (u["hobby1"] ?? "").toString();
      final hobby2 = (u["hobby2"] ?? "").toString();
      final age = _calculateAge(u["birthday"]) ?? 0;

      if (selectedPersonalities.isNotEmpty &&
          !selectedPersonalities.contains(personality)) return false;

      if (selectedAges.isNotEmpty) {
        bool matchesAge = false;
        for (var range in selectedAges) {
          if (range == "18-20" && age >= 18 && age <= 20) matchesAge = true;
          if (range == "21-23" && age >= 21 && age <= 23) matchesAge = true;
          if (range == "24-26" && age >= 24 && age <= 26) matchesAge = true;
          if (range == "27+" && age >= 27) matchesAge = true;
        }
        if (!matchesAge) return false;
      }

      if (selectedHobbies.isNotEmpty &&
          !selectedHobbies.contains(hobby1) &&
          !selectedHobbies.contains(hobby2)) return false;

      if (selectedSchools.isNotEmpty &&
          !selectedSchools.contains(university)) return false;

      // location filter kept available if you want to use it elsewhere
      // (currently unused, included for reference): location

      return true;
    }).toList();
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
                                if (!showFilters) activeFilter = "";
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

                // Active filter chips
                if (hasActiveFilters)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Active filters:",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: activeFilterChips.map((chip) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.teal,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    chip["label"]!,
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () => _removeFilter(chip),
                                    child: const Icon(Icons.close, color: Colors.white, size: 14),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

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
                              (sender['username'] ?? 'Someone')
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
          } else if (index == 2) {
            _openMyProfile();
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
      return const Center(child: Text('No profiles match these filters.'));
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

  // ── Filter panel ──────────────────────────────────────────────────────────
  Widget buildFilterPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              filterButton(
                title: "All",
                selected: !hasActiveFilters && activeFilter.isEmpty,
                onTap: () {
                  setState(() {
                    activeFilter = "";
                    selectedPersonalities = [];
                    selectedAges = [];
                    selectedHobbies = [];
                    selectedSchools = [];
                  });
                },
              ),
              filterButton(
                title: "Age",
                selected: activeFilter == "Age",
                onTap: () => setState(() {
                  activeFilter = activeFilter == "Age" ? "" : "Age";
                }),
              ),
              filterButton(
                title: "Hobbies",
                selected: activeFilter == "Hobbies",
                onTap: () => setState(() {
                  activeFilter = activeFilter == "Hobbies" ? "" : "Hobbies";
                }),
              ),
              filterButton(
                title: "School",
                selected: activeFilter == "School",
                onTap: () => setState(() {
                  activeFilter = activeFilter == "School" ? "" : "School";
                }),
              ),
              filterButton(
                title: "Personality",
                selected: activeFilter == "Personality",
                onTap: () => setState(() {
                  activeFilter = activeFilter == "Personality" ? "" : "Personality";
                }),
              ),
            ],
          ),

          if (activeFilter == "Personality") ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: personalityOptions.map((p) => optionButton(
                title: p,
                selected: selectedPersonalities.contains(p),
                onTap: () => setState(() {
                  selectedPersonalities.contains(p)
                      ? selectedPersonalities.remove(p)
                      : selectedPersonalities.add(p);
                }),
              )).toList(),
            ),
          ],

          if (activeFilter == "Age") ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: ageOptions.map((a) => optionButton(
                title: a,
                selected: selectedAges.contains(a),
                onTap: () => setState(() {
                  selectedAges.contains(a)
                      ? selectedAges.remove(a)
                      : selectedAges.add(a);
                }),
              )).toList(),
            ),
          ],

          if (activeFilter == "Hobbies") ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: hobbyOptions.map((h) => optionButton(
                title: h,
                selected: selectedHobbies.contains(h),
                onTap: () => setState(() {
                  selectedHobbies.contains(h)
                      ? selectedHobbies.remove(h)
                      : selectedHobbies.add(h);
                }),
              )).toList(),
            ),
          ],

          if (activeFilter == "School") ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: schoolOptions.map((s) => optionButton(
                title: s,
                selected: selectedSchools.contains(s),
                onTap: () => setState(() {
                  selectedSchools.contains(s)
                      ? selectedSchools.remove(s)
                      : selectedSchools.add(s);
                }),
              )).toList(),
            ),
          ],
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

  Widget optionButton({
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

  // ── Person card ───────────────────────────────────────────────────────────
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

  Widget personCard(Map<String, dynamic> user) {
    final name = (user["username"] ?? "Unknown").toString();
    final age = _calculateAge(user["birthday"]);
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
        child: Row(
          children: [
            CircleAvatar(
              radius: 45,
              backgroundColor: const Color(0xFFE0E0E0),
              backgroundImage: avatarUrl.isNotEmpty
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl.isEmpty
                  ? const Icon(Icons.person, size: 40, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 18), overflow: TextOverflow.ellipsis),
                  if (age != null) ...[
                    const SizedBox(height: 8),
                    Text('$age', style: const TextStyle(fontSize: 15), overflow: TextOverflow.ellipsis),
                  ],
                  if (personality.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(personality, style: const TextStyle(fontSize: 15), overflow: TextOverflow.ellipsis),
                  ],
                  if (location.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(location, style: const TextStyle(fontSize: 15), overflow: TextOverflow.ellipsis),
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
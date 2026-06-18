import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:junto/profile_page.dart';

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

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await supabase
          .from('profile')
          .select()
          .order('created_at', ascending: false);
      setState(() {
        users = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load profiles: $e';
        _loading = false;
      });
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
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: const Color(0xFF1E6A68),
                        child: const Text(
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
                                    if (showNotifications) showFilters = false;
                                  });
                                },
                              ),
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
              top: 100,
              left: 20,
              right: 20,
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    "No new notifications yet.",
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
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

import 'package:flutter/material.dart';

class ProfileViewPage extends StatefulWidget {
  final Map<String, dynamic> profile;

  const ProfileViewPage({super.key, required this.profile});

  @override
  State<ProfileViewPage> createState() => _ProfileViewPageState();
}

class _ProfileViewPageState extends State<ProfileViewPage> {
  int currentImageIndex = 0;

  // Pull a joined name (e.g. personality_type(name)) out of the row
  String _name(String table) {
    final obj = widget.profile[table];
    if (obj is Map && obj['name'] != null) return obj['name'].toString();
    return "";
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
                                      errorBuilder: (_, __, ___) => Container(
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
                      backgroundColor: const Color(0xFF1F6D6D),
                    ),
                    onPressed: () {},
                    child: const Text(
                      "Like",
                      style: TextStyle(color: Colors.white, fontSize: 22),
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
                    onPressed: () {},
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

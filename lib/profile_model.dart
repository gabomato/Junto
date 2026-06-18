/// Represents a user profile from the `profile` table in Supabase.
/// Also includes hobbies joined from `profile_hobby` → `hobby`.
class ProfileModel {
  final String profileId;
  final String username;
  final String? fullName;
  final int? age;
  final String? personalityType;
  final String? location;
  final String? uniStudy;
  final String? gender;
  final String? avatarUrl;
  final List<String> hobbies; // hobby names from joined profile_hobby + hobby

  ProfileModel({
    required this.profileId,
    required this.username,
    this.fullName,
    this.age,
    this.personalityType,
    this.location,
    this.uniStudy,
    this.gender,
    this.avatarUrl,
    this.hobbies = const [],
  });

  /// Build a ProfileModel from a Supabase row (with nested hobby join).
  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    // profile_hobby is a list of { hobby: { name: "..." } }
    final hobbyList = (map['profile_hobby'] as List<dynamic>? ?? [])
        .map((ph) {
          final hobby = ph['hobby'];
          if (hobby == null) return null;
          return hobby['name'] as String?;
        })
        .whereType<String>()
        .toList();

    return ProfileModel(
      profileId: map['profile_id'] as String,
      username: map['username'] as String,
      fullName: map['full_name'] as String?,
      age: map['age'] as int?,
      personalityType: map['personality_type'] as String?,
      location: map['location'] as String?,
      uniStudy: map['uni_study'] as String?,
      gender: map['gender'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      hobbies: hobbyList,
    );
  }

  /// Returns the best display name (full name if available, otherwise username)
  String get displayName => fullName?.isNotEmpty == true ? fullName! : username;

  /// Returns the first letter of the display name for avatar fallback
  String get avatarInitial =>
      displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
}

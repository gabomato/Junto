import 'package:supabase_flutter/supabase_flutter.dart';
import '../profile_model.dart';

/// All database calls go through this service.
/// The Flutter widgets just call methods here — they never touch Supabase directly.
class SupabaseService {
  final _db = Supabase.instance.client;

  // ─── PROFILES ─────────────────────────────────────────────────────────────

  /// Fetch suggested profiles (everyone except the current user).
  /// Returns profiles with their hobbies joined in.
  Future<List<ProfileModel>> getSuggestedProfiles(String? currentUserId) async {
    var query = _db.from('profile').select('''
      profile_id,
      username,
      full_name,
      age,
      personality_type,
      location,
      uni_study,
      gender,
      avatar_url,
      profile_hobby (
        hobby (
          name
        )
      )
    ''');

    // Exclude the current user from results if logged in
    if (currentUserId != null) {
      query = query.neq('profile_id', currentUserId);
    }

    final response = await query.limit(20);
    return (response as List)
        .map((item) => ProfileModel.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  /// Filter profiles by personality type.
  Future<List<ProfileModel>> getProfilesByPersonality(
    String? currentUserId,
    String personalityType,
  ) async {
    var query = _db
        .from('profile')
        .select('''
      profile_id,
      username,
      full_name,
      age,
      personality_type,
      location,
      uni_study,
      gender,
      avatar_url,
      profile_hobby (
        hobby (
          name
        )
      )
    ''')
        .eq('personality_type', personalityType);

    if (currentUserId != null) {
      query = query.neq('profile_id', currentUserId);
    }

    final response = await query.limit(20);
    return (response as List)
        .map((item) => ProfileModel.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  // ─── NOTIFICATIONS / CONNECTION REQUESTS ──────────────────────────────────

  /// Fetch pending connection requests sent TO the current user (shown as notifications).
  Future<List<Map<String, dynamic>>> getPendingRequests(
    String currentUserId,
  ) async {
    final response = await _db
        .from('connection_request')
        .select('''
      connection_request_id,
      sender_id,
      status,
      sent_at,
      profile:sender_id (
        username,
        full_name,
        age,
        avatar_url
      )
    ''')
        .eq('receiver_id', currentUserId)
        .eq('status', 'pending');

    return List<Map<String, dynamic>>.from(response as List);
  }

  /// Send a connection request from the current user to another profile.
  Future<void> sendConnectionRequest({
    required String senderId,
    required String receiverId,
  }) async {
    await _db.from('connection_request').insert({
      'sender_id': senderId,
      'receiver_id': receiverId,
      'status': 'pending',
    });
  }

  /// Accept a connection request → creates a match + chat automatically.
  Future<void> acceptConnectionRequest({
    required String requestId,
    required String senderId,
    required String receiverId,
  }) async {
    // 1. Mark the request as accepted
    await _db
        .from('connection_request')
        .update({'status': 'accepted'})
        .eq('connection_request_id', requestId);

    // 2. Create a match between the two users
    final matchResponse = await _db.from('match').insert({
      'profile_a_id': senderId,
      'profile_b_id': receiverId,
    }).select();

    // 3. Create a chat room for this match
    final matchId = (matchResponse as List).first['match_id'];
    await _db.from('chat').insert({
      'match_id': matchId,
      'last_message_at': DateTime.now().toIso8601String(),
    });
  }

  /// Decline a connection request.
  Future<void> declineConnectionRequest(String requestId) async {
    await _db
        .from('connection_request')
        .update({'status': 'declined'})
        .eq('connection_request_id', requestId);
  }

  // ─── HOBBIES ──────────────────────────────────────────────────────────────

  /// Fetch all available hobbies grouped by category.
  Future<List<Map<String, dynamic>>> getAllHobbies() async {
    final response = await _db.from('hobby').select('''
      hobby_id,
      name,
      categories (
        name
      )
    ''');
    return List<Map<String, dynamic>>.from(response as List);
  }

  // ─── MESSAGES ─────────────────────────────────────────────────────────────

  /// Fetch all messages for a given chat.
  Future<List<Map<String, dynamic>>> getMessages(String chatId) async {
    final response = await _db
        .from('message')
        .select()
        .eq('chat_id', chatId)
        .order('sent_at');
    return List<Map<String, dynamic>>.from(response as List);
  }

  /// Send a message in a chat.
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String content,
  }) async {
    await _db.from('message').insert({
      'chat_id': chatId,
      'sender_id': senderId,
      'content': content,
    });

    // Update last_message_at on the chat
    await _db
        .from('chat')
        .update({'last_message_at': DateTime.now().toIso8601String()})
        .eq('chat_id', chatId);
  }
}

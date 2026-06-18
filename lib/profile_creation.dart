import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_page.dart';

class ProfileCreationPage extends StatefulWidget {
  const ProfileCreationPage({super.key});

  @override
  State<ProfileCreationPage> createState() => _ProfileCreationPageState();
}

class _ProfileCreationPageState extends State<ProfileCreationPage> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _schoolController = TextEditingController();
  final TextEditingController _studyController = TextEditingController();

  String _locationText = '';

  String? selectedPersonality;
  String? selectedGender;
  String? selectedPronoun;
  List<String> selectedHobbies = [];

  XFile? profileImage;
  List<XFile?> addedImages = [null, null, null];

  final ImagePicker _picker = ImagePicker();

  final List<String> personalities = ['Extrovert', 'Introvert', 'Ambivert'];
  final List<String> genders = ['Female', 'Male', 'Other'];
  final List<String> pronouns = ['She/her', 'He/him', 'They/them'];
  final List<String> hobbies = [
    'Sports',
    'Arts&Culture',
    'Culinery',
    'Gaming',
    'Outdoors',
  ];

  Future<void> _pickProfileImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => profileImage = image);
    }
  }

  void _deleteProfileImage() {
    setState(() => profileImage = null);
  }

  Future<void> _pickAddedImage(int index) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => addedImages[index] = image);
    }
  }

  void _deleteAddedImage(int index) {
    setState(() => addedImages[index] = null);
  }

  Future<void> _getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _locationText = 'Location services disabled');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _locationText = 'Location permission denied');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => _locationText = 'Permission permanently denied');
      return;
    }

    Position position = await Geolocator.getCurrentPosition();

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        final city =
            place.locality ??
            place.subAdministrativeArea ??
            place.administrativeArea ??
            '';
        final country = place.country ?? '';
        setState(() {
          _locationText = city.isNotEmpty ? '$city, $country' : country;
        });
      }
    } catch (e) {
      setState(() {
        _locationText =
            '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      });
    }
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 14.0, bottom: 4),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, color: Colors.black87),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller) {
    return SizedBox(
      height: 36,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Colors.black54),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Colors.black54),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildLocationField() {
    return GestureDetector(
      onTap: _getLocation,
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black54),
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            const Icon(
              Icons.location_on_outlined,
              size: 18,
              color: Colors.black54,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _locationText.isEmpty ? 'Tap to get location' : _locationText,
                style: TextStyle(
                  fontSize: 14,
                  color: _locationText.isEmpty
                      ? Colors.black38
                      : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButton(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2D7D7D) : Colors.white,
          border: Border.all(color: Colors.black45),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildToggleRow(
    List<String> options,
    String? selected,
    Function(String) onSelect,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options
          .map(
            (o) => _buildToggleButton(o, selected == o, () {
              setState(() => onSelect(o));
            }),
          )
          .toList(),
    );
  }

  Widget _buildHobbiesRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: hobbies
          .map(
            (h) => _buildToggleButton(h, selectedHobbies.contains(h), () {
              setState(() {
                if (selectedHobbies.contains(h)) {
                  selectedHobbies.remove(h);
                } else {
                  selectedHobbies.add(h);
                }
              });
            }),
          )
          .toList(),
    );
  }

  Widget _buildImageSlot(int index) {
    final image = addedImages[index];
    return Stack(
      children: [
        GestureDetector(
          onTap: () => _pickAddedImage(index),
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.black45),
              borderRadius: BorderRadius.circular(4),
            ),
            child: image != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.file(File(image.path), fit: BoxFit.cover),
                  )
                : const Icon(Icons.add, color: Colors.black45),
          ),
        ),
        if (image != null)
          Positioned(
            top: -4,
            right: -4,
            child: GestureDetector(
              onTap: () => _deleteAddedImage(index),
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 12),
              ),
            ),
          ),
      ],
    );
  }

  Future<int?> _lookupId(String table, String idColumn, String? name) async {
    if (name == null || name.isEmpty) return null;
    final supabase = Supabase.instance.client;
    final row = await supabase
        .from(table)
        .select(idColumn)
        .eq('name', name)
        .maybeSingle();
    return row?[idColumn] as int?;
  }

  Future<void> _saveProfile() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not logged in. Register first.')),
      );
      return;
    }

    if (_nicknameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a nickname')));
      return;
    }

    try {
      final personalityId = await _lookupId(
        'personality_type',
        'personality_type_id',
        selectedPersonality,
      );
      final genderId = await _lookupId('gender', 'gender_id', selectedGender);
      final pronounsId = await _lookupId(
        'pronouns',
        'pronouns_id',
        selectedPronoun?.toLowerCase(),
      );

      await supabase.from('profile').insert({
        'auth_user_id': user.id, // the UUID goes HERE, not profile_id
        'username': _nicknameController.text.trim(),
        'full_name': _fullNameController.text.trim(),
        'birthday': '2000-01-01', // REQUIRED - see note below
        'uni_study': _studyController.text.trim(),
        'university': _schoolController.text.trim(),
        'location': _locationText,
        'personality_type_id': personalityId,
        'gender_id': genderId,
        'pronouns_id': pronounsId,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile saved!')));
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0EB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Profile Creation',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),

              // Profile picture
              Center(
                child: Stack(
                  children: [
                    GestureDetector(
                      onTap: _pickProfileImage,
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black54),
                          color: const Color(0xFFF5F0EB),
                        ),
                        child: profileImage != null
                            ? ClipOval(
                                child: Image.file(
                                  File(profileImage!.path),
                                  fit: BoxFit.cover,
                                ),
                              )
                            : null,
                      ),
                    ),
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: profileImage != null
                            ? _deleteProfileImage
                            : _pickProfileImage,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: profileImage != null
                                ? Colors.red
                                : Colors.black,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            profileImage != null ? Icons.close : Icons.edit,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              _buildLabel('Fullname'),
              _buildTextField(_fullNameController),

              _buildLabel('Nickname'),
              _buildTextField(_nicknameController),

              _buildLabel('Personality'),
              _buildToggleRow(
                personalities,
                selectedPersonality,
                (v) => selectedPersonality = v,
              ),

              _buildLabel('Gender'),
              _buildToggleRow(
                genders,
                selectedGender,
                (v) => selectedGender = v,
              ),

              _buildLabel('Pronouns'),
              _buildToggleRow(
                pronouns,
                selectedPronoun,
                (v) => selectedPronoun = v,
              ),

              _buildLabel('School'),
              _buildTextField(_schoolController),

              _buildLabel('Study'),
              _buildTextField(_studyController),

              _buildLabel('Hobbies'),
              _buildHobbiesRow(),

              _buildLabel('Location'),
              _buildLocationField(),

              _buildLabel('Add Images'),
              Row(
                children: [
                  _buildImageSlot(0),
                  const SizedBox(width: 10),
                  _buildImageSlot(1),
                  const SizedBox(width: 10),
                  _buildImageSlot(2),
                ],
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D7D7D),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text(
                    'Finish',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

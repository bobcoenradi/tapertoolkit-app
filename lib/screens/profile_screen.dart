import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../models/user_profile_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _profile;
  bool _loading = true;
  bool _saving = false;

  Uint8List? _newAvatarBytes;

  late final TextEditingController _nicknameCtrl = TextEditingController();
  late final TextEditingController _firstNameCtrl = TextEditingController();
  late final TextEditingController _lastNameCtrl = TextEditingController();
  late final TextEditingController _medicationCtrl = TextEditingController();
  late final TextEditingController _startDoseCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _medicationCtrl.dispose();
    _startDoseCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await AuthService.fetchProfile();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _loading = false;
      _nicknameCtrl.text = profile?.nickname ?? '';
      _firstNameCtrl.text = profile?.firstName ?? '';
      _lastNameCtrl.text = profile?.lastName ?? '';
      _medicationCtrl.text = profile?.medication ?? '';
      _startDoseCtrl.text = profile?.startDose?.toString() ?? '';
    });
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _newAvatarBytes = bytes);
  }

  Future<String?> _uploadAvatar() async {
    if (_newAvatarBytes == null) return null;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final ref = FirebaseStorage.instance.ref().child('avatars').child('$uid.jpg');
    final task = await ref.putData(_newAvatarBytes!);
    return await task.ref.getDownloadURL();
  }

  Future<void> _save() async {
    if (_profile == null) return;
    setState(() => _saving = true);

    try {
      String? avatarUrl = _profile!.avatarUrl;
      if (_newAvatarBytes != null) {
        avatarUrl = await _uploadAvatar();
      }

      final updated = _profile!.copyWith(
        nickname: _nicknameCtrl.text.trim().isEmpty ? null : _nicknameCtrl.text.trim(),
        firstName: _firstNameCtrl.text.trim().isEmpty ? null : _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim().isEmpty ? null : _lastNameCtrl.text.trim(),
        medication: _medicationCtrl.text.trim().isEmpty ? null : _medicationCtrl.text.trim(),
        startDose: double.tryParse(_startDoseCtrl.text),
        avatarUrl: avatarUrl,
      );
      await AuthService.updateProfile(updated);

      // Backfill photo URL on all existing posts/comments by this user
      if (avatarUrl != null) {
        await FirestoreService.backfillAuthorPhoto(
          nickname: updated.nickname,
          authorPhotoUrl: avatarUrl,
        );
      }

      if (mounted) {
        setState(() => _profile = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved'), backgroundColor: AppColors.primary),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.textDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Edit Profile', style: AppTextStyles.h4()),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton(
              onPressed: _saving || _loading ? null : _save,
              child: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                  : Text('Save', style: AppTextStyles.label(color: AppColors.primary)),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Avatar ──
                  Center(
                    child: GestureDetector(
                      onTap: _pickPhoto,
                      child: Stack(
                        children: [
                          _buildAvatarPreview(),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  _sectionLabel('Account'),
                  _field('Nickname', _nicknameCtrl),
                  const SizedBox(height: 12),
                  _field('First Name', _firstNameCtrl),
                  const SizedBox(height: 12),
                  _field('Last Name', _lastNameCtrl),

                  const SizedBox(height: 24),
                  _sectionLabel('Taper Info'),
                  _field('Medication', _medicationCtrl),
                  const SizedBox(height: 12),
                  _field('Starting Dose (mg)', _startDoseCtrl, keyboardType: TextInputType.number),

                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _saving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text('Save Changes', style: AppTextStyles.label(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildAvatarPreview() {
    if (_newAvatarBytes != null) {
      return CircleAvatar(
        radius: 52,
        backgroundImage: MemoryImage(_newAvatarBytes!),
      );
    }
    final url = _profile?.avatarUrl;
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: 52,
        backgroundImage: NetworkImage(url),
        backgroundColor: AppColors.primarySoft,
        onBackgroundImageError: (_, __) {},
      );
    }
    return const CircleAvatar(
      radius: 52,
      backgroundColor: AppColors.primarySoft,
      child: Icon(Icons.person, size: 48, color: AppColors.primary),
    );
  }

  Widget _sectionLabel(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          title,
          style: AppTextStyles.label(color: AppColors.textLight)
              .copyWith(letterSpacing: 1.0, fontSize: 11),
        ),
      );

  Widget _field(String label, TextEditingController ctrl, {TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.body(color: AppColors.textMid)),
        const SizedBox(height: 6),
        Container(
          decoration: AppDecorations.card(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: ctrl,
            keyboardType: keyboardType,
            decoration: const InputDecoration(border: InputBorder.none),
            style: AppTextStyles.body(color: AppColors.textDark),
          ),
        ),
      ],
    );
  }
}

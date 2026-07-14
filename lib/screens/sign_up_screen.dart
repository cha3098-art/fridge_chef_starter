import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/tr.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/locale_store.dart';
import '../services/profile_store.dart';
import '../theme/app_theme.dart';
import '../widgets/language_toggle.dart';

const _genderOptions = ['남성', '여성', '선택 안 함'];

/// 회원가입 화면 — 아이디/닉네임 중복확인, 프로필 사진 자동맞춤 + 용량/픽셀 표시,
/// 성별·사진·국적·거주도시·이메일은 비공개 토글을 둔다.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _idController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _nationalityController = TextEditingController(text: '대한민국');
  final _cityController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _bioController = TextEditingController();

  String _gender = _genderOptions.first;
  XFile? _photo;
  String? _photoInfo;

  bool? _idAvailable; // null = 미확인
  bool? _nicknameAvailable;
  bool _checkingId = false;
  bool _checkingNickname = false;
  bool _submitting = false;

  bool _hideGender = false;
  bool _hidePhoto = false;
  bool _hideNationality = false;
  bool _hideCity = false;
  bool _hideEmail = false;

  @override
  void dispose() {
    _idController.dispose();
    _nicknameController.dispose();
    _nationalityController.dispose();
    _cityController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _checkId() async {
    final id = _idController.text.trim();
    if (id.isEmpty) return;
    setState(() => _checkingId = true);
    final taken = await ProfileStore.instance.isUsernameTaken(id);
    if (!mounted) return;
    setState(() {
      _checkingId = false;
      _idAvailable = !taken;
    });
  }

  Future<void> _checkNickname() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) return;
    setState(() => _checkingNickname = true);
    final taken = await ProfileStore.instance.isNicknameTaken(nickname);
    if (!mounted) return;
    setState(() {
      _checkingNickname = false;
      _nicknameAvailable = !taken;
    });
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppColors.green),
              title: Text(tr('카메라로 촬영', 'Take a photo')),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.green),
              title: Text(tr('갤러리에서 선택', 'Choose from gallery')),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    try {
      final picked = await ImagePicker().pickImage(source: source, maxWidth: 1200, imageQuality: 90);
      if (picked == null || !mounted) return;
      final bytes = await File(picked.path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final width = frame.image.width;
      final height = frame.image.height;
      frame.image.dispose();
      if (!mounted) return;
      setState(() {
        _photo = picked;
        _photoInfo = '${(bytes.length / 1024).toStringAsFixed(0)}KB · ${width}x$height px';
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('사진을 가져오지 못했어요', 'Could not load photo'))),
        );
      }
    }
  }

  bool get _canSubmit =>
      _idController.text.trim().isNotEmpty &&
      _idAvailable == true &&
      _nicknameController.text.trim().isNotEmpty &&
      _nicknameAvailable == true &&
      _emailController.text.trim().isNotEmpty &&
      _passwordController.text.length >= 6 &&
      !_submitting;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _submitting = true);
    try {
      final authResponse = await AuthService.instance.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      final userId = authResponse.user?.id;
      if (userId == null) {
        throw Exception(tr('가입 처리 중 문제가 발생했어요', 'Something went wrong while signing up'));
      }
      final profile = UserProfile(
        id: userId,
        username: _idController.text.trim(),
        nickname: _nicknameController.text.trim(),
        gender: _gender,
        nationality: _nationalityController.text.trim().isEmpty ? tr('미입력', 'Not entered') : _nationalityController.text.trim(),
        city: _cityController.text.trim().isEmpty ? tr('미입력', 'Not entered') : _cityController.text.trim(),
        email: _emailController.text.trim(),
        bio: _bioController.text.trim(),
        // TODO: Supabase Storage 연동 시 _photo를 업로드하고 반환된 URL을 photoPath로 저장
        hideGender: _hideGender,
        hidePhoto: _hidePhoto,
        hideNationality: _hideNationality,
        hideCity: _hideCity,
        hideEmail: _hideEmail,
      );
      if (authResponse.session != null) {
        // 이메일 인증이 꺼져 있어 가입과 동시에 로그인 세션이 생긴 경우 — 바로 저장
        await ProfileStore.instance.register(profile);
      } else {
        // 이메일 인증이 필요해 세션이 아직 없는 경우 — 인증 후 첫 로그인 때 자동으로 저장하도록 보관
        ProfileStore.instance.stagePendingProfile(profile);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            authResponse.session != null
                ? tr('가입을 완료했어요! 환영해요 🎉', 'Sign-up complete! Welcome 🎉')
                : tr(
                    '가입 신청 완료! 이메일의 인증 링크를 클릭한 후 로그인해주세요.',
                    'Signed up! Please confirm your email, then log in.',
                  ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('가입에 실패했어요: $e', 'Sign-up failed: $e'))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocaleStore.instance,
      builder: (context, _) => Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        elevation: 0,
        title: Text(tr('회원가입', 'Sign Up')),
        actions: const [
          Padding(padding: EdgeInsets.only(right: 12), child: LanguageToggle()),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.lg),
        children: [
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickPhoto,
                  child: ClipOval(
                    child: Container(
                      width: 96,
                      height: 96,
                      color: AppColors.paperDeep,
                      child: _photo == null
                          ? const Icon(Icons.add_a_photo_outlined, color: AppColors.inkSoft, size: 28)
                          : Image.file(File(_photo!.path), fit: BoxFit.cover, width: 96, height: 96),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _photoInfo ?? tr('프로필 사진을 눌러 선택하세요 (96x96 원형으로 자동 맞춤)', 'Tap to choose a profile photo (auto-fit to a 96x96 circle)'),
                  style: const TextStyle(fontSize: 11, color: AppColors.inkSoft),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                _PrivacyToggle(
                  label: tr('사진 비공개', 'Hide photo'),
                  value: _hidePhoto,
                  onChanged: (v) => setState(() => _hidePhoto = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: cardDecoration(),
            child: Column(
              children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _idController,
                  decoration: InputDecoration(labelText: tr('아이디', 'Username')),
                  onChanged: (_) => setState(() => _idAvailable = null),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton(
                  onPressed: _checkingId ? null : _checkId,
                  child: Text(tr('중복확인', 'Check')),
                ),
              ),
            ],
          ),
          if (_idAvailable != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _idAvailable! ? tr('사용 가능한 아이디예요', 'Username is available') : tr('이미 사용 중인 아이디예요', 'Username is already taken'),
                style: TextStyle(fontSize: 11, color: _idAvailable! ? AppColors.green : AppColors.red),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _nicknameController,
                  decoration: InputDecoration(labelText: tr('닉네임', 'Nickname')),
                  onChanged: (_) => setState(() => _nicknameAvailable = null),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton(
                  onPressed: _checkingNickname ? null : _checkNickname,
                  child: Text(tr('중복확인', 'Check')),
                ),
              ),
            ],
          ),
          if (_nicknameAvailable != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _nicknameAvailable! ? tr('사용 가능한 닉네임이에요', 'Nickname is available') : tr('이미 사용 중인 닉네임이에요', 'Nickname is already taken'),
                style: TextStyle(fontSize: 11, color: _nicknameAvailable! ? AppColors.green : AppColors.red),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(tr('성별', 'Gender'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.inkSoft)),
              const Spacer(),
              _PrivacyToggle(
                label: tr('비공개', 'Private'),
                value: _hideGender,
                onChanged: (v) => setState(() => _hideGender = v),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: [
              for (final option in _genderOptions)
                ChoiceChip(
                  label: Text(trTag(option), style: const TextStyle(fontSize: 12)),
                  selected: _gender == option,
                  onSelected: (_) => setState(() => _gender = option),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _FieldWithPrivacy(
            controller: _nationalityController,
            label: tr('국적', 'Nationality'),
            hidden: _hideNationality,
            onHiddenChanged: (v) => setState(() => _hideNationality = v),
          ),
          const SizedBox(height: 12),
          _FieldWithPrivacy(
            controller: _cityController,
            label: tr('거주도시', 'City'),
            hidden: _hideCity,
            onHiddenChanged: (v) => setState(() => _hideCity = v),
          ),
          const SizedBox(height: 12),
          _FieldWithPrivacy(
            controller: _emailController,
            label: tr('이메일', 'Email'),
            keyboardType: TextInputType.emailAddress,
            hidden: _hideEmail,
            onHiddenChanged: (v) => setState(() => _hideEmail = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: true,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: tr('비밀번호', 'Password'),
              helperText: tr('6자 이상', 'At least 6 characters'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bioController,
            maxLines: 3,
            decoration: InputDecoration(labelText: tr('자기소개', 'Bio')),
          ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canSubmit ? _submit : null,
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(tr('가입하기', 'Sign Up')),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _FieldWithPrivacy extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool hidden;
  final ValueChanged<bool> onHiddenChanged;
  final TextInputType? keyboardType;

  const _FieldWithPrivacy({
    required this.controller,
    required this.label,
    required this.hidden,
    required this.onHiddenChanged,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: InputDecoration(labelText: label),
          ),
        ),
        const SizedBox(width: 8),
        _PrivacyToggle(label: tr('비공개', 'Private'), value: hidden, onChanged: onHiddenChanged),
      ],
    );
  }
}

class _PrivacyToggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PrivacyToggle({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.inkSoft)),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.green,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    );
  }
}

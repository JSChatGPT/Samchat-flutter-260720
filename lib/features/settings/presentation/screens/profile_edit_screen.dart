import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../auth/application/auth_notifier.dart';
import '../../application/profile_notifier.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _username;
  late final TextEditingController _about;
  String? _newPhotoPath;

  @override
  void initState() {
    super.initState();
    final me = ref.read(currentUserProvider);
    _firstName = TextEditingController(text: me?.firstName ?? '');
    _lastName = TextEditingController(text: me?.lastName ?? '');
    _username = TextEditingController(text: me?.username ?? '');
    _about = TextEditingController(text: me?.aboutStatus ?? '');
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _username.dispose();
    _about.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file != null) setState(() => _newPhotoPath = file.path);
  }

  Future<void> _save() async {
    final ok = await ref.read(profileEditNotifierProvider.notifier).save(
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim(),
          username: _username.text.trim(),
          aboutStatus: _about.text.trim(),
          photoPath: _newPhotoPath,
        );
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final editState = ref.watch(profileEditNotifierProvider);
    final me = ref.watch(currentUserProvider);
    final saving = editState.status == ProfileSaveStatus.saving;
    final appBarFg = Theme.of(context).appBarTheme.foregroundColor ?? Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit profile'),
        actions: [
          TextButton(
            onPressed: saving ? null : _save,
            style: TextButton.styleFrom(foregroundColor: appBarFg),
            child: saving
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: appBarFg),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickPhoto,
              child: Stack(
                children: [
                  AppAvatar(photoUrl: _newPhotoPath ?? me?.photoUrl, initials: me?.initials ?? '?', size: 100),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          AppTextField(controller: _firstName, label: 'First name'),
          const SizedBox(height: 14),
          AppTextField(controller: _lastName, label: 'Last name'),
          const SizedBox(height: 14),
          AppTextField(controller: _username, label: 'Username', prefixIcon: const Icon(Icons.alternate_email)),
          const SizedBox(height: 14),
          AppTextField(controller: _about, label: 'About', maxLines: 2),
          if (editState.status == ProfileSaveStatus.error) ...[
            const SizedBox(height: 12),
            Text(editState.error ?? 'Could not save', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
    );
  }
}

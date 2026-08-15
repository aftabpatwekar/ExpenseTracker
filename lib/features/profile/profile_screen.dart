import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../data/profile_repository.dart';
import '../../domain/models/profile.dart';

const _genders = ['Male', 'Female', 'Other', 'Prefer not to say'];

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  DateTime? _dob;
  String? _gender;
  String? _avatarUrl;
  bool _initialized = false;
  bool _saving = false;
  bool _uploading = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  void _hydrate(Profile p) {
    if (_initialized) return;
    _initialized = true;
    _name.text = p.displayName ?? '';
    _phone.text = p.phone ?? '';
    _address.text = p.address ?? '';
    _dob = p.dob;
    _gender = p.gender;
    _avatarUrl = p.avatarUrl;
  }

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 800);
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.name.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
      final url =
          await ref.read(profileRepositoryProvider).uploadAvatar(bytes, ext: ext);
      if (mounted) setState(() => _avatarUrl = url);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not upload photo')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
    );
    if (d != null) setState(() => _dob = d);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(profileRepositoryProvider).update(
            displayName: _name.text.trim().isEmpty ? null : _name.text.trim(),
            dob: _dob,
            gender: _gender,
            address: _address.text.trim().isEmpty ? null : _address.text.trim(),
            phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
            avatarUrl: _avatarUrl,
          );
      ref.invalidate(profileProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Profile saved')));
    } catch (_) {
      messenger
          .showSnackBar(const SnackBar(content: Text('Could not save profile')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = Supabase.instance.client.auth.currentUser;
    final async = ref.watch(profileProvider);
    async.whenData((p) {
      if (p != null) _hydrate(p);
    });

    final initial = (_name.text.isNotEmpty
            ? _name.text
            : (user?.email ?? '?'))
        .characters
        .first
        .toUpperCase();

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpace.lg, AppSpace.sm, AppSpace.lg, 32),
        children: [
          // Avatar
          Center(
            child: Stack(
              children: [
                Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: accentGradient(context),
                    image: _avatarUrl != null
                        ? DecorationImage(
                            image: NetworkImage(_avatarUrl!), fit: BoxFit.cover)
                        : null,
                    boxShadow: [
                      BoxShadow(
                          color: theme.colorScheme.primary.withAlpha(60),
                          blurRadius: 18,
                          offset: const Offset(0, 6)),
                    ],
                  ),
                  child: _avatarUrl == null
                      ? Center(
                          child: Text(initial,
                              style: TextStyle(
                                  color: onAccentOf(theme.colorScheme.primary),
                                  fontSize: 40,
                                  fontWeight: FontWeight.w800)))
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Material(
                    color: theme.colorScheme.primary,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _uploading ? null : _pickAvatar,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: _uploading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : Icon(Icons.camera_alt,
                                size: 18,
                                color: onAccentOf(theme.colorScheme.primary)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.xl),

          // Account (read-only)
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _readOnly(theme, 'Email', user?.email ?? '—'),
                const Divider(height: AppSpace.lg),
                _readOnly(theme, 'User ID', user?.id ?? '—', copyable: true),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.lg),

          Text('Personal details', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpace.sm),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
                labelText: 'Full name', prefixIcon: Icon(Icons.person_outline)),
          ),
          const SizedBox(height: AppSpace.md),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
                labelText: 'Phone', prefixIcon: Icon(Icons.phone_outlined)),
          ),
          const SizedBox(height: AppSpace.md),
          // DOB
          InkWell(
            onTap: _pickDob,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: InputDecorator(
              decoration: const InputDecoration(
                  labelText: 'Date of birth',
                  prefixIcon: Icon(Icons.cake_outlined)),
              child: Text(
                _dob == null
                    ? 'Not set'
                    : '${_dob!.day.toString().padLeft(2, '0')}/'
                        '${_dob!.month.toString().padLeft(2, '0')}/${_dob!.year}',
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          // Gender
          DropdownButtonFormField<String>(
            initialValue: _genders.contains(_gender) ? _gender : null,
            decoration: const InputDecoration(
                labelText: 'Gender', prefixIcon: Icon(Icons.wc_outlined)),
            items: [
              for (final g in _genders)
                DropdownMenuItem(value: g, child: Text(g)),
            ],
            onChanged: (v) => setState(() => _gender = v),
          ),
          const SizedBox(height: AppSpace.md),
          TextField(
            controller: _address,
            maxLines: 2,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
                labelText: 'Address',
                prefixIcon: Icon(Icons.home_outlined),
                alignLabelWithHint: true),
          ),
          const SizedBox(height: AppSpace.xl),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14)),
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save profile'),
          ),
        ],
      ),
    );
  }

  Widget _readOnly(ThemeData theme, String label, String value,
      {bool copyable = false}) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4)),
              const SizedBox(height: 2),
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        if (copyable)
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 18),
            tooltip: 'Copy',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User ID copied')));
            },
          ),
      ],
    );
  }
}

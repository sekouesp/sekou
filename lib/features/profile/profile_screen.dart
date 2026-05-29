import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants.dart';
import '../../core/services/cloudinary_service.dart';
import '../../core/theme/dept_theme.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../shared/widgets/magnetic_button.dart';

enum ProfileMode { create, edit }

class ProfileScreen extends ConsumerStatefulWidget {
  final ProfileMode mode;
  const ProfileScreen({super.key, required this.mode});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _firstCtrl     = TextEditingController();
  final _lastCtrl      = TextEditingController();
  final _bioCtrl       = TextEditingController();
  final _hobbiesCtrl   = TextEditingController();
  String _photoUrl     = '';
  String _dept         = '';
  List<String> _commissions = [];
  bool _isDeureudj     = false;
  bool _saving         = false;
  bool _initialized    = false;
  bool _uploadingPhoto = false;

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _bioCtrl.dispose();
    _hobbiesCtrl.dispose();
    super.dispose();
  }

  void _initFromProfile(UserProfile p) {
    if (_initialized) return;
    _initialized = true;
    _firstCtrl.text  = p.firstName;
    _lastCtrl.text   = p.lastName;
    _bioCtrl.text    = p.bio;
    _hobbiesCtrl.text = p.hobbies;
    _photoUrl = p.photoUrl;
    final allComm = List<String>.from(p.commissions);
    _isDeureudj = allComm.contains(AppConstants.deureudj);
    _commissions = allComm.where((c) => c != AppConstants.deureudj).toList();
    if (_dept.isEmpty) {
      setState(() => _dept = p.department.isEmpty
          ? AppConstants.departments.first : p.department);
    }
  }

  void _initFromGoogle() {
    if (_initialized) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final displayName = user.displayName ?? '';
    final parts = displayName.split(' ');
    _firstCtrl.text = parts.isNotEmpty ? parts.first : '';
    _lastCtrl.text  = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    _photoUrl = user.photoURL ?? '';
    _dept = AppConstants.departments.first;
    _initialized = true;
  }

  /// Ouvre le sélecteur de photo (galerie ou caméra)
  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Changer la photo',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library_rounded,
                      color: Color(0xFF4F46E5)),
                ),
                title: const Text('Galerie',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Choisir depuis la galerie'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt_rounded,
                      color: Color(0xFF059669)),
                ),
                title: const Text('Caméra',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Prendre une photo'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    setState(() => _uploadingPhoto = true);

    final url = await CloudinaryService.pickAndUpload(source: source);

    if (url != null && mounted) {
      setState(() {
        _photoUrl = url;
        _uploadingPhoto = false;
      });
    } else if (mounted) {
      setState(() => _uploadingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur lors de l\'upload de la photo'),
          backgroundColor: Color(0xFFE11D48),
        ),
      );
    }
  }

  Future<void> _save(UserProfile? existing) async {
    if (_firstCtrl.text.trim().isEmpty ||
        _lastCtrl.text.trim().isEmpty ||
        _dept.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prénom, nom et département obligatoires'),
          backgroundColor: Color(0xFFE11D48),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Non connecté');
      final uid = user.uid;

      const roleStr = 'user';

      final finalCommissions = List<String>.from(_commissions);
      if (_isDeureudj &&
          !finalCommissions.contains(AppConstants.deureudj)) {
        finalCommissions.add(AppConstants.deureudj);
      }

      final data = <String, dynamic>{
        'firstName': _firstCtrl.text.trim(),
        'lastName': _lastCtrl.text.trim(),
        'department': _dept,
        'bio': _bioCtrl.text.trim(),
        'hobbies': _hobbiesCtrl.text.trim(),
        'photoUrl': _photoUrl,
        // Ne pas écraser les commissions en mode édition
        if (existing == null) 'commissions': finalCommissions,
        if (existing == null) ...{
          'role': roleStr,
          'isBureauMember': false,
          'isLocked': false,
          'isApproved': false,
          'badges': [],
          'interactionStats': {
            'points': 0,
            'startedConversations': 0,
            'totalMessages': 0,
            'crossDeptInteractions': [],
          },
        },
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(data, SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));

      // OneSignal tag (fire & forget — ne bloque pas la navigation)
      try {
        ref.read(authNotifierProvider.notifier).savePlayerIdAfterLogin(uid);
      } catch (_) {}

      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            elevation: 0,
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.transparent,
            margin: EdgeInsets.only(
              bottom: MediaQuery.of(context).size.height - 150,
              left: 20, right: 20,
            ),
            content: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF059669).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
                ],
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF10B981)),
                  SizedBox(width: 12),
                  Text('Profil sauvegardé !', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                ],
              ),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
        if (existing == null) {
          context.go('/home');
        }
      }

    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString().replaceAll('Exception:', '').trim()}'),
            backgroundColor: const Color(0xFFE11D48),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    final profile = profileAsync.value;

    if (profile != null) {
      _initFromProfile(profile);
    } else if (!_initialized) {
      _initFromGoogle();
    }

    final theme = _dept.isNotEmpty ? DeptTheme.of(_dept) : DeptTheme.of(null);
    final isCreate = widget.mode == ProfileMode.create;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FF),
      appBar: isCreate ? null : AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Mon Profil',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => _save(profile),
            child: _saving
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF4F46E5)))
                : const Text('Sauvegarder',
                    style: TextStyle(
                        color: Color(0xFF4F46E5), fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey.shade100),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 60),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isCreate) ...[
              const SizedBox(height: 16),
              Center(
                child: Column(
                  children: [
                    Image.network(AppConstants.logoUrl, width: 60, height: 60),
                    const SizedBox(height: 16),
                    const Text('Complétez votre profil',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
                    const SizedBox(height: 6),
                    Text('Dites-en plus sur vous à la promotion.',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                  ],
                ),
              ).animate().fadeIn().slideY(begin: -0.1),
              const SizedBox(height: 32),
            ],

            // Avatar + photo picker
            Center(
              child: GestureDetector(
                onTap: _uploadingPhoto ? null : _pickPhoto,
                child: Stack(
                  children: [
                    _uploadingPhoto
                        ? Container(
                            width: 90, height: 90,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: const Center(
                              child: SizedBox(width: 28, height: 28,
                                child: CircularProgressIndicator(strokeWidth: 2.5)),
                            ),
                          )
                        : _photoUrl.isNotEmpty
                            ? Container(
                                width: 90, height: 90,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(color: Colors.grey.shade100, width: 2),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Image.network(
                                  _photoUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _avatarFallback(theme),
                                ),
                              )
                            : _avatarFallback(theme),
                    Positioned(
                      bottom: -4, right: -4,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle,
                          boxShadow: [BoxShadow(
                              color: Colors.black.withOpacity(0.1), blurRadius: 8)],
                        ),
                        child: Icon(Icons.camera_alt_outlined,
                            size: 14, color: theme.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),

            _Label('IDENTITÉ'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _Field(ctrl: _firstCtrl, label: 'Prénom',
                    icon: Icons.person_outline_rounded,
                    onChanged: (_) => setState(() {}))),
                const SizedBox(width: 10),
                Expanded(child: _Field(ctrl: _lastCtrl, label: 'Nom',
                    icon: Icons.person_outline_rounded,
                    onChanged: (_) => setState(() {}))),
              ],
            ),

            const SizedBox(height: 20),
            _Label('DÉPARTEMENT'),
            const SizedBox(height: 10),
            if (isCreate)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _dept.isEmpty ? null : _dept,
                    hint: Text('Sélectionne ton département',
                        style: TextStyle(color: Colors.grey.shade400,
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    isExpanded: true,
                    style: const TextStyle(color: Colors.black87,
                        fontWeight: FontWeight.w600, fontSize: 14, fontFamily: 'Inter'),
                    items: AppConstants.departments
                        .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                        .toList(),
                    onChanged: (v) => setState(() => _dept = v!),
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_rounded, size: 16, color: Colors.grey.shade400),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _dept,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('Non modifiable',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                              color: Colors.grey.shade500)),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),
            _Label('BIO'),
            const SizedBox(height: 10),
            _Field(ctrl: _bioCtrl, label: 'Parle un peu de toi...',
                icon: Icons.info_outline_rounded, maxLines: 3),

            const SizedBox(height: 20),
            _Label('PASSIONS'),
            const SizedBox(height: 10),
            _Field(ctrl: _hobbiesCtrl, label: 'Tes hobbies, sports, activités...',
                icon: Icons.favorite_outline_rounded, maxLines: 2),

            // Commissions — uniquement à la création
            if (isCreate) ...[
              const SizedBox(height: 20),
              _Label('COMMISSION (1 max)'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: AppConstants.commissions.map((comm) {
                  final selected = _commissions.contains(comm);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (selected) {
                        _commissions.remove(comm);
                      } else {
                        _commissions = [comm]; // 1 seule max
                      }
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? theme.primary : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: selected ? theme.primary : Colors.grey.shade200),
                        boxShadow: selected ? [BoxShadow(
                            color: theme.primary.withOpacity(0.25),
                            blurRadius: 8, offset: const Offset(0, 3))] : [],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (selected) ...[
                            const Icon(Icons.check_circle_rounded,
                                color: Colors.white, size: 14),
                            const SizedBox(width: 6),
                          ],
                          Text(comm, style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 13,
                            color: selected ? Colors.white : Colors.black87,
                          )),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Veux-tu postuler pour la commission Deureudj ?',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isDeureudj = true),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              decoration: BoxDecoration(
                                color: _isDeureudj
                                    ? const Color(0xFF0F172A) : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: _isDeureudj
                                    ? const Color(0xFF0F172A) : Colors.grey.shade200),
                              ),
                              child: Text('Oui',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900, fontSize: 14,
                                    color: _isDeureudj ? Colors.white : Colors.black87,
                                  )),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isDeureudj = false),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              decoration: BoxDecoration(
                                color: !_isDeureudj
                                    ? const Color(0xFF0F172A) : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: !_isDeureudj
                                    ? const Color(0xFF0F172A) : Colors.grey.shade200),
                              ),
                              child: Text('Non',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900, fontSize: 14,
                                    color: !_isDeureudj ? Colors.white : Colors.black87,
                                  )),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            // Commissions affichées en lecture seule en mode édition
            if (!isCreate && profile != null && profile.commissions.isNotEmpty) ...[
              const SizedBox(height: 20),
              _Label('MA COMMISSION'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_rounded, size: 16, color: Colors.grey.shade400),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        profile.commissions.join(', '),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('Non modifiable',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                              color: Colors.grey.shade500)),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 36),

            if (isCreate)
              MagneticButton(
                label: "COMMENCER L'AVENTURE",
                icon: Icons.rocket_launch_rounded,
                isLoading: _saving,
                backgroundColor: _dept.isNotEmpty ? theme.primary : const Color(0xFF0F172A),
                onPressed: () => _save(null),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),

            if (!isCreate && profile != null) ...[
              const Divider(height: 32),
              _Label('COMPTE'),
              const SizedBox(height: 12),
              _InfoRow(icon: Icons.star_outline_rounded,
                  label: 'Points',
                  value: '${profile.interactionStats?.points ?? 0}'),
              if (profile.isBureauMember)
                _InfoRow(icon: Icons.verified_rounded,
                    label: 'Bureau',
                    value: profile.bureauRole ?? 'Membre', isHighlight: true),
              const SizedBox(height: 16),

              OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(authNotifierProvider.notifier).signOut();
                  if (context.mounted) context.go('/auth');
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Déconnexion'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFE11D48),
                  side: const BorderSide(color: Color(0xFFE11D48)),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _avatarFallback(DeptTheme theme) {
    return Container(
      width: 90, height: 90,
      decoration: BoxDecoration(
        color: theme.primary, borderRadius: BorderRadius.circular(28),
      ),
      child: Center(
        child: Text(
          '${_firstCtrl.text.isNotEmpty ? _firstCtrl.text[0].toUpperCase() : '?'}'
          '${_lastCtrl.text.isNotEmpty ? _lastCtrl.text[0].toUpperCase() : '?'}',
          style: const TextStyle(color: Colors.white,
              fontWeight: FontWeight.w900, fontSize: 28),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900,
        letterSpacing: 2, color: Colors.grey.shade500));
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  const _Field({required this.ctrl, required this.label,
      required this.icon, this.maxLines = 1, this.onChanged});
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl, maxLines: maxLines, onChanged: onChanged,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      decoration: InputDecoration(
        labelText: label, prefixIcon: Icon(icon, size: 20),
        filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2)),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final bool isHighlight;
  const _InfoRow({required this.icon, required this.label,
      required this.value, this.isHighlight = false});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18,
              color: isHighlight ? const Color(0xFF4F46E5) : Colors.grey),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: Colors.grey.shade500,
              fontWeight: FontWeight.w700, fontSize: 13)),
          const Spacer(),
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13,
              color: isHighlight ? const Color(0xFF4F46E5) : Colors.black87)),
        ],
      ),
    );
  }
}

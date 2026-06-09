import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/onesignal_push_service.dart';
import '../../core/theme/dept_theme.dart';
import '../../models/app_config.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../shared/widgets/dept_avatar.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../../shared/widgets/user_detail_modal.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _broadcastTitleCtrl = TextEditingController();
  final _broadcastTextCtrl  = TextEditingController();
  String _broadcastType = 'general';
  String _broadcastDept = ''; // '' = tous les départements
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _broadcastTitleCtrl.dispose();
    _broadcastTextCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendBroadcast() async {
    if (_broadcastTitleCtrl.text.isEmpty || _broadcastTextCtrl.text.isEmpty) return;
    setState(() => _sending = true);
    final title = _broadcastTitleCtrl.text.trim();
    final text  = _broadcastTextCtrl.text.trim();
    await FirebaseFirestore.instance.collection('broadcasts').add({
      'title': title,
      'text':  text,
      'type':  _broadcastType,
      if (_broadcastDept.isNotEmpty) 'filterDept': _broadcastDept,
      'createdAt': FieldValue.serverTimestamp(),
    });
    // Envoie push OneSignal à tous les users
    try {
      await OneSignalPushService.sendBroadcastPush(
        title: title,
        body: text,
        type: _broadcastType,
      );
    } catch (_) {
      // Push non bloquant
    }
    _broadcastTitleCtrl.clear();
    _broadcastTextCtrl.clear();
    setState(() { _sending = false; _broadcastType = 'general'; _broadcastDept = ''; });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Annonce envoyée ✓'),
            backgroundColor: Color(0xFF059669)));
    }
  }

  Future<void> _toggleLock(UserProfile user) async {
    final newLocked = !user.isLocked;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'isLocked': newLocked,
    });
    // Envoie push OneSignal à l'utilisateur concerné
    try {
      await OneSignalPushService.sendLockPush(
        targetUid: user.uid,
        isLocked: newLocked,
      );
    } catch (_) {}
  }

  Future<void> _toggleBureau(UserProfile user) async {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'isBureauMember': !user.isBureauMember,
    });
  }

  Future<void> _changeBureauRole(UserProfile user, String role) async {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'bureauRole': role,
    });
  }

  Future<void> _approveUser(UserProfile user) async {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'isApproved': true,
    });
  }

  Future<void> _rejectUser(UserProfile user) async {
    // Supprime complètement l'utilisateur rejeté
    await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
  }

  Future<void> _updateConfig(String field, dynamic value) async {
    await FirebaseFirestore.instance.collection('config').doc('global').set({
      field: value,
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).value;
    if (profile?.isAdmin != true) {
      return Scaffold(
        appBar: AppBar(title: const Text('Accès refusé')),
        body: const Center(child: Icon(Icons.lock_outline_rounded, size: 80)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('GESTION BUREAU', style: TextStyle(
                fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5)),
            Text('Administration', style: TextStyle(
                color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          indicatorColor: const Color(0xFF818CF8),
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          tabs: const [
            Tab(icon: Icon(Icons.campaign_rounded), text: 'Annonces'),
            Tab(icon: Icon(Icons.verified_user_rounded), text: 'Approbations'),
            Tab(icon: Icon(Icons.people_rounded), text: 'Utilisateurs'),
            Tab(icon: Icon(Icons.settings_rounded), text: 'Config'),
            Tab(icon: Icon(Icons.image_rounded), text: 'Logos'),
            Tab(icon: Icon(Icons.bar_chart_rounded), text: 'Stats'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _BroadcastTab(
            titleCtrl: _broadcastTitleCtrl,
            textCtrl: _broadcastTextCtrl,
            type: _broadcastType,
            dept: _broadcastDept,
            sending: _sending,
            onTypeChange: (v) => setState(() => _broadcastType = v),
            onDeptChange: (v) => setState(() => _broadcastDept = v),
            onSend: _sendBroadcast,
          ),
          _ApprovalsTab(onApprove: _approveUser, onReject: _rejectUser),
          _UsersTab(onLock: _toggleLock, onBureau: _toggleBureau, onRoleChange: _changeBureauRole),
          _ConfigTab(onUpdate: _updateConfig),
          const _LogosTab(),
          const _StatsTab(),
        ],
      ),
    );
  }
}

//  Broadcast Tab
class _BroadcastTab extends StatelessWidget {
  final TextEditingController titleCtrl, textCtrl;
  final String type;
  final String dept;
  final bool sending;
  final ValueChanged<String> onTypeChange;
  final ValueChanged<String> onDeptChange;
  final VoidCallback onSend;

  const _BroadcastTab({
    required this.titleCtrl, required this.textCtrl, required this.type,
    required this.dept, required this.sending,
    required this.onTypeChange, required this.onDeptChange, required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nouvelle annonce', style: TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 20),
                TextFormField(
                  controller: titleCtrl,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  decoration: _inputDecor('Titre de l\'annonce', Icons.title_rounded),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: textCtrl,
                  maxLines: 4,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  decoration: _inputDecor('Contenu du message', Icons.notes_rounded),
                ),
                const SizedBox(height: 16),
                const Text('TYPE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900,
                    letterSpacing: 1.5, color: Colors.grey)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['general', 'urgent', 'event', 'info'].map((t) => ChoiceChip(
                    label: Text(t.toUpperCase(), style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 10)),
                    selected: type == t,
                    onSelected: (_) => onTypeChange(t),
                    selectedColor: _typeColor(t).withOpacity(0.2),
                    labelStyle: TextStyle(color: type == t ? _typeColor(t) : Colors.grey),
                  )).toList(),
                ),
                const SizedBox(height: 12),
                const Text('CIBLER UN DÉPARTEMENT (optionnel)',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900,
                        letterSpacing: 1.5, color: Colors.grey)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: dept,
                      isExpanded: true,
                      style: const TextStyle(color: Colors.black87,
                          fontWeight: FontWeight.w600, fontSize: 13, fontFamily: 'Inter'),
                      items: [
                        const DropdownMenuItem(value: '', child: Text('📢 Tous les départements')),
                        ...['Génie Informatique','Génie Civil','Génie Électrique',
                            'Génie Mécanique','Génie Chimique et Biologie Appliquée','Gestion']
                          .map((d) => DropdownMenuItem(value: d, child: Text(d))),
                      ],
                      onChanged: (v) => onDeptChange(v ?? ''),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: sending ? null : onSend,
                  icon: sending
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded),
                  label: Text(sending ? 'Envoi...' : 'ENVOYER L\'ANNONCE'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn().slideY(begin: 0.1),

          const SizedBox(height: 24),
          const Text('HISTORIQUE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900,
              letterSpacing: 2, color: Colors.grey)),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('broadcasts')
                .orderBy('createdAt', descending: true).limit(20).snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const CircularProgressIndicator();
              return Column(
                children: snap.data!.docs.map((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _typeColor(d['type'] ?? 'general').withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: _typeColor(d['type'] ?? 'general'),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(d['title'] ?? '', style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 13)),
                              Text(d['text'] ?? '', style: TextStyle(
                                  color: Colors.grey.shade500, fontSize: 11),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: Colors.red, size: 18),
                          onPressed: () => doc.reference.delete(),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Color _typeColor(String t) {
    switch (t) {
      case 'urgent': return const Color(0xFFE11D48);
      case 'event': return const Color(0xFF4F46E5);
      case 'info': return const Color(0xFF0891B2);
      default: return const Color(0xFF059669);
    }
  }

  InputDecoration _inputDecor(String label, IconData icon) => InputDecoration(
    labelText: label, prefixIcon: Icon(icon, size: 18),
    filled: true, fillColor: const Color(0xFFF5F7FF),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2)),
  );
}

// Approvals Tab 
class _ApprovalsTab extends ConsumerWidget {
  final Future<void> Function(UserProfile) onApprove;
  final Future<void> Function(UserProfile) onReject;

  const _ApprovalsTab({required this.onApprove, required this.onReject});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);
    return usersAsync.when(
      loading: () => const Center(child: AppLoadingIndicator()),
      error: (e, _) => Center(child: Text('Erreur: $e')),
      data: (users) {
        final pendingUsers = users.where((u) => !u.isApproved).toList();

        if (pendingUsers.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline_rounded, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text('Aucune inscription en attente', style: TextStyle(
                    fontWeight: FontWeight.w700, color: Colors.grey.shade500)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: pendingUsers.length,
          itemBuilder: (_, i) {
            final u = pendingUsers[i];
            final theme = DeptTheme.of(u.department);
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
              ),
              child: ListTile(
                onTap: () => showUserDetailModal(context, u),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                leading: DeptAvatar(user: u, size: 46),
                title: Text(u.fullName, style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 14)),
                subtitle: Text(u.department.replaceAll('Génie ', 'G. '),
                    style: TextStyle(color: theme.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFFE11D48)),
                      onPressed: () => _showRejectConfirm(context, u),
                      tooltip: 'Refuser',
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => onApprove(u),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Accepter', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showRejectConfirm(BuildContext context, UserProfile u) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Refuser l\'inscription ?',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        content: Text('Le compte de ${u.firstName} sera définitivement supprimé.',
            style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              onReject(u);
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Refuser'),
          ),
        ],
      ),
    );
  }
}

// Users Tab
class _UsersTab extends ConsumerWidget {
  final Future<void> Function(UserProfile) onLock;
  final Future<void> Function(UserProfile) onBureau;
  final Future<void> Function(UserProfile, String) onRoleChange;
  const _UsersTab({required this.onLock, required this.onBureau, required this.onRoleChange});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);
    return usersAsync.when(
      loading: () => const Center(child: AppLoadingIndicator()),
      error: (e, _) => Center(child: Text('Erreur: $e')),
      data: (allUsers) {
        final users = allUsers.where((u) => u.isApproved).toList();
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          itemBuilder: (_, i) {
            final u = users[i];
          final theme = DeptTheme.of(u.department);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: u.isLocked
                  ? const Color(0xFFE11D48).withOpacity(0.3) : Colors.grey.shade100),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              leading: Stack(
                clipBehavior: Clip.none,
                children: [
                  DeptAvatar(user: u, size: 46),
                  if (u.isLocked)
                    Positioned(bottom: -3, right: -3,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                              color: Color(0xFFE11D48), shape: BoxShape.circle),
                          child: const Icon(Icons.lock_rounded, color: Colors.white, size: 8),
                        )),
                ],
              ),
              title: Text(u.fullName, style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 13)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(u.department.replaceAll('Génie ', 'G. '),
                      style: TextStyle(color: theme.primary, fontSize: 11, fontWeight: FontWeight.w700)),
                  if (u.bureauRole == 'Joker')
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Text('⭐ JOKER', style: TextStyle(
                          fontSize: 8, fontWeight: FontWeight.w900,
                          color: Color(0xFFD97706), letterSpacing: 1)),
                    ),
                ],
              ),
              trailing: PopupMenuButton<String>(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'lock',
                    child: Row(children: [
                      Icon(u.isLocked ? Icons.lock_open_rounded : Icons.lock_rounded, size: 18),
                      const SizedBox(width: 10),
                      Text(u.isLocked ? 'Déverrouiller' : 'Verrouiller'),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'bureau',
                    child: Row(children: [
                      Icon(u.isBureauMember ? Icons.remove_circle_outline_rounded
                          : Icons.verified_rounded, size: 18),
                      const SizedBox(width: 10),
                      Text(u.isBureauMember ? 'Retirer du bureau' : 'Ajouter au bureau'),
                    ]),
                  ),
                  if (u.isBureauMember)
                    PopupMenuItem(
                      value: 'change_role',
                      child: Row(children: [
                        const Icon(Icons.manage_accounts_rounded, size: 18, color: Color(0xFF4F46E5)),
                        const SizedBox(width: 10),
                        Text('Attribuer un rôle (${u.bureauRole ?? 'Membre'})',
                            style: const TextStyle(color: Color(0xFF4F46E5))),
                      ]),
                    ),
                ],
                onSelected: (v) async {
                  if (v == 'lock') onLock(u);
                  if (v == 'bureau') onBureau(u);
                  if (v == 'change_role') {
                    final role = await showDialog<String>(
                      context: context,
                      builder: (c) => SimpleDialog(
                        title: Text('Rôle pour ${u.fullName}'),
                        children: ['Président', 'Vice-Président', 'Trésorier', 'Secrétaire', 'Joker', 'Membre']
                            .map((r) => SimpleDialogOption(
                                  onPressed: () => Navigator.pop(c, r),
                                  child: Text(r, style: const TextStyle(fontSize: 16)),
                                ))
                            .toList(),
                      ),
                    );
                    if (role != null) {
                      onRoleChange(u, role);
                    }
                  }
                },
              ),
            ),
          ).animate(delay: Duration(milliseconds: 30 * i)).fadeIn();
        },
      );
      },
    );
  }
}

//  Config Tab
class _ConfigTab extends StatelessWidget {
  final Future<void> Function(String, dynamic) onUpdate;
  const _ConfigTab({required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('config').doc('global').snapshots(),
      builder: (context, snap) {
        final config = snap.hasData && snap.data!.exists
            ? AppConfig.fromFirestore(snap.data!) : const AppConfig();

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('PARAMÈTRES GLOBAUX', style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w900,
                letterSpacing: 2, color: Colors.grey)),
            const SizedBox(height: 12),
            ...[
              _ConfigTile(
                label: 'Afficher les Valeurs',
                subtitle: 'Section valeurs dans le menu',
                value: config.showValues,
                onChanged: (v) => onUpdate('showValues', v),
              ),
              _ConfigTile(
                label: 'Afficher le Serment',
                subtitle: 'Serment polytechnicien dans le menu',
                value: config.showOath,
                onChanged: (v) => onUpdate('showOath', v),
              ),
              _ConfigTile(
                label: 'Désactiver le Chat',
                subtitle: 'Bloque toute la messagerie',
                value: config.disableChat,
                danger: true,
                onChanged: (v) => onUpdate('disableChat', v),
              ),
              _ConfigTile(
                label: 'Classement activé',
                subtitle: 'Affiche le classement des étudiants',
                value: config.rankingEnabled,
                onChanged: (v) => onUpdate('rankingEnabled', v),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.format_list_numbered_rounded, color: Colors.grey),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Limite du classement', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                          Text("Nombre max d'étudiants affichés", style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: TextEditingController(text: config.rankingLimit.toString()),
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          filled: true,
                          fillColor: const Color(0xFFF5F7FF),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                        onSubmitted: (val) {
                          final limit = int.tryParse(val);
                          if (limit != null && limit > 0) {
                            onUpdate('rankingLimit', limit);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _ConfigTile(
                label: 'Culturel activé',
                subtitle: 'Section sons et hymnes',
                value: config.culturelEnabled,
                onChanged: (v) => onUpdate('culturelEnabled', v),
              ),
              _ConfigTile(
                label: 'Annonces activées',
                subtitle: 'Affiche les annonces aux étudiants',
                value: config.annoncesEnabled,
                onChanged: (v) => onUpdate('annoncesEnabled', v),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ConfigTile extends StatelessWidget {
  final String label, subtitle;
  final bool value, danger;
  final ValueChanged<bool> onChanged;

  const _ConfigTile({
    required this.label, required this.subtitle,
    required this.value, required this.onChanged, this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: danger && value
            ? const Color(0xFFE11D48).withOpacity(0.3) : Colors.grey.shade100),
      ),
      child: SwitchListTile.adaptive(
        value: value,
        onChanged: onChanged,
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
        activeColor: danger ? const Color(0xFFE11D48) : const Color(0xFF4F46E5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ).animate().fadeIn();
  }
}

//  Logos Tab
class _LogosTab extends StatelessWidget {
  const _LogosTab();

  Future<void> _updateLogo(String key, String url) async {
    await FirebaseFirestore.instance.collection('config').doc('global').set({
      'departmentLogos': {key: url},
    }, SetOptions(merge: true));
  }

  Future<void> _updateCommunalLogo(String url) async {
    await FirebaseFirestore.instance.collection('config').doc('global').set({
      'communalLogo': url,
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    final depts = [
      'Génie Informatique', 'Génie Civil', 'Génie Électrique',
      'Génie Mécanique', 'Génie Chimique et Biologie Appliquée', 'Gestion',
    ];

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('config').doc('global').snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() as Map<String, dynamic>? ?? {};
        final logos = Map<String, String>.from(data['departmentLogos'] ?? {});
        final communalLogo = data['communalLogo'] as String? ?? '';

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('LOGOS CULTUREL', style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w900,
                letterSpacing: 2, color: Colors.grey)),
            const SizedBox(height: 4),
            Text('URL des images affichées dans la section Culturel',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
            const SizedBox(height: 16),

            // Logo communal
            _LogoField(
              label: '🎵 Logo Communal',
              currentUrl: communalLogo,
              onSave: _updateCommunalLogo,
            ),
            const Divider(height: 24),

            // Logos par département
            ...depts.map((dept) => _LogoField(
              label: dept,
              currentUrl: logos[dept] ?? '',
              onSave: (url) => _updateLogo(dept, url),
            )),
          ],
        );
      },
    );
  }
}

class _LogoField extends StatefulWidget {
  final String label;
  final String currentUrl;
  final Future<void> Function(String) onSave;

  const _LogoField({
    required this.label,
    required this.currentUrl,
    required this.onSave,
  });

  @override
  State<_LogoField> createState() => _LogoFieldState();
}

class _LogoFieldState extends State<_LogoField> {
  late final TextEditingController _ctrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.currentUrl);
  }

  @override
  void didUpdateWidget(_LogoField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUrl != widget.currentUrl && _ctrl.text != widget.currentUrl) {
      _ctrl.text = widget.currentUrl;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Aperçu logo
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                clipBehavior: Clip.antiAlias,
                child: widget.currentUrl.isNotEmpty
                    ? Image.network(widget.currentUrl, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.broken_image_rounded, color: Colors.grey))
                    : const Icon(Icons.image_outlined, color: Colors.grey),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(widget.label.replaceAll('Génie ', 'G. '),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'https://...',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    filled: true,
                    fillColor: const Color(0xFFF5F7FF),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade200)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade200)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _saving ? null : () async {
                  setState(() => _saving = true);
                  await widget.onSave(_ctrl.text.trim());
                  setState(() => _saving = false);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Logo mis à jour ✓'),
                          backgroundColor: Color(0xFF059669)));
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _saving
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

//  Stats Tab
class _StatsTab extends ConsumerWidget {
  const _StatsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);

    return usersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur: $e')),
      data: (users) {
        final total = users.length;
        final locked = users.where((u) => u.isLocked).length;
        final bureau = users.where((u) => u.isBureauMember).length;
        final withProfile = users.where((u) => u.department.isNotEmpty).length;
        final couverture = total > 0 ? (withProfile / total * 100).round() : 0;

        // Points par département
        final deptPoints = <String, int>{};
        for (final u in users) {
          if (u.department.isEmpty) continue;
          deptPoints[u.department] = (deptPoints[u.department] ?? 0) +
              (u.interactionStats?.points ?? 0);
        }
        final sortedDepts = deptPoints.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        // Étudiants sans activité
        final inactifs = users
            .where((u) => !u.isBureauMember &&
                (u.interactionStats?.points ?? 0) == 0 &&
                u.department.isNotEmpty)
            .toList();

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Vue globale
            const Text('VUE GLOBALE', style: TextStyle(fontSize: 11,
                fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.grey)),
            const SizedBox(height: 12),
            Row(children: [
              _StatCard2(value: '$total', label: 'Inscrits',
                  color: const Color(0xFF4F46E5), icon: Icons.people_rounded),
              const SizedBox(width: 8),
              _StatCard2(value: '$couverture%', label: 'Profils',
                  color: const Color(0xFF059669), icon: Icons.person_rounded),
              const SizedBox(width: 8),
              _StatCard2(value: '$locked', label: 'Verrouillés',
                  color: const Color(0xFFE11D48), icon: Icons.lock_rounded),
            ]),

            const SizedBox(height: 24),
            const Text('POINTS PAR DÉPARTEMENT', style: TextStyle(fontSize: 11,
                fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.grey)),
            const SizedBox(height: 12),
            ...sortedDepts.map((entry) {
              final theme = DeptTheme.of(entry.key);
              final maxPts = sortedDepts.isNotEmpty ? sortedDepts.first.value : 1;
              final pct = maxPts > 0 ? entry.value / maxPts : 0.0;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(entry.key.replaceAll('Génie ', 'G. '),
                            style: TextStyle(fontWeight: FontWeight.w800,
                                fontSize: 12, color: theme.primary)),
                        Text('${entry.value} pts',
                            style: const TextStyle(fontWeight: FontWeight.w900,
                                fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct.toDouble(),
                        backgroundColor: Colors.grey.shade100,
                        color: theme.primary,
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              );
            }),

            if (inactifs.isNotEmpty) ...[
              const SizedBox(height: 24),
              Row(children: [
                const Text('À CONTACTER', style: TextStyle(fontSize: 11,
                    fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.grey)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE11D48).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('${inactifs.length}',
                      style: const TextStyle(color: Color(0xFFE11D48),
                          fontSize: 10, fontWeight: FontWeight.w900)),
                ),
              ]),
              const SizedBox(height: 6),
              Text('Étudiants sans aucune interaction',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
              const SizedBox(height: 10),
              ...inactifs.take(10).map((u) {
                final theme = DeptTheme.of(u.department);
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Row(children: [
                    DeptAvatar(user: u, size: 36),
                    const SizedBox(width: 10),
                    Expanded(child: Text(u.fullName,
                        style: const TextStyle(fontWeight: FontWeight.w700,
                            fontSize: 13))),
                    Text(u.department.replaceAll('Génie ', 'G. '),
                        style: TextStyle(color: theme.primary,
                            fontSize: 10, fontWeight: FontWeight.w700)),
                  ]),
                );
              }),
              if (inactifs.length > 10)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('+ ${inactifs.length - 10} autres',
                      style: TextStyle(color: Colors.grey.shade400,
                          fontSize: 11, fontWeight: FontWeight.w700)),
                ),
            ],

            // Liens commissions
            const SizedBox(height: 24),
            const _CommissionLinksSection(),
          ],
        );
      },
    );
  }
}

class _StatCard2 extends StatelessWidget {
  final String value, label;
  final Color color;
  final IconData icon;
  const _StatCard2({required this.value, required this.label,
      required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontWeight: FontWeight.w900,
              fontSize: 18, color: color)),
          Text(label, style: TextStyle(color: Colors.grey.shade500,
              fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        ]),
      ),
    );
  }
}

//  Commission Links Section (dans Stats)
class _CommissionLinksSection extends StatefulWidget {
  const _CommissionLinksSection();
  @override
  State<_CommissionLinksSection> createState() => _CommissionLinksSectionState();
}

class _CommissionLinksSectionState extends State<_CommissionLinksSection> {
  final _commissions = [
    'Organisation', 'Communication', 'Sante', 'Culturel', 'Cuisine'
  ];
  final _controllers = <String, TextEditingController>{};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final c in _commissions) {
      _controllers[c] = TextEditingController();
    }
    _load();
  }

  Future<void> _load() async {
    final snap = await FirebaseFirestore.instance
        .collection('config').doc('global').get();
    final links = Map<String, String>.from(
        (snap.data()?['commissionLinks'] as Map?) ?? {});
    for (final c in _commissions) {
      _controllers[c]?.text = links[c] ?? '';
    }
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final links = {
      for (final c in _commissions)
        if (_controllers[c]!.text.trim().isNotEmpty)
          c: _controllers[c]!.text.trim()
    };
    await FirebaseFirestore.instance
        .collection('config').doc('global')
        .set({'commissionLinks': links}, SetOptions(merge: true));
    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Liens sauvegardés ✓'),
            backgroundColor: Color(0xFF059669)));
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('LIENS COMMISSIONS (WhatsApp)', style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w900,
            letterSpacing: 2, color: Colors.grey)),
        const SizedBox(height: 4),
        Text('Liens affichés aux étudiants dans leur profil',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
        const SizedBox(height: 12),
        ..._commissions.map((c) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            SizedBox(
              width: 90,
              child: Text(c, style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 12)),
            ),
            Expanded(
              child: TextField(
                controller: _controllers[c],
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'https://chat.whatsapp.com/...',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                  filled: true, fillColor: const Color(0xFFF5F7FF),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade200)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade200)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: Color(0xFF4F46E5), width: 2)),
                ),
              ),
            ),
          ]),
        )),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_rounded, size: 16),
            label: Text(_saving ? 'Sauvegarde...' : 'SAUVEGARDER LES LIENS'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(
                  fontWeight: FontWeight.w900, letterSpacing: 1),
            ),
          ),
        ),
      ],
    );
  }
}

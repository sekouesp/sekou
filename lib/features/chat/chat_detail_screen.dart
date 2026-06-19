import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../main.dart';
import '../../core/services/onesignal_push_service.dart';
import '../../core/theme/dept_theme.dart';
import '../../models/message.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../shared/widgets/dept_avatar.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../../core/services/realtime_bus_service.dart';

class ChatDetailScreen extends ConsumerStatefulWidget {
  final String convId;
  final Map<String, dynamic> extra;
  /// Affiché dans un panneau (split desktop) plutôt qu'en plein écran :
  /// masque la flèche retour (on change de panneau, on ne `pop` pas).
  final bool embedded;

  const ChatDetailScreen({
    super.key,
    required this.convId,
    required this.extra,
    this.embedded = false,
  });

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();
  bool _sending = false;

  late final Stream<List<Message>> _messagesStream;
  StreamSubscription<DocumentSnapshot>? _convSub;

  /// Dernier instant de lecture de l'interlocuteur (accusés de lecture).
  Timestamp? _otherLastReadAt;

  /// Id du dernier message déjà marqué comme lu (évite les écritures répétées).
  String? _lastMarkedMsgId;

  /// Messages anciens chargés via "Voir plus"
  List<Message> _olderMessages = [];
  bool _loadingOlder = false;
  bool _hasMoreOlder = true;

  /// Message auquel on est en train de répondre (mode reply).
  Message? _replyingTo;

  /// Message en cours d'édition (mode edit). Exclusif avec [_replyingTo].
  Message? _editingMessage;

  /// Texte du brouillon mis de côté pendant une édition, restauré à l'annulation.
  String? _draftBeforeEdit;

  /// Clé du brouillon non envoyé, isolée par conversation.
  String get _draftKey => 'draft_${widget.convId}';

  @override
  void initState() {
    super.initState();

    // Restaure un éventuel brouillon non envoyé pour cette conversation.
    final draft = ref.read(sharedPrefsProvider).getString(_draftKey);
    if (draft != null && draft.isNotEmpty) {
      _ctrl.text = draft;
    }
    _ctrl.addListener(_saveDraft);

    _messagesStream = FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.convId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map((snap) => snap.docs.map(Message.fromFirestore).toList().reversed.toList());

    // Stream du doc conversation pour suivre lastReadAt de l'autre en temps réel.
    _convSub = FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.convId)
        .snapshots()
        .listen((doc) {
      final data = doc.data();
      if (data == null || !mounted) return;
      final me = ref.read(currentUidProvider);
      final readMap = data['lastReadAt'] as Map<String, dynamic>? ?? {};
      Timestamp? otherRead;
      readMap.forEach((key, value) {
        if (key != me && value is Timestamp) otherRead = value;
      });
      if (otherRead != _otherLastReadAt) {
        setState(() => _otherLastReadAt = otherRead);
      }
    });

    _focusNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.enter &&
          !HardwareKeyboard.instance.isShiftPressed) {
        _send();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };

    WidgetsBinding.instance.addPostFrameCallback((_) => _markAsRead());
  }

  /// Charge 30 messages plus anciens que le plus ancien message affiché.
  Future<void> _loadOlderMessages(List<Message> currentMessages) async {
    if (_loadingOlder || !_hasMoreOlder) return;
    setState(() => _loadingOlder = true);

    // Le plus ancien message visible = le premier de la liste combinée
    final allVisible = [..._olderMessages, ...currentMessages];
    final oldestTimestamp = allVisible.isNotEmpty ? allVisible.first.createdAt : null;

    var query = FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.convId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(30);

    if (oldestTimestamp != null) {
      query = query.startAfter([oldestTimestamp]);
    }

    final snap = await query.get();
    final older = snap.docs.map(Message.fromFirestore).toList().reversed.toList();

    setState(() {
      _loadingOlder = false;
      if (older.isEmpty) {
        _hasMoreOlder = false;
      } else {
        _olderMessages = [...older, ..._olderMessages];
      }
    });
  }

  /// Marque la conversation comme lue pour l'utilisateur courant :
  /// remet son compteur de non-lus à 0 et met à jour son lastReadAt.
  /// Appelé à l'ouverture ET à chaque nouveau message reçu pendant qu'on lit.
  void _markAsRead() {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.convId)
        .update({
      'unreadCounts.$uid': 0,
      'lastReadAt.$uid': FieldValue.serverTimestamp(),
    }).catchError((_) {});
  }

  /// Sauvegarde (ou efface) le brouillon courant en local pour pouvoir le
  /// restaurer si l'utilisateur quitte la conversation sans envoyer.
  void _saveDraft() {
    // En édition, le champ contient le texte du message édité, pas un brouillon.
    if (_editingMessage != null) return;
    final prefs = ref.read(sharedPrefsProvider);
    final text = _ctrl.text;
    if (text.isEmpty) {
      prefs.remove(_draftKey);
    } else {
      prefs.setString(_draftKey, text);
    }
  }

  /// Passe en mode « réponse » à [m].
  void _startReply(Message m) {
    setState(() {
      _replyingTo = m;
      _editingMessage = null;
    });
    HapticFeedback.selectionClick();
    FocusScope.of(context).requestFocus(_focusNode);
  }

  /// Passe en mode « édition » de [m] (mes messages uniquement).
  void _startEdit(Message m) {
    _draftBeforeEdit = _ctrl.text;
    setState(() {
      _editingMessage = m;
      _replyingTo = null;
    });
    _ctrl.text = m.text;
    _ctrl.selection = TextSelection.fromPosition(
      TextPosition(offset: _ctrl.text.length),
    );
    HapticFeedback.selectionClick();
    FocusScope.of(context).requestFocus(_focusNode);
  }

  /// Quitte le mode reply/edit et restaure le brouillon en cours si besoin.
  void _cancelComposerMode() {
    final wasEditing = _editingMessage != null;
    setState(() {
      _replyingTo = null;
      _editingMessage = null;
    });
    if (wasEditing) {
      _ctrl.text = _draftBeforeEdit ?? '';
      _ctrl.selection = TextSelection.fromPosition(
        TextPosition(offset: _ctrl.text.length),
      );
      _draftBeforeEdit = null;
    }
  }

  Future<void> _send() async {
    // Mode édition : on met à jour le message existant, pas de nouvel envoi.
    if (_editingMessage != null) {
      await _submitEdit();
      return;
    }
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final replyingTo = _replyingTo;
    setState(() => _sending = true);
    _ctrl.clear();
    HapticFeedback.lightImpact();
    // Fetch recipient info pour scoring
    String recipientUid = widget.extra['otherUid'] as String? ?? '';
    String recipientDept = widget.extra['otherDept'] as String? ?? '';
    
    if (recipientUid.isEmpty) {
      try {
        final convSnap = await FirebaseFirestore.instance
            .collection('conversations')
            .doc(widget.convId)
            .get();
        final participants = List<String>.from(convSnap.data()?['participantIds'] ?? []);
        recipientUid = participants.firstWhere((id) => id != uid, orElse: () => '');
        
        if (recipientUid.isNotEmpty) {
          final recipientSnap = await FirebaseFirestore.instance.collection('users').doc(recipientUid).get();
          recipientDept = recipientSnap.data()?['department'] as String? ?? '';
        }
      } catch (_) {}
    }

    // Déterminer si cross-département (comme le web)
    final myProfile = ref.read(currentProfileProvider).value;
    final isCrossDept = recipientDept.isNotEmpty &&
        myProfile != null &&
        recipientDept != myProfile.department;

    final batch = FirebaseFirestore.instance.batch();
    final msgRef = FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.convId)
        .collection('messages')
        .doc();
    batch.set(msgRef, {
      'senderId': uid,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      if (replyingTo != null) ...{
        'replyToId': replyingTo.id,
        'replyToText': replyingTo.text.length > 120
            ? '${replyingTo.text.substring(0, 120)}…'
            : replyingTo.text,
        'replyToSenderId': replyingTo.senderId,
      },
    });
    batch.update(
      FirebaseFirestore.instance.collection('conversations').doc(widget.convId),
      {
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageText': text,
        'lastSenderId': uid,
        if (recipientUid.isNotEmpty) 'unreadCounts.$recipientUid': FieldValue.increment(1),
      },
    );
    // Scoring aligné avec le web : 1 pt/msg × 2 si cross-département
    final multiplier = isCrossDept ? 2 : 1;
    final pointsToAdd = 1 * multiplier;

    batch.update(
      FirebaseFirestore.instance.collection('users').doc(uid),
      {
        'interactionStats.totalMessages': FieldValue.increment(1),
        'interactionStats.points': FieldValue.increment(pointsToAdd),
        if (isCrossDept)
          'interactionStats.crossDeptInteractions':
              FieldValue.arrayUnion([recipientUid]),
      },
    );
    await batch.commit();

    // Signal temps réel Supabase
    ref.read(realtimeBusProvider).broadcastUserUpdate(uid);

    // Envoie push OneSignal au destinataire
    if (recipientUid.isNotEmpty) {
      try {
        final senderSnap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final senderName = "${senderSnap.data()?['firstName'] ?? ''} ${senderSnap.data()?['lastName'] ?? ''}".trim();

        await OneSignalPushService.sendMessagePush(
          recipientUid: recipientUid,
          senderName: senderName.isEmpty ? 'SEKOU' : senderName,
          messageText: text,
          convId: widget.convId,
        );
      } catch (e) {
        debugPrint('Erreur lors de l\'envoi du push OneSignal: $e');
      }
    }
    setState(() {
      _sending = false;
      _replyingTo = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Enregistre la modification du message en cours d'édition.
  Future<void> _submitEdit() async {
    final msg = _editingMessage;
    if (msg == null) return;
    final newText = _ctrl.text.trim();
    if (newText.isEmpty) return;
    if (newText == msg.text) {
      _cancelComposerMode();
      return;
    }
    HapticFeedback.lightImpact();
    final convRef =
        FirebaseFirestore.instance.collection('conversations').doc(widget.convId);
    try {
      await convRef.collection('messages').doc(msg.id).update({
        'text': newText,
        'editedAt': FieldValue.serverTimestamp(),
      });

      // Si on vient d'éditer le dernier message, rafraîchir l'aperçu de la conv.
      final last = await convRef
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      if (last.docs.isNotEmpty && last.docs.first.id == msg.id) {
        await convRef.update({'lastMessageText': newText}).catchError((_) {});
      }
    } catch (e) {
      debugPrint('Erreur édition message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Impossible de modifier le message',
                style: TextStyle(fontWeight: FontWeight.w700)),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return; // On garde le bandeau pour permettre de réessayer.
    }

    // Succès : restaure le brouillon en cours et ferme le mode édition.
    if (!mounted) return;
    final restored = _draftBeforeEdit ?? '';
    _draftBeforeEdit = null;
    setState(() => _editingMessage = null);
    _ctrl.text = restored;
    _ctrl.selection =
        TextSelection.fromPosition(TextPosition(offset: restored.length));
  }

  /// Supprimer un message (uniquement les miens)
  Future<void> _deleteMessage(Message msg) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer le message ?',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        content: const Text('Ce message sera supprimé définitivement.',
            style: TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      HapticFeedback.mediumImpact();
      final convRef = FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.convId);
      await convRef.collection('messages').doc(msg.id).delete();

      // Si on a supprimé le dernier message, recalculer l'aperçu de la conversation.
      final remaining = await convRef
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      if (remaining.docs.isEmpty) {
        await convRef.update({
          'lastMessageText': null,
          'lastSenderId': null,
        }).catchError((_) {});
      } else {
        final last = Message.fromFirestore(remaining.docs.first);
        await convRef.update({
          'lastMessageText': last.text,
          'lastMessageAt': last.createdAt,
          'lastSenderId': last.senderId,
        }).catchError((_) {});
      }
    }
  }

  /// Copier un message
  void _copyMessage(Message msg) {
    Clipboard.setData(ClipboardData(text: msg.text));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Message copié !',
            style: TextStyle(fontWeight: FontWeight.w700)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  /// Menu contextuel (appui long)
  void _showMessageOptions(Message msg, bool isMe) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
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
              const SizedBox(height: 16),
              // Aperçu du message
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  msg.text.length > 100 ? '${msg.text.substring(0, 100)}…' : msg.text,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.reply_rounded, color: Color(0xFF4F46E5), size: 20),
                ),
                title: const Text('Répondre', style: TextStyle(fontWeight: FontWeight.w700)),
                onTap: () {
                  Navigator.pop(context);
                  _startReply(msg);
                },
              ),
              if (isMe)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.edit_rounded, color: Color(0xFF4F46E5), size: 20),
                  ),
                  title: const Text('Modifier', style: TextStyle(fontWeight: FontWeight.w700)),
                  onTap: () {
                    Navigator.pop(context);
                    _startEdit(msg);
                  },
                ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.copy_rounded, color: Color(0xFF4F46E5), size: 20),
                ),
                title: const Text('Copier', style: TextStyle(fontWeight: FontWeight.w700)),
                onTap: () {
                  Navigator.pop(context);
                  _copyMessage(msg);
                },
              ),
              if (isMe)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE11D48).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.delete_outline_rounded,
                        color: Color(0xFFE11D48), size: 20),
                  ),
                  title: const Text('Supprimer',
                      style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFE11D48))),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteMessage(msg);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _convSub?.cancel();
    _ctrl.removeListener(_saveDraft);
    _ctrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUidProvider);
    final dept = ref.watch(currentProfileProvider).value?.department;
    final theme = DeptTheme.of(dept);
    final cs = ColorScheme.fromSeed(seedColor: theme.seed);
    final isBureau = widget.extra['isBureau'] as bool? ?? false;
    final otherName = widget.extra['otherName'] as String? ?? '';
    final otherUid = widget.extra['otherUid'] as String? ?? '';

    // Profil de l'interlocuteur (pour afficher la vraie photo + ouvrir le profil)
    final otherUser = ref.watch(allUsersProvider).value
        ?.cast<UserProfile?>()
        .firstWhere((u) => u?.uid == otherUid, orElse: () => null);

    void openProfile() {
      if (otherUid.isNotEmpty) context.push('/user/$otherUid');
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: !widget.embedded,
        leading: widget.embedded
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => context.pop(),
              ),
        titleSpacing: 0,
        title: const SizedBox.shrink(),
        actions: [
          // Profil de l'interlocuteur à droite, cliquable → ouvre le profil
          InkWell(
            onTap: openProfile,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (otherUser?.isNewcomer ?? false) ...[
                                const NewBadge(),
                                const SizedBox(width: 6),
                              ],
                              Flexible(
                                child: Text(otherName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.end,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800, fontSize: 14,
                                        color: Colors.black87)),
                              ),
                            ],
                          ),
                          if (isBureau)
                            const Text('Membre du Bureau',
                                style: TextStyle(color: Color(0xFF4F46E5), fontSize: 10,
                                    fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    otherUser != null
                        ? DeptAvatar(user: otherUser, size: 38, borderRadius: 12)
                        : Container(
                            width: 38, height: 38,
                            decoration: BoxDecoration(
                              color: theme.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                otherName.isNotEmpty ? otherName[0].toUpperCase() : '?',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey.shade100),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: _messagesStream,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: AppLoadingIndicator());
                }
                final msgs = snap.data ?? [];
                if (msgs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.waving_hand_rounded, size: 48, color: theme.primary),
                        const SizedBox(height: 12),
                        Text('Dis bonjour à $otherName !',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      ],
                    ).animate().fadeIn().scale(begin: const Offset(0.8, 0.8)),
                  );
                }
                // Marque lu en continu : si le dernier message vient de l'autre
                // et qu'il est nouveau, on remet les non-lus à 0 (fix compteur).
                final lastMsg = msgs.last;
                if (lastMsg.senderId != me && lastMsg.id != _lastMarkedMsgId) {
                  _lastMarkedMsgId = lastMsg.id;
                  _markAsRead();
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollCtrl.hasClients) {
                    _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
                  }
                });
                // Combine les anciens messages chargés manuellement + les 30 récents du stream
                final allMsgs = [..._olderMessages, ...msgs];
                final showLoadMore = _hasMoreOlder && (msgs.length >= 30 || _olderMessages.isNotEmpty);
                
                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: allMsgs.length + (showLoadMore ? 1 : 0),
                  itemBuilder: (_, i) {
                    // Bouton "Charger plus" en haut de la liste
                    if (showLoadMore && i == 0) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TextButton.icon(
                            onPressed: _loadingOlder ? null : () => _loadOlderMessages(msgs),
                            icon: _loadingOlder
                                ? const SizedBox(width: 14, height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.expand_less_rounded, size: 18),
                            label: Text(
                              _loadingOlder ? 'Chargement…' : 'Messages plus anciens',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: cs.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(color: cs.primary.withOpacity(0.2)),
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    final msgIndex = i - (showLoadMore ? 1 : 0);
                    final msg = allMsgs[msgIndex];
                    final isMe = msg.senderId == me;
                    final showDate = msgIndex == 0 ||
                        allMsgs[msgIndex].createdAt.toDate().day !=
                            allMsgs[msgIndex - 1].createdAt.toDate().day;
                    return Column(
                      children: [
                        if (showDate) _DateDivider(date: msg.createdAt.toDate()),
                        _SwipeableMessage(
                          messageId: msg.id,
                          isMe: isMe,
                          canEdit: isMe,
                          theme: theme,
                          onReply: () => _startReply(msg),
                          onEdit: () => _startEdit(msg),
                          onLongPress: () => _showMessageOptions(msg, isMe),
                          child: _MessageBubble(
                            msg: msg,
                            isMe: isMe,
                            theme: theme,
                            cs: cs,
                            index: msgIndex,
                            me: me,
                            otherName: otherName,
                            isRead: isMe &&
                                _otherLastReadAt != null &&
                                msg.createdAt.compareTo(_otherLastReadAt!) <= 0,
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          // Bandeau de réponse / édition au-dessus du composer
          if (_replyingTo != null || _editingMessage != null)
            _ComposerBanner(
              theme: theme,
              isEditing: _editingMessage != null,
              authorLabel: _editingMessage != null
                  ? 'Modifier le message'
                  : (_replyingTo!.senderId == me
                      ? 'Réponse à toi'
                      : 'Réponse à $otherName'),
              preview: (_editingMessage ?? _replyingTo)!.text,
              onCancel: _cancelComposerMode,
            ),
          // Input bar
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(
              left: 16, right: 12, top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    focusNode: _focusNode,
                    maxLines: 4,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Écris un message...',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      filled: true,
                      fillColor: const Color(0xFFF5F7FF),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: theme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: _sending
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                        )
                      : IconButton(
                          icon: Icon(
                            _editingMessage != null
                                ? Icons.check_rounded
                                : Icons.send_rounded,
                            color: Colors.white, size: 20),
                          onPressed: _send,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message msg;
  final bool isMe;
  final DeptTheme theme;
  final ColorScheme cs;
  final int index;
  final bool isRead;
  final String? me;
  final String otherName;

  const _MessageBubble({
    required this.msg, required this.isMe,
    required this.theme, required this.cs, required this.index,
    this.isRead = false,
    this.me,
    this.otherName = '',
  });

  String _formatTime(Timestamp ts) {
    final dt = ts.toDate();
    return DateFormat('HH:mm').format(dt);
  }

  /// Ouvre un lien détecté dans le navigateur externe. Préfixe en https://
  /// les URLs sans schéma (ex. www.exemple.com).
  Future<void> _openLink(LinkableElement link) async {
    var raw = link.url;
    if (!raw.startsWith('http://') && !raw.startsWith('https://')) {
      raw = 'https://$raw';
    }
    final uri = Uri.tryParse(raw);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Bloc « citation » affiché au-dessus du texte quand le message est une réponse.
  Widget _buildReplyQuote() {
    final author = msg.replyToSenderId == me ? 'Toi' : (otherName.isEmpty ? '' : otherName);
    final accent = isMe ? Colors.white : theme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isMe ? Colors.white.withOpacity(0.18) : const Color(0xFFF1F3FF),
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (author.isNotEmpty)
            Text(
              author,
              style: TextStyle(
                color: isMe ? Colors.white : theme.primary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          Text(
            msg.replyToText ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isMe ? Colors.white.withOpacity(0.85) : Colors.black54,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? theme.primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMe ? 20 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8, offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (msg.replyToText != null) ...[
              _buildReplyQuote(),
              const SizedBox(height: 6),
            ],
            Linkify(
              text: msg.text,
              onOpen: _openLink,
              options: const LinkifyOptions(humanize: false, looseUrl: true),
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 14,
                height: 1.45,
              ),
              linkStyle: TextStyle(
                color: isMe ? Colors.white : theme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                height: 1.45,
                decoration: TextDecoration.underline,
                decorationColor: isMe ? Colors.white : theme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(msg.createdAt) +
                      (msg.editedAt != null ? ' · modifié' : ''),
                  style: TextStyle(
                    color: isMe ? Colors.white.withOpacity(0.6) : Colors.grey.shade400,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    isRead ? Icons.done_all_rounded : Icons.done_rounded,
                    size: 14,
                    // Bleu vif quand lu, blanc translucide sinon (sur bulle colorée).
                    color: isRead
                        ? const Color(0xFF38BDF8)
                        : Colors.white.withOpacity(0.6),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ).animate(delay: Duration(milliseconds: 20 * (index % 10)))
     .fadeIn(duration: 250.ms)
     .slideY(begin: 0.15, curve: Curves.easeOutCubic);
  }
}

/// Bandeau au-dessus du composer indiquant le mode réponse ou édition.
class _ComposerBanner extends StatelessWidget {
  final DeptTheme theme;
  final bool isEditing;
  final String authorLabel;
  final String preview;
  final VoidCallback onCancel;

  const _ComposerBanner({
    required this.theme,
    required this.isEditing,
    required this.authorLabel,
    required this.preview,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FF),
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: theme.primary, width: 4)),
        ),
        child: Row(
          children: [
            Icon(isEditing ? Icons.edit_rounded : Icons.reply_rounded,
                size: 18, color: theme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    authorLabel,
                    style: TextStyle(
                      color: theme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.close_rounded, size: 20, color: Colors.grey.shade500),
              onPressed: onCancel,
              splashRadius: 18,
            ),
          ],
        ),
      ),
    );
  }
}

/// Enrobe une bulle de message : swipe (mobile) pour répondre/éditer,
/// actions au survol (PC) et appui long (universel).
class _SwipeableMessage extends StatefulWidget {
  final String messageId;
  final bool isMe;
  final bool canEdit;
  final DeptTheme theme;
  final Widget child;
  final VoidCallback onReply;
  final VoidCallback onEdit;
  final VoidCallback onLongPress;

  const _SwipeableMessage({
    required this.messageId,
    required this.isMe,
    required this.canEdit,
    required this.theme,
    required this.child,
    required this.onReply,
    required this.onEdit,
    required this.onLongPress,
  });

  @override
  State<_SwipeableMessage> createState() => _SwipeableMessageState();
}

class _SwipeableMessageState extends State<_SwipeableMessage> {
  bool _hovering = false;

  Widget _swipeBg(Alignment alignment, IconData icon) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Icon(icon, color: widget.theme.primary, size: 24),
    );
  }

  Widget _hoverActions() {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.reply_rounded, size: 18, color: widget.theme.primary),
              onPressed: widget.onReply,
              splashRadius: 16,
              tooltip: 'Répondre',
            ),
            if (widget.canEdit)
              IconButton(
                icon: Icon(Icons.edit_rounded, size: 18, color: widget.theme.primary),
                onPressed: widget.onEdit,
                splashRadius: 16,
                tooltip: 'Modifier',
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = GestureDetector(
      onLongPress: widget.onLongPress,
      child: Dismissible(
        key: ValueKey(widget.messageId),
        direction: widget.canEdit
            ? DismissDirection.horizontal
            : DismissDirection.startToEnd,
        dismissThresholds: const {
          DismissDirection.startToEnd: 0.25,
          DismissDirection.endToStart: 0.25,
        },
        background: _swipeBg(Alignment.centerLeft, Icons.reply_rounded),
        secondaryBackground:
            widget.canEdit ? _swipeBg(Alignment.centerRight, Icons.edit_rounded) : null,
        confirmDismiss: (dir) async {
          if (dir == DismissDirection.startToEnd) {
            widget.onReply();
          } else if (widget.canEdit) {
            widget.onEdit();
          }
          return false;
        },
        child: widget.child,
      ),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Stack(
        alignment: widget.isMe ? Alignment.centerLeft : Alignment.centerRight,
        children: [
          content,
          if (_hovering)
            Positioned(
              left: widget.isMe ? 0 : null,
              right: widget.isMe ? null : 0,
              child: _hoverActions(),
            ),
        ],
      ),
    );
  }
}

class _DateDivider extends StatelessWidget {
  final DateTime date;
  const _DateDivider({required this.date});

  String _label() {
    final now = DateTime.now();
    final diff = now.difference(date).inDays;
    if (diff == 0) return "Aujourd'hui";
    if (diff == 1) return "Hier";
    return "${date.day}/${date.month}/${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey.shade200)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _label(),
              style: TextStyle(color: Colors.grey.shade400, fontSize: 11,
                  fontWeight: FontWeight.w700, letterSpacing: 0.5),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey.shade200)),
        ],
      ),
    );
  }
}

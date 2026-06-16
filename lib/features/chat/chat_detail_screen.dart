import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/services/onesignal_push_service.dart';
import '../../core/theme/dept_theme.dart';
import '../../models/message.dart';
import '../../providers/auth_provider.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../../core/services/realtime_bus_service.dart';

class ChatDetailScreen extends ConsumerStatefulWidget {
  final String convId;
  final Map<String, dynamic> extra;

  const ChatDetailScreen({super.key, required this.convId, required this.extra});

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

  @override
  void initState() {
    super.initState();
    _messagesStream = FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.convId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs.map(Message.fromFirestore).toList());

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

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
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
    setState(() => _sending = false);
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

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            Container(
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
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(otherName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  if (isBureau)
                    const Text('Membre du Bureau',
                        style: TextStyle(color: Color(0xFF4F46E5), fontSize: 10,
                            fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => context.push('/user/${widget.extra['otherUid']}'),
          ),
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
                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: msgs.length,
                  itemBuilder: (_, i) {
                    final msg = msgs[i];
                    final isMe = msg.senderId == me;
                    final showDate = i == 0 ||
                        msgs[i].createdAt.toDate().day !=
                            msgs[i - 1].createdAt.toDate().day;
                    return Column(
                      children: [
                        if (showDate) _DateDivider(date: msg.createdAt.toDate()),
                        GestureDetector(
                          onLongPress: () => _showMessageOptions(msg, isMe),
                          child: _MessageBubble(
                            msg: msg,
                            isMe: isMe,
                            theme: theme,
                            cs: cs,
                            index: i,
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
                          icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
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

  const _MessageBubble({
    required this.msg, required this.isMe,
    required this.theme, required this.cs, required this.index,
    this.isRead = false,
  });

  String _formatTime(Timestamp ts) {
    final dt = ts.toDate();
    return DateFormat('HH:mm').format(dt);
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
            Text(
              msg.text,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(msg.createdAt),
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

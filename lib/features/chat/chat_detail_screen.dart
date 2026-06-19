import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../main.dart';
import '../../core/services/cloudinary_service.dart';
import '../../core/services/onesignal_push_service.dart';
import '../../core/theme/dept_theme.dart';
import '../../models/message.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../shared/widgets/dept_avatar.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../../core/services/realtime_bus_service.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:animated_emoji/animated_emoji.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  bool _isRecording = false;
  bool _showEmojiPicker = false;
  late final AudioRecorder _audioRecorder;

  void _toggleEmojiPicker() {
    if (_showEmojiPicker) {
      setState(() {
        _showEmojiPicker = false;
      });
      _focusNode.requestFocus();
    } else {
      FocusScope.of(context).unfocus();
      setState(() {
        _showEmojiPicker = true;
      });
    }
  }

  @override
  void initState() {
    super.initState();

    _audioRecorder = AudioRecorder();

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

    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _showEmojiPicker) {
        setState(() {
          _showEmojiPicker = false;
        });
      }
    });

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
        final senderName = "${myProfile?.firstName ?? ''} ${myProfile?.lastName ?? ''}".trim();
        
        // Broadcast in-app toast
        ref.read(realtimeBusProvider).broadcastNewMessage(recipientUid, senderName.isEmpty ? 'SEKOU' : senderName, text, widget.convId);

        if (kIsWeb) {
          await Supabase.instance.client.functions.invoke(
            'onesignal_push',
            body: {
              'recipientUid': recipientUid,
              'senderName': senderName.isEmpty ? 'SEKOU' : senderName,
              'messageText': text,
              'convId': widget.convId,
            },
          );
        } else {
          await OneSignalPushService.sendMessagePush(
            recipientUid: recipientUid,
            senderName: senderName.isEmpty ? 'SEKOU' : senderName,
            messageText: text,
            convId: widget.convId,
          );
        }
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

  Future<void> _sendImage() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    
    setState(() => _sending = true);
    
    // 1. Demander la photo et l'uploader sur Cloudinary
    final imageUrl = await CloudinaryService.pickAndUpload(folder: 'esp_sekou/chat_media');
    
    if (imageUrl == null) {
      // Annulé ou erreur
      setState(() => _sending = false);
      return;
    }

    HapticFeedback.lightImpact();

    // Fetch recipient info pour scoring & notifications
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
        
    // 2. Créer le message de type image
    batch.set(msgRef, {
      'senderId': uid,
      'text': '', // Pas de texte principal
      'type': 'image',
      'mediaUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
      if (_replyingTo != null) ...{
        'replyToId': _replyingTo!.id,
        'replyToText': _replyingTo!.type == MessageType.image ? '📷 Image' : (_replyingTo!.text.length > 120
            ? '${_replyingTo!.text.substring(0, 120)}…'
            : _replyingTo!.text),
        'replyToSenderId': _replyingTo!.senderId,
      },
    });
    
    batch.update(
      FirebaseFirestore.instance.collection('conversations').doc(widget.convId),
      {
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageText': '📷 Image',
        'lastSenderId': uid,
        if (recipientUid.isNotEmpty) 'unreadCounts.$recipientUid': FieldValue.increment(1),
      },
    );

    // Scoring
    final multiplier = isCrossDept ? 2 : 1;
    final pointsToAdd = 1 * multiplier;

    batch.update(
      FirebaseFirestore.instance.collection('users').doc(uid),
      {
        'interactionStats.startedConversations': FieldValue.increment(1),
        'interactionStats.points': FieldValue.increment(pointsToAdd),
      },
    );

    await batch.commit();

    // 3. Envoyer la notification OneSignal et In-app
    if (recipientUid.isNotEmpty) {
      try {
        final senderName = "${myProfile?.firstName ?? ''} ${myProfile?.lastName ?? ''}".trim();
        
        // Broadcast in-app toast
        ref.read(realtimeBusProvider).broadcastNewMessage(recipientUid, senderName.isEmpty ? 'SEKOU' : senderName, '📷 Vous a envoyé une image', widget.convId);

        if (kIsWeb) {
          await Supabase.instance.client.functions.invoke(
            'onesignal_push',
            body: {
              'recipientUid': recipientUid,
              'senderName': senderName.isEmpty ? 'SEKOU' : senderName,
              'messageText': '📷 Vous a envoyé une image',
              'convId': widget.convId,
            },
          );
        } else {
          await OneSignalPushService.sendMessagePush(
            recipientUid: recipientUid,
            senderName: senderName.isEmpty ? 'SEKOU' : senderName,
            messageText: '📷 Vous a envoyé une image',
            convId: widget.convId,
          );
        }
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
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
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

  Future<void> _startRecording() async {
    try {
      if (kIsWeb || await Permission.microphone.request().isGranted) {
        String? path;
        if (!kIsWeb) {
          final dir = await getTemporaryDirectory();
          path = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        }
        final encoder = kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc;
        await _audioRecorder.start(RecordConfig(encoder: encoder), path: path ?? '');
        setState(() {
          _isRecording = true;
        });
        HapticFeedback.lightImpact();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permission micro refusée.')));
        }
      }
    } catch (e) {
      debugPrint('Erreur startRecording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
      });
      if (path != null && path.isNotEmpty) {
        _sendAudio(path);
      }
    } catch (e) {
      debugPrint('Erreur stopRecording: $e');
    }
  }

  Future<void> _sendAudio(String filePath) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    
    setState(() => _sending = true);
    
    try {
      XFile file;
      if (kIsWeb) {
        final response = await http.get(Uri.parse(filePath));
        file = XFile.fromData(response.bodyBytes, name: 'audio.webm', mimeType: 'audio/webm');
      } else {
        file = XFile(filePath);
      }

      final url = await CloudinaryService.uploadFile(
        file,
        folder: 'esp_sekou/chat_media',
      );
      
      if (url == null) {
        setState(() => _sending = false);
        return;
      }
      
      String recipientUid = widget.extra['otherUid'] as String? ?? '';
      String recipientDept = widget.extra['otherDept'] as String? ?? '';
      
      final batch = FirebaseFirestore.instance.batch();
      final msgRef = FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.convId)
          .collection('messages')
          .doc();
          
      batch.set(msgRef, {
        'senderId': uid,
        'text': '',
        'type': 'audio',
        'mediaUrl': url,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      batch.update(
        FirebaseFirestore.instance.collection('conversations').doc(widget.convId),
        {
          'lastMessageAt': FieldValue.serverTimestamp(),
          'lastMessageText': '🎤 Message vocal',
          'lastSenderId': uid,
          if (recipientUid.isNotEmpty) 'unreadCounts.$recipientUid': FieldValue.increment(1),
        },
      );
      
      await batch.commit();
      
      ref.read(realtimeBusProvider).broadcastUserUpdate(uid);
      
      if (recipientUid.isNotEmpty) {
        final myProfile = ref.read(currentProfileProvider).value;
        final senderName = "${myProfile?.firstName ?? ''} ${myProfile?.lastName ?? ''}".trim();
        ref.read(realtimeBusProvider).broadcastNewMessage(recipientUid, senderName.isEmpty ? 'SEKOU' : senderName, '🎤 Message vocal', widget.convId);

        if (kIsWeb) {
          await Supabase.instance.client.functions.invoke(
            'onesignal_push',
            body: {
              'recipientUid': recipientUid,
              'senderName': senderName.isEmpty ? 'SEKOU' : senderName,
              'messageText': '🎤 Message vocal',
              'convId': widget.convId,
            },
          );
        } else {
          await OneSignalPushService.sendMessagePush(
            recipientUid: recipientUid,
            senderName: senderName.isEmpty ? 'SEKOU' : senderName,
            messageText: '🎤 Message vocal',
            convId: widget.convId,
          );
        }
      }
    } catch (e) {
      debugPrint('Erreur envoi audio: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendSticker(String url) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    
    String recipientUid = widget.extra['otherUid'] as String? ?? '';
    
    final batch = FirebaseFirestore.instance.batch();
    final msgRef = FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.convId)
        .collection('messages')
        .doc();
        
    batch.set(msgRef, {
      'senderId': uid,
      'text': '',
      'type': 'sticker',
      'mediaUrl': url,
      'createdAt': FieldValue.serverTimestamp(),
      'replyToId': _replyingTo?.id,
      'replyToText': _replyingTo?.text,
      'replyToSenderId': _replyingTo?.senderId,
    });
    
    final convRef = FirebaseFirestore.instance.collection('conversations').doc(widget.convId);
    batch.update(convRef, {
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageText': '🖼️ Sticker',
      'lastSenderId': uid,
      if (recipientUid.isNotEmpty) 'unreadCounts.$recipientUid': FieldValue.increment(1),
    });
    
    await batch.commit();
    _cancelComposerMode();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _createSticker() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    
    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: ImageSource.gallery);
    if (xFile == null) return;
    
    setState(() => _sending = true);
    
    try {
      final url = await CloudinaryService.uploadFile(
        xFile,
        folder: 'esp_sekou/stickers',
      );
      
      if (url != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).collection('stickers').add({
          'url': url,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint("Erreur upload sticker: $e");
    } finally {
      if (mounted) setState(() => _sending = false);
    }
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
    _audioRecorder.dispose();
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
            color: Colors.transparent,
            padding: const EdgeInsets.only(left: 8, right: 8, top: 4, bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _isRecording
                        ? Container(
                            height: 48,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            child: Row(
                              children: [
                                const Icon(Icons.mic, color: Color(0xFFE11D48))
                                    .animate(onPlay: (controller) => controller.repeat(reverse: true))
                                    .fadeOut(duration: 500.ms)
                                    .fadeIn(duration: 500.ms),
                                const SizedBox(width: 12),
                                const Text(
                                  'Enregistrement...',
                                  style: TextStyle(
                                    color: Color(0xFFE11D48),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : TextField(
                            controller: _ctrl,
                            focusNode: _focusNode,
                            maxLines: 4,
                            minLines: 1,
                            onTap: () {
                              if (_showEmojiPicker) {
                                setState(() {
                                  _showEmojiPicker = false;
                                });
                              }
                            },
                            onChanged: (_) => setState(() {}),
                            textInputAction: TextInputAction.send,
                            textCapitalization: TextCapitalization.sentences,
                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                            onSubmitted: (_) => _send(),
                            decoration: InputDecoration(
                              hintText: 'Message',
                              hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                              filled: true,
                              fillColor: Colors.transparent,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: IconButton(
                                icon: Icon(
                                  _showEmojiPicker ? Icons.keyboard_rounded : Icons.emoji_emotions_outlined,
                                  color: Colors.grey.shade600,
                                ),
                                onPressed: _toggleEmojiPicker,
                              ),
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.camera_alt_rounded, color: Colors.grey.shade600),
                                    onPressed: _sending ? null : _sendImage,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 40),
                                  ),
                                  const SizedBox(width: 4),
                                ],
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: _isRecording
                        ? const Color(0xFFE11D48)
                        : theme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _sending
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                        )
                      : IconButton(
                          icon: Icon(
                            _isRecording
                                ? Icons.stop_rounded
                                : (_ctrl.text.isEmpty && _editingMessage == null
                                    ? Icons.mic_rounded
                                    : Icons.send_rounded),
                            color: Colors.white, size: 24),
                          onPressed: _isRecording
                              ? _stopRecording
                              : (_ctrl.text.isEmpty && _editingMessage == null
                                  ? _startRecording
                                  : _send),
                        ),
                ),
              ],
            ),
          ),
          if (_showEmojiPicker)
            _EmojiStickerPicker(
              theme: theme,
              uid: me ?? '',
              onEmojiSelected: (emoji) {
                _ctrl.text = _ctrl.text + emoji.emoji;
                _ctrl.selection = TextSelection.fromPosition(TextPosition(offset: _ctrl.text.length));
                setState(() {}); // refresh mic/send icon
              },
              onStickerSelected: (url) {
                _sendSticker(url);
                setState(() => _showEmojiPicker = false);
              },
              onCreateSticker: _createSticker,
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

  void _triggerLaughExplosion(BuildContext context, Offset position) {
    final overlay = Overlay.of(context);
    final random = DateTime.now().millisecondsSinceEpoch;
    final entries = <OverlayEntry>[];
    
    final particleTypes = [
      '😂', '🤣', 'HAH_cyan', 'lol_red', '😅', 'HAH_orange', 'HEH_pink', '😂'
    ];
    
    for (int i = 0; i < 8; i++) {
      late OverlayEntry entry;
      entry = OverlayEntry(
        builder: (ctx) {
          return _LaughParticle(
            particleType: particleTypes[i],
            index: i,
            seed: random + i,
            center: position,
            onComplete: () {
              entry.remove();
              entries.remove(entry);
            },
          );
        },
      );
      entries.add(entry);
    }
    
    for (final e in entries) {
      overlay.insert(e);
    }
  }

  bool _isOnlyEmojis(String text) {
    if (text.isEmpty) return false;
    final emojiRegex = RegExp(r'^[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{1F1E6}-\u{1F1FF}\u{1F018}-\u{1F0F5}\u{1F200}-\u{1F270}\u{1F600}-\u{1F64F}\u{1F680}-\u{1F6FF}\u{1F900}-\u{1F9FF}\u{1FA70}-\u{1FAFF}\u{FE0F}\s]+$', unicode: true);
    if (!emojiRegex.hasMatch(text)) return false;
    return text.replaceAll(RegExp(r'\s+'), '').length <= 10;
  }

  @override
  Widget build(BuildContext context) {
    final isStickerMsg = msg.type == MessageType.sticker;
    final isGiantEmoji = msg.type == MessageType.text && msg.replyToText == null && _isOnlyEmojis(msg.text);
    final isImageOnly = msg.type == MessageType.image && msg.text.isEmpty && msg.replyToText == null;
    final isBorderless = isStickerMsg || isGiantEmoji;

    final bubblePadding = isBorderless 
        ? EdgeInsets.zero 
        : (isImageOnly ? const EdgeInsets.all(4) : const EdgeInsets.symmetric(horizontal: 16, vertical: 10));

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        padding: bubblePadding,
        decoration: isBorderless ? null : BoxDecoration(
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
        child: isBorderless ? _buildStickerContent(context, isGiantEmoji: isGiantEmoji) : _buildTextContent(context),
      ),
    ).animate(delay: Duration(milliseconds: 20 * (index % 10)))
     .fadeIn(duration: 250.ms)
     .slideY(begin: 0.15, curve: Curves.easeOutCubic);
  }

  AnimatedEmojiData? _getAnimatedEmojiData(String text) {
    final t = text.trim().replaceAll('\u{FE0F}', '');
    return AnimatedEmojis.fromEmojiString(t) ?? AnimatedEmojis.fromEmojiString(text.trim());
  }

  Widget _buildStickerContent(BuildContext context, {bool isGiantEmoji = false}) {
    final animatedData = isGiantEmoji ? _getAnimatedEmojiData(msg.text) : null;
    
    return Stack(
      children: [
        if (isGiantEmoji)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              final text = msg.text.trim().replaceAll('\u{FE0F}', '');
              if (text.contains('😂') || text.contains('🤣') || text.contains('😅') || text.contains('😆') || text.contains('😹')) {
                final renderBox = context.findRenderObject() as RenderBox?;
                final position = renderBox != null 
                    ? renderBox.localToGlobal(Offset(renderBox.size.width / 2, renderBox.size.height / 2))
                    : MediaQuery.of(context).size.center(Offset.zero);
                _triggerLaughExplosion(context, position);
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: animatedData != null
                  ? AnimatedEmoji(
                      animatedData,
                      size: 90,
                      errorWidget: Text(msg.text, style: const TextStyle(fontSize: 64, height: 1.1)),
                    )
                  : Text(
                      msg.text,
                      style: const TextStyle(fontSize: 64, height: 1.1),
                    ),
            ),
          )
        else if (msg.mediaUrl != null)
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => _FullScreenImageViewer(imageUrl: msg.mediaUrl!, tag: 'sticker_${msg.id}'),
              ));
            },
            child: Hero(
              tag: 'sticker_${msg.id}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: msg.mediaUrl!.toLowerCase().endsWith('.gif')
                  ? Image.network(
                      msg.mediaUrl!,
                      width: 160,
                      height: 160,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          width: 160, height: 160, color: Colors.transparent,
                          child: const Center(child: AppLoadingIndicator()),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 160, height: 160, color: Colors.black12,
                        child: const Center(child: Icon(Icons.broken_image_rounded, color: Colors.grey)),
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: msg.mediaUrl!,
                      width: 160,
                      height: 160,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => Container(
                        width: 160,
                        height: 160,
                        color: Colors.transparent,
                        child: const Center(child: AppLoadingIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 160,
                        height: 160,
                        color: Colors.black12,
                        child: const Center(child: Icon(Icons.broken_image_rounded, color: Colors.grey)),
                      ),
                    ),
              ),
            ),
          ),
        Positioned(
          bottom: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(msg.createdAt),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    isRead ? Icons.done_all_rounded : Icons.done_rounded,
                    size: 14,
                    color: isRead ? const Color(0xFF38BDF8) : Colors.white,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextContent(BuildContext context) {
    return Column(
      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (msg.replyToText != null) ...[
          _buildReplyQuote(),
          const SizedBox(height: 6),
        ],
        if (msg.type == MessageType.image && msg.mediaUrl != null) ...[
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => _FullScreenImageViewer(imageUrl: msg.mediaUrl!, tag: 'img_${msg.id}'),
              ));
            },
            child: Hero(
              tag: 'img_${msg.id}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: msg.mediaUrl!,
                  width: MediaQuery.of(context).size.width * 0.65,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: MediaQuery.of(context).size.width * 0.65,
                    height: 200,
                    color: Colors.black12,
                    child: const Center(child: AppLoadingIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: MediaQuery.of(context).size.width * 0.65,
                    height: 200,
                    color: Colors.black12,
                    child: const Center(child: Icon(Icons.broken_image_rounded, color: Colors.grey)),
                  ),
                ),
              ),
            ),
          ),
          if (msg.text.isNotEmpty) const SizedBox(height: 6),
        ],
        if (msg.text.isNotEmpty)
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
        if (msg.type == MessageType.audio && msg.mediaUrl != null) ...[
          Container(
            width: MediaQuery.of(context).size.width * 0.60,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: _AudioPlayerWidget(
              audioUrl: msg.mediaUrl!,
              isMe: isMe,
              theme: theme,
            ),
          ),
        ],
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
    );
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

class _AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  final bool isMe;
  final DeptTheme theme;

  const _AudioPlayerWidget({
    required this.audioUrl,
    required this.isMe,
    required this.theme,
  });

  @override
  State<_AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<_AudioPlayerWidget> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });
    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) {
        setState(() {
          _duration = newDuration;
        });
      }
    });
    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) {
        setState(() {
          _position = newPosition;
        });
      }
    });
    _audioPlayer.setSourceUrl(widget.audioUrl);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isMe ? Colors.white : Colors.black87;
    final iconColor = widget.isMe ? Colors.white : widget.theme.primary;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(_isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, color: iconColor, size: 36),
          onPressed: () {
            if (_isPlaying) {
              _audioPlayer.pause();
            } else {
              _audioPlayer.play(UrlSource(widget.audioUrl));
            }
          },
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SliderTheme(
                data: SliderThemeData(
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  trackHeight: 3,
                  activeTrackColor: iconColor,
                  inactiveTrackColor: iconColor.withOpacity(0.3),
                  thumbColor: iconColor,
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                ),
                child: Slider(
                  min: 0,
                  max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1,
                  value: _position.inSeconds.toDouble().clamp(0, _duration.inSeconds.toDouble()),
                  onChanged: (value) {
                    _audioPlayer.seek(Duration(seconds: value.toInt()));
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  "${_formatDuration(_position)} / ${_formatDuration(_duration)}",
                  style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmojiStickerPicker extends StatefulWidget {
  final DeptTheme theme;
  final String uid;
  final ValueChanged<Emoji> onEmojiSelected;
  final ValueChanged<String> onStickerSelected;
  final VoidCallback onCreateSticker;

  const _EmojiStickerPicker({
    required this.theme,
    required this.uid,
    required this.onEmojiSelected,
    required this.onStickerSelected,
    required this.onCreateSticker,
  });

  @override
  State<_EmojiStickerPicker> createState() => _EmojiStickerPickerState();
}

class _EmojiStickerPickerState extends State<_EmojiStickerPicker> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280,
      child: Column(
        children: [
          Container(
            color: const Color(0xFFF5F7FF),
            child: TabBar(
              controller: _tabCtrl,
              indicatorColor: widget.theme.primary,
              labelColor: widget.theme.primary,
              unselectedLabelColor: Colors.grey.shade500,
              tabs: const [
                Tab(icon: Icon(Icons.emoji_emotions_outlined)),
                Tab(icon: Icon(Icons.sticky_note_2_outlined)),
                Tab(icon: Icon(Icons.gif_box_outlined)),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                // Tab 1: Emoji Picker
                EmojiPicker(
                  onEmojiSelected: (category, emoji) => widget.onEmojiSelected(emoji),
                  config: Config(
                    height: 250,
                    checkPlatformCompatibility: false,
                    emojiViewConfig: EmojiViewConfig(
                      backgroundColor: const Color(0xFFF5F7FF),
                      columns: 7,
                      emojiSizeMax: 28 * (defaultTargetPlatform == TargetPlatform.iOS ? 1.30 : 1.0),
                    ),
                    categoryViewConfig: CategoryViewConfig(
                      backgroundColor: const Color(0xFFF5F7FF),
                      indicatorColor: widget.theme.primary,
                      iconColorSelected: widget.theme.primary,
                      iconColor: Colors.grey,
                    ),
                    bottomActionBarConfig: const BottomActionBarConfig(
                      backgroundColor: Color(0xFFF5F7FF),
                      buttonIconColor: Colors.grey,
                      buttonColor: Colors.transparent,
                    ),
                  ),
                ),
                // Tab 2: Stickers
                Container(
                  color: const Color(0xFFF5F7FF),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.construction_rounded, size: 48, color: widget.theme.primary.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text(
                          'Stickers Coming Soon',
                          style: TextStyle(
                            color: widget.theme.primary.withOpacity(0.7),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Tab 3: GIFs (Giphy)
                _GiphyTab(onGifSelected: widget.onStickerSelected),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Full-screen Image Viewer with Hero animation and zoom
// ─────────────────────────────────────────────────────────────────────────────
class _FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String tag;
  const _FullScreenImageViewer({required this.imageUrl, required this.tag});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: Hero(
            tag: tag,
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (_, __) => const Center(child: CircularProgressIndicator(color: Colors.white)),
                errorWidget: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image_rounded, color: Colors.white54, size: 64),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Laugh Explosion Particle (Telegram-style with "HAH", "lol" texts)
// ─────────────────────────────────────────────────────────────────────────────
class _LaughParticle extends StatefulWidget {
  final String particleType;
  final int index;
  final int seed;
  final Offset center;
  final VoidCallback onComplete;

  const _LaughParticle({
    required this.particleType,
    required this.index,
    required this.seed,
    required this.center,
    required this.onComplete,
  });

  @override
  State<_LaughParticle> createState() => _LaughParticleState();
}

class _LaughParticleState extends State<_LaughParticle> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late double _dx;
  late double _dy;
  late double _rotation;
  late double _startSize;

  @override
  void initState() {
    super.initState();
    // Spread it out nicely around the center
    final angle = (widget.index / 8.0) * 3.14159 * 2;
    final spread = 70.0 + (widget.seed % 50);
    _dx = spread * math.cos(angle);
    _dy = spread * math.sin(angle) - 30; // slight bias upward
    _rotation = (widget.index - 4) * 0.35;
    _startSize = 32.0 + (widget.seed % 24);

    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _ctrl.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _buildParticleContent() {
    if (widget.particleType.contains('_')) {
      final parts = widget.particleType.split('_');
      final text = parts[0];
      final colorStr = parts[1];
      Color color;
      switch (colorStr) {
        case 'blue': color = const Color(0xFF2563EB); break;
        case 'orange': color = const Color(0xFFF97316); break;
        case 'red': color = const Color(0xFFDC2626); break;
        case 'pink': color = const Color(0xFFEC4899); break;
        case 'cyan': color = const Color(0xFF06B6D4); break;
        default: color = Colors.white;
      }
      
      return Stack(
        children: [
          Text(text, style: TextStyle(
            fontSize: _startSize * 0.9, 
            fontWeight: FontWeight.w900, 
            fontFamily: 'Comic Sans MS',
            letterSpacing: 1.5,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 5
              ..color = Colors.black87,
          )),
          Text(text, style: TextStyle(
            fontSize: _startSize * 0.9, 
            fontWeight: FontWeight.w900,
            fontFamily: 'Comic Sans MS',
            letterSpacing: 1.5,
            color: color,
          )),
        ],
      );
    } else {
      return Text(widget.particleType, style: TextStyle(fontSize: _startSize));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = _ctrl.value;
        final curve = Curves.easeOutCubic.transform(t);
        final opacity = (1.0 - Curves.easeIn.transform(t)).clamp(0.0, 1.0);
        final scale = 1.0 + curve * 0.5;
        
        return Positioned(
          left: widget.center.dx + _dx * curve - _startSize / 2,
          top: widget.center.dy + _dy * curve - _startSize / 2,
          child: Transform.rotate(
            angle: _rotation * curve,
            child: Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity,
                child: _buildParticleContent(),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Giphy GIFs Tab
// ─────────────────────────────────────────────────────────────────────────────
class _GiphyTab extends StatefulWidget {
  final ValueChanged<String> onGifSelected;
  const _GiphyTab({required this.onGifSelected});
  @override
  State<_GiphyTab> createState() => _GiphyTabState();
}

class _GiphyTabState extends State<_GiphyTab> {
  List<String> _gifs = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchGifs('');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchGifs(String query) async {
    setState(() => _loading = true);
    // Public key for Tenor
    const apiKey = 'LIVDSRZULELA';
    final url = query.isEmpty 
      ? 'https://g.tenor.com/v1/trending?key=$apiKey&limit=30'
      : 'https://g.tenor.com/v1/search?key=$apiKey&q=$query&limit=30';
      
    try {
      final res = await http.get(Uri.parse(url));
      final data = jsonDecode(res.body);
      final List gifs = data['results'];
      if (mounted) {
        setState(() {
          _gifs = gifs.map((g) => g['media'][0]['gif']['url'].toString()).toList();
          _loading = false;
        });
      }
    } catch(e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearch(String val) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      _fetchGifs(val);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F7FF),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearch,
                decoration: InputDecoration(
                  hintText: 'Rechercher un GIF...',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading 
              ? const Center(child: CircularProgressIndicator())
              : GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                  ),
                  itemCount: _gifs.length,
                  itemBuilder: (context, i) {
                    return GestureDetector(
                      onTap: () => widget.onGifSelected(_gifs[i]),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _gifs[i],
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Container(color: Colors.grey.shade300);
                          },
                          errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey.shade300, child: const Icon(Icons.error, color: Colors.grey)),
                        ),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}

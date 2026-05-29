import * as admin from "firebase-admin";
import * as functions from "firebase-functions";

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// ─────────────────────────────────────────────────────────────────────────────
// HELPER: Send FCM push to a single user by UID
// ─────────────────────────────────────────────────────────────────────────────
async function sendPushToUser(
  uid: string,
  title: string,
  body: string,
  data?: Record<string, string>
): Promise<void> {
  const snap = await db.collection("users").doc(uid).get();
  if (!snap.exists) return;

  const fcmToken = snap.data()?.fcmToken as string | undefined;
  if (!fcmToken) return;

  await messaging.send({
    token: fcmToken,
    notification: { title, body },
    data: data ?? {},
    android: {
      priority: "high",
      notification: {
        channelId: "esp_sekou_channel",
        priority: "high",
        defaultSound: true,
        clickAction: "FLUTTER_NOTIFICATION_CLICK",
      },
    },
    apns: {
      payload: {
        aps: {
          alert: { title, body },
          sound: "default",
          badge: 1,
        },
      },
    },
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// TRIGGER 1: New Broadcast → Push to ALL users
// ─────────────────────────────────────────────────────────────────────────────
export const onNewBroadcast = functions
  .region("europe-west1")
  .firestore.document("broadcasts/{broadcastId}")
  .onCreate(async (snap) => {
    const data = snap.data();
    const title = (data.title as string) || "ESP SEKOU";
    const text  = (data.text  as string) || "";
    const type  = (data.type  as string) || "general";

    const typeEmoji: Record<string, string> = {
      urgent: "🚨",
      event:  "📅",
      info:   "ℹ️",
      general: "📢",
    };

    const prefix = typeEmoji[type] ?? "📢";

    functions.logger.info(`New broadcast: ${title}`);

    // Fetch all users with FCM tokens
    const usersSnap = await db
      .collection("users")
      .where("fcmToken", "!=", "")
      .get();

    const tokens: string[] = [];
    usersSnap.docs.forEach((doc) => {
      const token = doc.data().fcmToken as string | undefined;
      if (token) tokens.push(token);
    });

    if (tokens.length === 0) {
      functions.logger.info("No FCM tokens found");
      return;
    }

    // Send multicast (max 500 per batch)
    const batchSize = 500;
    for (let i = 0; i < tokens.length; i += batchSize) {
      const batch = tokens.slice(i, i + batchSize);
      await messaging.sendEachForMulticast({
        tokens: batch,
        notification: {
          title: `${prefix} ${title}`,
          body: text.length > 100 ? text.substring(0, 100) + "…" : text,
        },
        data: { route: "/notifications", type },
        android: {
          priority: "high",
          notification: {
            channelId: "esp_sekou_channel",
            priority: "high",
            defaultSound: true,
          },
        },
        apns: {
          payload: {
            aps: {
              alert: {
                title: `${prefix} ${title}`,
                body: text.length > 100 ? text.substring(0, 100) + "…" : text,
              },
              sound: "default",
              badge: 1,
            },
          },
        },
      });
    }

    functions.logger.info(`Push sent to ${tokens.length} users`);
  });

// ─────────────────────────────────────────────────────────────────────────────
// TRIGGER 2: New Message → Push to recipient
// ─────────────────────────────────────────────────────────────────────────────
export const onNewMessage = functions
  .region("europe-west1")
  .firestore.document("conversations/{convId}/messages/{msgId}")
  .onCreate(async (snap, context) => {
    const msg = snap.data();
    const senderId   = msg.senderId  as string;
    const text       = msg.text      as string;
    const { convId } = context.params;

    // Get conversation to find recipient
    const convSnap = await db.collection("conversations").doc(convId).get();
    if (!convSnap.exists) return;

    const participants = convSnap.data()?.participantIds as string[] ?? [];
    const recipientId  = participants.find((id) => id !== senderId);
    if (!recipientId) return;

    // Get sender name
    const senderSnap = await db.collection("users").doc(senderId).get();
    const senderName = senderSnap.exists
      ? `${senderSnap.data()?.firstName ?? ""} ${senderSnap.data()?.lastName ?? ""}`.trim()
      : "ESP SEKOU";

    await sendPushToUser(
      recipientId,
      `💬 ${senderName}`,
      text.length > 80 ? text.substring(0, 80) + "…" : text,
      { route: `/chat/${convId}`, senderId }
    );
  });

// ─────────────────────────────────────────────────────────────────────────────
// TRIGGER 3: User locked → Push notification to user
// ─────────────────────────────────────────────────────────────────────────────
export const onUserLocked = functions
  .region("europe-west1")
  .firestore.document("users/{uid}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after  = change.after.data();

    if (!before.isLocked && after.isLocked) {
      // User just got locked
      await sendPushToUser(
        context.params.uid,
        "🔒 Compte verrouillé",
        "Ton compte ESP SEKOU a été suspendu par le Bureau. Contacte un administrateur.",
        { route: "/locked" }
      );
    } else if (before.isLocked && !after.isLocked) {
      // User got unlocked
      await sendPushToUser(
        context.params.uid,
        "🔓 Compte déverrouillé",
        "Ton compte ESP SEKOU a été réactivé. Bienvenue de retour !",
        { route: "/home" }
      );
    }
  });

// ─────────────────────────────────────────────────────────────────────────────
// SCHEDULED: Daily cleanup of old broadcasts (> 30 days)
// ─────────────────────────────────────────────────────────────────────────────
export const cleanupOldBroadcasts = functions
  .region("europe-west1")
  .pubsub.schedule("every 24 hours")
  .onRun(async () => {
    const cutoff = new Date();
    cutoff.setDate(cutoff.getDate() - 30);

    const old = await db
      .collection("broadcasts")
      .where("createdAt", "<", admin.firestore.Timestamp.fromDate(cutoff))
      .get();

    const batch = db.batch();
    old.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();

    functions.logger.info(`Deleted ${old.size} old broadcasts`);
  });

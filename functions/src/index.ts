import * as admin from "firebase-admin";
import { onDocumentCreated, onDocumentDeleted, onDocumentUpdated } from "firebase-functions/v2/firestore";

admin.initializeApp();

/** Notifie les membres et supprime toutes les sous-collections quand un groupe est supprimé. */
export const onGroupDeleted = onDocumentDeleted(
  "groups/{groupId}",
  async (event) => {
    const { groupId } = event.params;
    const db = admin.firestore();
    const groupRef = db.collection("groups").doc(groupId);

    // Données du groupe avant suppression (disponibles dans le snapshot)
    const groupData = event.data?.data();
    const groupName: string = groupData?.name ?? "le groupe";
    const memberIds: string[] = groupData?.memberIds ?? [];

    // ── 1. Notifier tous les membres ────────────────────────────────────────
    if (memberIds.length > 0) {
      const tokens: string[] = [];
      await Promise.all(
        memberIds.map(async (uid) => {
          try {
            const userDoc = await db.doc(`users/${uid}`).get();
            const token = userDoc.data()?.fcmToken;
            if (token) tokens.push(token);
          } catch {
            // skip — user doc missing or permission denied
          }
        })
      );

      if (tokens.length > 0) {
        await admin.messaging().sendEachForMulticast({
          tokens,
          notification: {
            title: groupName,
            body: "Le groupe a été supprimé.",
          },
          data: { groupId },
          android: {
            priority: "high",
          },
          apns: {
            payload: { aps: { sound: "default", threadId: groupId } },
          },
        });
      }
    }

    // ── 2. Supprimer toutes les sous-collections ─────────────────────────────
    const SUBCOLLECTIONS = ["members", "messages", "notes", "expenses", "events", "typing"];

    await Promise.all(
      SUBCOLLECTIONS.map(async (sub) => {
        const colRef = groupRef.collection(sub);
        // Supprime par batch de 500 (limite Firestore)
        let snap = await colRef.limit(500).get();
        while (!snap.empty) {
          const batch = db.batch();
          snap.docs.forEach((doc) => batch.delete(doc.ref));
          await batch.commit();
          snap = await colRef.limit(500).get();
        }
      })
    );
  }
);

/** Notifie un membre quand il est retiré d'un groupe. */
export const onMemberRemoved = onDocumentDeleted(
  "groups/{groupId}/members/{userId}",
  async (event) => {
    const { groupId, userId } = event.params;
    const db = admin.firestore();

    // Token FCM du membre retiré
    let token: string | undefined;
    try {
      const userDoc = await db.doc(`users/${userId}`).get();
      token = userDoc.data()?.fcmToken;
    } catch {
      return;
    }
    if (!token) return;

    // Nom du groupe
    const groupDoc = await db.doc(`groups/${groupId}`).get();
    const groupName: string = groupDoc.data()?.name ?? "le groupe";

    await admin.messaging().send({
      token,
      notification: {
        title: groupName,
        body: "Tu as été retiré du groupe.",
      },
      data: { groupId },
      android: {
        priority: "high",
      },
      apns: {
        payload: { aps: { sound: "default", threadId: groupId } },
      },
    });
  }
);

export const onNewMessage = onDocumentCreated(
  "groups/{groupId}/messages/{messageId}",
  async (event) => {
    const message = event.data?.data();
    if (!message) return;

    // Ne pas notifier les messages système (ex: "Bob a ajouté une dépense")
    if (message.type === "system") return;

    const { groupId } = event.params;

    // Récupère les membres du groupe
    const groupDoc = await admin
      .firestore()
      .doc(`groups/${groupId}`)
      .get();

    const groupName: string = groupDoc.data()?.name ?? "";
    const memberIds: string[] = groupDoc.data()?.memberIds ?? [];

    // Récupère les tokens FCM de chaque membre (sauf l'expéditeur)
    const tokens: string[] = [];
    await Promise.all(
      memberIds
        .filter((uid) => uid !== message.senderId)
        .map(async (uid) => {
          try {
            const userDoc = await admin.firestore().doc(`users/${uid}`).get();
            const token = userDoc.data()?.fcmToken;
            if (token) tokens.push(token);
          } catch {
            // skip — user doc missing or permission denied
          }
        })
    );

    console.log(`[onNewMessage] type="${message.type}" tokens=${tokens.length}`);
    if (tokens.length === 0) return;

    const senderName: string = message.senderName ?? "Quelqu'un";
    let body: string;
    if (message.type === "audio") {
      body = `${senderName} a envoyé un message vocal 🎤`;
    } else if (message.type === "poll") {
      body = `${senderName} a créé un sondage 📊`;
    } else if (message.type === "image") {
      body = `${senderName} a envoyé une photo 📷`;
    } else if (message.type === "file") {
      body = `${senderName} a envoyé une vidéo 🎥`;
    } else {
      const content: string = message.content ?? "";
      const preview = content.length > 80 ? content.substring(0, 80) + "…" : content;
      body = `${senderName}: ${preview}`;
    }

    await sendNotif(tokens, groupName, body, groupId, "chat");
  }
);

// ── Helpers ──────────────────────────────────────────────────────────────────

/** Récupère le pseudo du membre dans le groupe (displayName du sous-doc members).
 *  Fallback sur le displayName Firebase Auth si le doc membre est introuvable. */
async function getMemberPseudo(
  db: admin.firestore.Firestore,
  groupId: string,
  uid: string
): Promise<string> {
  try {
    const memberDoc = await db.doc(`groups/${groupId}/members/${uid}`).get();
    const pseudo = memberDoc.data()?.displayName;
    if (pseudo) return pseudo;
    const user = await admin.auth().getUser(uid);
    return user.displayName ?? "Quelqu'un";
  } catch {
    return "Quelqu'un";
  }
}

/** Récupère les tokens FCM de tous les membres du groupe, sauf excludeUid.
 *  Retourne aussi le nom du groupe (doc déjà chargé, pas de requête supplémentaire). */
async function getGroupTokens(
  db: admin.firestore.Firestore,
  groupId: string,
  excludeUid?: string
): Promise<{ tokens: string[]; groupName: string }> {
  const groupDoc = await db.doc(`groups/${groupId}`).get();
  const groupName: string = groupDoc.data()?.name ?? "";
  const memberIds: string[] = groupDoc.data()?.memberIds ?? [];
  const tokens = (await Promise.all(
    memberIds
      .filter((uid) => uid !== excludeUid)
      .map(async (uid) => {
        try {
          const userDoc = await db.doc(`users/${uid}`).get();
          return userDoc.data()?.fcmToken as string | undefined;
        } catch {
          return undefined;
        }
      })
  )).filter((t): t is string => !!t);
  return { tokens, groupName };
}

/** Récupère uniquement le nom du groupe. */
async function getGroupName(
  db: admin.firestore.Firestore,
  groupId: string
): Promise<string> {
  try {
    const groupDoc = await db.doc(`groups/${groupId}`).get();
    return groupDoc.data()?.name ?? "";
  } catch {
    return "";
  }
}

/** Envoie une notification multicast si la liste de tokens est non vide.
 *  title = nom du groupe, body = action de l'utilisateur. */
async function sendNotif(
  tokens: string[],
  groupName: string,
  body: string,
  groupId: string,
  screen: string
): Promise<void> {
  if (tokens.length === 0) return;
  try {
    await admin.messaging().sendEachForMulticast({
      tokens,
      notification: { title: groupName, body },
      data: { groupId, screen },
      android: {
        priority: "high",
      },
      apns: {
        payload: { aps: { sound: "default", threadId: groupId } },
      },
    });
  } catch (e) {
    console.error("[sendNotif] FCM error:", e);
  }
}

export const onExpenseUpdated = onDocumentUpdated(
  "groups/{groupId}/expenses/{expenseId}",
  async (event) => {
    const after = event.data?.after.data();
    if (!after) return;
    const { groupId } = event.params;
    const db = admin.firestore();

    // Notifier les membres de splitWith sauf celui qui a modifié
    const actorUid: string = after.updatedBy ?? after.paidBy ?? "";
    const splitWith: string[] = after.splitWith ?? [];
    const recipients = splitWith.filter((uid: string) => uid !== actorUid);
    if (recipients.length === 0) return;

    const [tokens, groupName] = await Promise.all([
      Promise.all(
        recipients.map(async (uid: string) => {
          try {
            const userDoc = await db.doc(`users/${uid}`).get();
            return userDoc.data()?.fcmToken as string | undefined;
          } catch {
            return undefined;
          }
        })
      ).then((ts) => ts.filter((t): t is string => !!t)),
      getGroupName(db, groupId),
    ]);

    const actorName = after.updatedBy
      ? await getMemberPseudo(db, groupId, after.updatedBy)
      : (after.paidByName ?? "Quelqu'un");
    await sendNotif(tokens, groupName, `${actorName} a modifié une dépense`, groupId, "expenses");
  }
);

// ── Événements ────────────────────────────────────────────────────────────────

export const onEventCreated = onDocumentCreated(
  "groups/{groupId}/events/{eventId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;
    const { groupId } = event.params;
    const db = admin.firestore();
    const createdBy: string = data.createdBy;
    const [{ tokens, groupName }, name] = await Promise.all([
      getGroupTokens(db, groupId, createdBy),
      data.creatorName ? Promise.resolve(data.creatorName) : getMemberPseudo(db, groupId, createdBy),
    ]);
    await sendNotif(tokens, groupName, `${name} a créé un événement`, groupId, "calendar");
  }
);

export const onEventUpdated = onDocumentUpdated(
  "groups/{groupId}/events/{eventId}",
  async (event) => {
    const after = event.data?.after.data();
    if (!after) return;
    const { groupId } = event.params;
    const db = admin.firestore();
    const actorUid: string = after.updatedBy ?? after.createdBy;
    const [{ tokens, groupName }, name] = await Promise.all([
      getGroupTokens(db, groupId, actorUid),
      getMemberPseudo(db, groupId, actorUid),
    ]);
    await sendNotif(tokens, groupName, `${name} a modifié un événement`, groupId, "calendar");
  }
);

export const onEventDeleted = onDocumentDeleted(
  "groups/{groupId}/events/{eventId}",
  async (event) => {
    const before = event.data?.data();
    if (!before) return;
    const { groupId } = event.params;
    const db = admin.firestore();
    const createdBy: string = before.createdBy;
    const [{ tokens, groupName }, name] = await Promise.all([
      getGroupTokens(db, groupId),
      before.creatorName ? Promise.resolve(before.creatorName) : getMemberPseudo(db, groupId, createdBy),
    ]);
    await sendNotif(tokens, groupName, `${name} a supprimé un événement`, groupId, "calendar");
  }
);

// ── Notes ─────────────────────────────────────────────────────────────────────

export const onNoteCreated = onDocumentCreated(
  "groups/{groupId}/notes/{noteId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;
    const { groupId } = event.params;
    const db = admin.firestore();
    const createdBy: string = data.createdBy;
    const [{ tokens, groupName }, name] = await Promise.all([
      getGroupTokens(db, groupId, createdBy),
      getMemberPseudo(db, groupId, createdBy),
    ]);
    await sendNotif(tokens, groupName, `${name} a créé une note`, groupId, "notes");
  }
);

export const onNoteUpdated = onDocumentUpdated(
  "groups/{groupId}/notes/{noteId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    // Ignorer les changements de checklist uniquement (cocher/décocher une case)
    const contentChanged = before.title !== after.title || before.content !== after.content;
    if (!contentChanged) return;

    const { groupId } = event.params;
    const db = admin.firestore();
    const actorUid: string = after.updatedBy ?? after.createdBy;
    const [{ tokens, groupName }, name] = await Promise.all([
      getGroupTokens(db, groupId, actorUid),
      getMemberPseudo(db, groupId, actorUid),
    ]);
    await sendNotif(tokens, groupName, `${name} a modifié une note`, groupId, "notes");
  }
);

export const onNoteDeleted = onDocumentDeleted(
  "groups/{groupId}/notes/{noteId}",
  async (event) => {
    const before = event.data?.data();
    if (!before) return;
    const { groupId } = event.params;
    const db = admin.firestore();
    const createdBy: string = before.createdBy;
    const [{ tokens, groupName }, name] = await Promise.all([
      getGroupTokens(db, groupId),
      getMemberPseudo(db, groupId, createdBy),
    ]);
    await sendNotif(tokens, groupName, `${name} a supprimé une note`, groupId, "notes");
  }
);

export const onMessageReaction = onDocumentUpdated(
  "groups/{groupId}/messages/{messageId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    const beforeReactions: Record<string, string[]> = before.reactions ?? {};
    const afterReactions: Record<string, string[]> = after.reactions ?? {};

    // Trouver le premier emoji qui a un nouvel UID ajouté
    let newEmoji: string | null = null;
    let reactorUid: string | null = null;

    for (const [emoji, uids] of Object.entries(afterReactions)) {
      const beforeUids: string[] = beforeReactions[emoji] ?? [];
      const added = (uids as string[]).filter((uid) => !beforeUids.includes(uid));
      if (added.length > 0) {
        newEmoji = emoji;
        reactorUid = added[0];
        break;
      }
    }

    // Pas de nouvelle réaction (ex: suppression)
    if (!newEmoji || !reactorUid) return;

    const recipientUid: string = after.senderId;
    if (!recipientUid) return;

    // Pas de notif si on réagit à son propre message
    if (reactorUid === recipientUid) return;

    const { groupId } = event.params;
    const db = admin.firestore();

    const [recipientDoc, reactorName, groupName] = await Promise.all([
      db.doc(`users/${recipientUid}`).get(),
      getMemberPseudo(db, groupId, reactorUid),
      getGroupName(db, groupId),
    ]);

    const token = recipientDoc.data()?.fcmToken;
    if (!token) return;

    await sendNotif(
      [token],
      groupName,
      `${reactorName} a réagi à ton message avec ${newEmoji}`,
      groupId,
      "chat"
    );
  }
);

export const onNewExpense = onDocumentCreated(
  "groups/{groupId}/expenses/{expenseId}",
  async (event) => {
    const expense = event.data?.data();
    if (!expense) return;

    const { groupId } = event.params;
    const db = admin.firestore();

    // Notifier tous les membres de splitWith sauf le payeur
    const splitWith: string[] = expense.splitWith ?? [];
    const paidBy: string = expense.paidBy ?? "";
    const recipients = splitWith.filter((uid) => uid !== paidBy);
    if (recipients.length === 0) return;

    const [tokens, groupName] = await Promise.all([
      Promise.all(
        recipients.map(async (uid) => {
          try {
            const userDoc = await db.doc(`users/${uid}`).get();
            return userDoc.data()?.fcmToken as string | undefined;
          } catch {
            return undefined;
          }
        })
      ).then((ts) => ts.filter((t): t is string => !!t)),
      getGroupName(db, groupId),
    ]);

    if (tokens.length === 0) return;

    const paidByName: string = expense.paidByName ?? "Quelqu'un";

    await sendNotif(tokens, groupName, `${paidByName} a ajouté une dépense`, groupId, "expenses");
  }
);

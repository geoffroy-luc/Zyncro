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
          const userDoc = await db.doc(`users/${uid}`).get();
          const token = userDoc.data()?.fcmToken;
          if (token) tokens.push(token);
        })
      );

      if (tokens.length > 0) {
        await admin.messaging().sendEachForMulticast({
          tokens,
          notification: {
            title: "Groupe supprimé",
            body: `Le groupe « ${groupName} » a été supprimé.`,
          },
          data: { groupId },
          android: { priority: "high" },
          apns: { payload: { aps: { sound: "default" } } },
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
    const userDoc = await db.doc(`users/${userId}`).get();
    const token = userDoc.data()?.fcmToken;
    if (!token) return;

    // Nom du groupe
    const groupDoc = await db.doc(`groups/${groupId}`).get();
    const groupName: string = groupDoc.data()?.name ?? "le groupe";

    await admin.messaging().send({
      token,
      notification: {
        title: "Retiré du groupe",
        body: `Tu as été retiré du groupe « ${groupName} ».`,
      },
      data: { groupId },
      android: { priority: "high" },
      apns: { payload: { aps: { sound: "default" } } },
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
          const userDoc = await admin.firestore().doc(`users/${uid}`).get();
          const token = userDoc.data()?.fcmToken;
          if (token) tokens.push(token);
        })
    );

    if (tokens.length === 0) return;

    let preview: string;
    if (message.type === "audio") {
      preview = "a envoyé un message vocal 🎤";
    } else if (message.type === "poll") {
      preview = "a créé un sondage 📊";
    } else {
      const content: string = message.content ?? "";
      preview = content.length > 80 ? content.substring(0, 80) + "…" : content;
    }

    await sendNotif(
      tokens,
      message.senderName ?? "Nouveau message",
      preview,
      groupId,
      "chat",
      groupName
    );
  }
);

// ── Helpers ──────────────────────────────────────────────────────────────────

/** Récupère le displayName Firebase Auth d'un utilisateur. */
async function getDisplayName(uid: string): Promise<string> {
  try {
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
  const tokens: string[] = [];
  await Promise.all(
    memberIds
      .filter((uid) => uid !== excludeUid)
      .map(async (uid) => {
        const userDoc = await db.doc(`users/${uid}`).get();
        const token = userDoc.data()?.fcmToken;
        if (token) tokens.push(token);
      })
  );
  return { tokens, groupName };
}

/** Récupère uniquement le nom du groupe. */
async function getGroupName(
  db: admin.firestore.Firestore,
  groupId: string
): Promise<string> {
  const groupDoc = await db.doc(`groups/${groupId}`).get();
  return groupDoc.data()?.name ?? "";
}

/** Envoie une notification multicast si la liste de tokens est non vide.
 *  Ajoute le nom du groupe dans le corps si fourni. */
async function sendNotif(
  tokens: string[],
  title: string,
  body: string,
  groupId: string,
  screen: string,
  groupName?: string
): Promise<void> {
  if (tokens.length === 0) return;
  const fullBody = groupName ? `${groupName} — ${body}` : body;
  await admin.messaging().sendEachForMulticast({
    tokens,
    notification: { title, body: fullBody },
    data: { groupId, screen },
    android: { priority: "high" },
    apns: { payload: { aps: { sound: "default" } } },
  });
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
          const userDoc = await db.doc(`users/${uid}`).get();
          return userDoc.data()?.fcmToken as string | undefined;
        })
      ).then((ts) => ts.filter((t): t is string => !!t)),
      getGroupName(db, groupId),
    ]);

    const actorName = after.updatedBy
      ? await getDisplayName(after.updatedBy)
      : (after.paidByName ?? "Quelqu'un");
    const title: string = after.title ?? "Dépense";
    const amount: number = after.amount ?? 0;
    await sendNotif(
      tokens,
      `${actorName} a modifié une dépense`,
      `${title} · ${amount.toFixed(2)} €`,
      groupId,
      "expenses",
      groupName
    );
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
      data.creatorName ? Promise.resolve(data.creatorName) : getDisplayName(createdBy),
    ]);
    await sendNotif(tokens, `${name} a créé un événement`, data.title ?? "Événement", groupId, "calendar", groupName);
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
      actorUid === after.createdBy
        ? Promise.resolve(after.creatorName ?? null).then((n) => n ?? getDisplayName(actorUid))
        : getDisplayName(actorUid),
    ]);
    await sendNotif(tokens, `${name} a modifié un événement`, after.title ?? "Événement", groupId, "calendar", groupName);
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
      before.creatorName ? Promise.resolve(before.creatorName) : getDisplayName(createdBy),
    ]);
    await sendNotif(tokens, `${name} a supprimé un événement`, before.title ?? "Événement", groupId, "calendar", groupName);
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
      getDisplayName(createdBy),
    ]);
    await sendNotif(tokens, `${name} a créé une note`, data.title ?? "Note", groupId, "notes", groupName);
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
      getDisplayName(actorUid),
    ]);
    await sendNotif(tokens, `${name} a modifié une note`, after.title ?? "Note", groupId, "notes", groupName);
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
      getDisplayName(createdBy),
    ]);
    await sendNotif(tokens, `${name} a supprimé une note`, before.title ?? "Note", groupId, "notes", groupName);
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
          const userDoc = await db.doc(`users/${uid}`).get();
          return userDoc.data()?.fcmToken as string | undefined;
        })
      ).then((ts) => ts.filter((t): t is string => !!t)),
      getGroupName(db, groupId),
    ]);

    if (tokens.length === 0) return;

    const paidByName: string = expense.paidByName ?? "Quelqu'un";
    const title: string = expense.title ?? "Nouvelle dépense";
    const amount: number = expense.amount ?? 0;

    await sendNotif(
      tokens,
      `${paidByName} a ajouté une dépense`,
      `${title} · ${amount.toFixed(2)} €`,
      groupId,
      "expenses",
      groupName
    );
  }
);

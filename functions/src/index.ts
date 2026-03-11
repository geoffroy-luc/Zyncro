import * as admin from "firebase-admin";
import { onDocumentCreated, onDocumentDeleted } from "firebase-functions/v2/firestore";

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

export const onNewMessage = onDocumentCreated(
  "groups/{groupId}/messages/{messageId}",
  async (event) => {
    const message = event.data?.data();
    if (!message) return;

    const { groupId } = event.params;

    // Récupère les membres du groupe
    const groupDoc = await admin
      .firestore()
      .doc(`groups/${groupId}`)
      .get();

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

    const content: string = message.content ?? "";
    const preview = content.length > 80 ? content.substring(0, 80) + "…" : content;

    await admin.messaging().sendEachForMulticast({
      tokens,
      notification: {
        title: message.senderName ?? "Nouveau message",
        body: preview,
      },
      data: {
        groupId,
      },
      android: {
        priority: "high",
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    });
  }
);

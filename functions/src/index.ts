import * as admin from "firebase-admin";
import { onDocumentCreated } from "firebase-functions/v2/firestore";

admin.initializeApp();

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

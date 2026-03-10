import * as admin from "firebase-admin";
import { onDocumentCreated } from "firebase-functions/v2/firestore";

admin.initializeApp();

export const onNewMessage = onDocumentCreated(
  "groups/{groupId}/messages/{messageId}",
  async (event) => {
    const message = event.data?.data();
    if (!message) return;

    const { groupId } = event.params;
    const isSystemMessage = message.type === "system";

    // Récupère le groupe (membres + nom)
    const groupDoc = await admin.firestore().doc(`groups/${groupId}`).get();
    const groupData = groupDoc.data();
    const memberIds: string[] = groupData?.memberIds ?? [];
    const groupName: string = groupData?.name ?? "Zyncro";

    // On exclut toujours l'expéditeur (qu'il s'agisse d'un message texte ou système)
    const excludeUid = message.senderId;

    // Collecte les tokens FCM
    const tokens: string[] = [];
    await Promise.all(
      memberIds
        .filter((uid) => uid !== excludeUid)
        .map(async (uid) => {
          const userDoc = await admin.firestore().doc(`users/${uid}`).get();
          const token = userDoc.data()?.fcmToken;
          if (token) tokens.push(token);
        })
    );

    if (tokens.length === 0) return;

    const content: string = message.content ?? "";
    const preview = content.length > 80 ? content.substring(0, 80) + "…" : content;

    // Titre et écran cible selon le type de message
    const title: string = isSystemMessage
      ? groupName
      : (message.senderName ?? "Nouveau message");
    const screen: string = isSystemMessage
      ? (message.notifScreen ?? "chat")
      : "chat";

    await admin.messaging().sendEachForMulticast({
      tokens,
      notification: {
        title,
        body: preview,
      },
      data: {
        groupId,
        screen,
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

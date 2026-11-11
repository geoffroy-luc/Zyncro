import { admin } from "../shared/firebase";

export const HIGH_IMPORTANCE_CHANNEL = "zyncro_high_importance";

/** Onglet ouvert au tap sur la notification (clé `screen` des données). */
export type NotificationScreen = "chat" | "expenses" | "notes" | "calendar";

/** Notification d'activité de groupe (multicast). title = nom du groupe,
 *  body = action de l'utilisateur. Ne fait rien si [tokens] est vide. */
export async function sendGroupNotification(
  tokens: string[],
  groupName: string,
  body: string,
  groupId: string,
  screen: NotificationScreen,
): Promise<void> {
  if (tokens.length === 0) return;
  await admin.messaging().sendEachForMulticast({
    tokens,
    notification: { title: groupName, body },
    data: { groupId, screen },
    android: {
      priority: "high",
      collapseKey: groupId,
      notification: { channelId: HIGH_IMPORTANCE_CHANNEL },
    },
    apns: {
      headers: { "apns-collapse-id": groupId },
      payload: { aps: { sound: "default", threadId: groupId } },
    },
  });
}

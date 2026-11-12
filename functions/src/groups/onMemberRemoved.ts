import { onDocumentDeleted } from "firebase-functions/v2/firestore";
import { admin, db } from "../shared/firebase";
import { asString } from "../shared/guards";
import { paths } from "../shared/paths";

/** Notifie un membre quand il est retiré d'un groupe.
 *  ⚠️ Déclenché aussi quand on quitte soi-même ou à la suppression du groupe
 *  (BUGS_FOUND G7, G8) — comportement conservé. */
export const onMemberRemoved = onDocumentDeleted("groups/{groupId}/members/{userId}", async (event) => {
  const { groupId, userId } = event.params;

  const userDoc = await db().doc(paths.user(userId)).get();
  const token = asString(userDoc.data()?.fcmToken);
  if (!token) return;

  const groupDoc = await db().doc(paths.group(groupId)).get();
  const groupName = asString(groupDoc.data()?.name) ?? "le groupe";

  await admin.messaging().send({
    token,
    notification: { title: groupName, body: "Tu as été retiré du groupe." },
    data: { groupId },
    android: {
      priority: "high",
      collapseKey: groupId,
      notification: { tag: groupId },
    },
    apns: {
      headers: { "apns-collapse-id": groupId },
      payload: { aps: { sound: "default", threadId: groupId } },
    },
  });
});

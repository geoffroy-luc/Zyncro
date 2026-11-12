import { onDocumentDeletedWithAuthContext } from "firebase-functions/v2/firestore";
import { admin, db } from "../shared/firebase";
import { asString } from "../shared/guards";
import { paths } from "../shared/paths";

/** Notifie un membre quand il est retiré d'un groupe.
 *  - BUG G8 corrigé : rien quand on quitte soi-même le groupe (l'auteur de
 *    la suppression est le membre lui-même) ;
 *  - BUG G7 corrigé : rien pendant la purge qui suit la suppression du
 *    groupe (le document du groupe n'existe plus ; « Le groupe a été
 *    supprimé » est déjà envoyé par onGroupDeleted). */
export const onMemberRemoved = onDocumentDeletedWithAuthContext(
  "groups/{groupId}/members/{userId}",
  async (event) => {
    const { groupId, userId } = event.params;
    if (event.authId === userId) return;

    const groupDoc = await db().doc(paths.group(groupId)).get();
    if (!groupDoc.exists) return;

    const userDoc = await db().doc(paths.user(userId)).get();
    const token = asString(userDoc.data()?.fcmToken);
    if (!token) return;

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
  },
);

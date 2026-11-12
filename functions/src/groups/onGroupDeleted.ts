import { onDocumentDeleted } from "firebase-functions/v2/firestore";
import { admin, db } from "../shared/firebase";
import { asString, asStringArray } from "../shared/guards";
import { getUsersTokens } from "../shared/members";
import { GROUP_SUBCOLLECTIONS, paths } from "../shared/paths";
import { HIGH_IMPORTANCE_CHANNEL } from "../notifications/fcm";

const BATCH_SIZE = 500; // limite Firestore par batch

/** Notifie les membres et supprime les sous-collections quand un groupe est
 *  supprimé. ⚠️ `config` et le Storage ne sont pas purgés (BUGS_FOUND G7). */
export const onGroupDeleted = onDocumentDeleted("groups/{groupId}", async (event) => {
  const { groupId } = event.params;
  const groupRef = db().doc(paths.group(groupId));

  // Données du groupe avant suppression (disponibles dans le snapshot)
  const groupData = event.data?.data();
  const groupName = asString(groupData?.name) ?? "le groupe";
  const memberIds = asStringArray(groupData?.memberIds);

  // ── 1. Notifier tous les membres ──────────────────────────────────────
  if (memberIds.length > 0) {
    const tokens = await getUsersTokens(memberIds);
    if (tokens.length > 0) {
      await admin.messaging().sendEachForMulticast({
        tokens,
        notification: { title: groupName, body: "Le groupe a été supprimé." },
        data: { groupId },
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
  }

  // ── 2. Supprimer les sous-collections, par batch ─────────────────────
  await Promise.all(
    GROUP_SUBCOLLECTIONS.map(async (sub) => {
      const colRef = groupRef.collection(sub);
      let snap = await colRef.limit(BATCH_SIZE).get();
      while (!snap.empty) {
        const batch = db().batch();
        snap.docs.forEach((doc) => batch.delete(doc.ref));
        await batch.commit();
        snap = await colRef.limit(BATCH_SIZE).get();
      }
    }),
  );
});

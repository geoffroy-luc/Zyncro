import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { sendGroupNotification } from "../notifications/fcm";
import { asString } from "../shared/guards";
import { getGroupTokens, getMemberPseudo } from "../shared/members";

/** ⚠️ Notifie à chaque mise à jour, sans comparer avant/après (BUGS_FOUND F2). */
export const onEventUpdated = onDocumentUpdated("groups/{groupId}/events/{eventId}", async (event) => {
  const after = event.data?.after.data();
  if (!after) return;
  const { groupId } = event.params;
  const actorUid = asString(after.updatedBy) ?? asString(after.createdBy) ?? "";
  const [{ tokens, groupName }, name] = await Promise.all([
    getGroupTokens(groupId, actorUid),
    getMemberPseudo(groupId, actorUid),
  ]);
  await sendGroupNotification(tokens, groupName, `${name} a modifié un événement`, groupId, "calendar");
});

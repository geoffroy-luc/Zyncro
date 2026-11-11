import { onDocumentDeleted } from "firebase-functions/v2/firestore";
import { sendGroupNotification } from "../notifications/fcm";
import { asString } from "../shared/guards";
import { getGroupTokens, getMemberPseudo } from "../shared/members";

/** ⚠️ Attribué au créateur (pas à l'auteur de la suppression) et notifie tout
 *  le groupe, auteur compris (BUGS_FOUND F1). */
export const onEventDeleted = onDocumentDeleted("groups/{groupId}/events/{eventId}", async (event) => {
  const before = event.data?.data();
  if (!before) return;
  const { groupId } = event.params;
  const createdBy = asString(before.createdBy) ?? "";
  const creatorName = asString(before.creatorName);
  const [{ tokens, groupName }, name] = await Promise.all([
    getGroupTokens(groupId),
    creatorName ? Promise.resolve(creatorName) : getMemberPseudo(groupId, createdBy),
  ]);
  await sendGroupNotification(tokens, groupName, `${name} a supprimé un événement`, groupId, "calendar");
});

import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { sendGroupNotification } from "../notifications/fcm";
import { sameContent } from "../shared/changes";
import { asString } from "../shared/guards";
import { getGroupTokens, getMemberPseudo } from "../shared/members";

/** BUG F2 corrigé : pas de notification si rien n'a changé hormis les
 *  méta-données d'écriture (`updatedBy`, `updatedAt`). */
export const onEventUpdated = onDocumentUpdated("groups/{groupId}/events/{eventId}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!after) return;
  if (before && sameContent(before, after)) return;
  const { groupId } = event.params;
  const actorUid = asString(after.updatedBy) ?? asString(after.createdBy) ?? "";
  const [{ tokens, groupName }, name] = await Promise.all([
    getGroupTokens(groupId, actorUid),
    getMemberPseudo(groupId, actorUid),
  ]);
  await sendGroupNotification(tokens, groupName, `${name} a modifié un événement`, groupId, "calendar");
});

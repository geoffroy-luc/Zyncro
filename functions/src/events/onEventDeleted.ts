import { onDocumentDeletedWithAuthContext } from "firebase-functions/v2/firestore";
import { sendGroupNotification } from "../notifications/fcm";
import { asString } from "../shared/guards";
import { getGroupTokens, getMemberPseudo, memberActor } from "../shared/members";

/** BUG F1 corrigé : attribué à l'auteur réel de la suppression, qui n'est pas
 *  notifié. Sans auteur connu (suppression serveur), comportement historique :
 *  attribué au créateur, tout le groupe notifié. */
export const onEventDeleted = onDocumentDeletedWithAuthContext(
  "groups/{groupId}/events/{eventId}",
  async (event) => {
    const before = event.data?.data();
    if (!before) return;
    const { groupId } = event.params;
    const actor = await memberActor(groupId, event.authId);
    const createdBy = asString(before.createdBy) ?? "";
    const creatorName = asString(before.creatorName);
    const [{ tokens, groupName }, name] = await Promise.all([
      getGroupTokens(groupId, actor),
      actor
        ? getMemberPseudo(groupId, actor)
        : creatorName
          ? Promise.resolve(creatorName)
          : getMemberPseudo(groupId, createdBy),
    ]);
    await sendGroupNotification(tokens, groupName, `${name} a supprimé un événement`, groupId, "calendar");
  },
);

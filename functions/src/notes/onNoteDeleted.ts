import { onDocumentDeletedWithAuthContext } from "firebase-functions/v2/firestore";
import { sendGroupNotification } from "../notifications/fcm";
import { asString } from "../shared/guards";
import { getGroupTokens, getMemberPseudo, memberActor } from "../shared/members";

/** BUG F1 corrigé : attribué à l'auteur réel de la suppression, qui n'est pas
 *  notifié. Sans auteur connu, comportement historique (créateur, tout le
 *  groupe). */
export const onNoteDeleted = onDocumentDeletedWithAuthContext(
  "groups/{groupId}/notes/{noteId}",
  async (event) => {
    const before = event.data?.data();
    if (!before) return;
    const { groupId } = event.params;
    const actor = await memberActor(groupId, event.authId);
    const createdBy = asString(before.createdBy) ?? "";
    const [{ tokens, groupName }, name] = await Promise.all([
      getGroupTokens(groupId, actor),
      getMemberPseudo(groupId, actor ?? createdBy),
    ]);
    await sendGroupNotification(tokens, groupName, `${name} a supprimé une note`, groupId, "notes");
  },
);

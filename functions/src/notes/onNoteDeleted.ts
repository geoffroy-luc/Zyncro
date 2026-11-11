import { onDocumentDeleted } from "firebase-functions/v2/firestore";
import { sendGroupNotification } from "../notifications/fcm";
import { asString } from "../shared/guards";
import { getGroupTokens, getMemberPseudo } from "../shared/members";

/** ⚠️ Attribué au créateur et notifie tout le groupe (BUGS_FOUND F1). */
export const onNoteDeleted = onDocumentDeleted("groups/{groupId}/notes/{noteId}", async (event) => {
  const before = event.data?.data();
  if (!before) return;
  const { groupId } = event.params;
  const createdBy = asString(before.createdBy) ?? "";
  const [{ tokens, groupName }, name] = await Promise.all([
    getGroupTokens(groupId),
    getMemberPseudo(groupId, createdBy),
  ]);
  await sendGroupNotification(tokens, groupName, `${name} a supprimé une note`, groupId, "notes");
});

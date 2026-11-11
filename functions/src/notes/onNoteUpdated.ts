import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { sendGroupNotification } from "../notifications/fcm";
import { asString } from "../shared/guards";
import { getGroupTokens, getMemberPseudo } from "../shared/members";

export const onNoteUpdated = onDocumentUpdated("groups/{groupId}/notes/{noteId}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return;

  // Ignorer les changements de checklist seuls (cocher / décocher une case)
  const contentChanged = before.title !== after.title || before.content !== after.content;
  if (!contentChanged) return;

  const { groupId } = event.params;
  const actorUid = asString(after.updatedBy) ?? asString(after.createdBy) ?? "";
  const [{ tokens, groupName }, name] = await Promise.all([
    getGroupTokens(groupId, actorUid),
    getMemberPseudo(groupId, actorUid),
  ]);
  await sendGroupNotification(tokens, groupName, `${name} a modifié une note`, groupId, "notes");
});

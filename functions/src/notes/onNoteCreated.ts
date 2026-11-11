import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { sendGroupNotification } from "../notifications/fcm";
import { asString } from "../shared/guards";
import { getGroupTokens, getMemberPseudo } from "../shared/members";

export const onNoteCreated = onDocumentCreated("groups/{groupId}/notes/{noteId}", async (event) => {
  const data = event.data?.data();
  if (!data) return;
  const { groupId } = event.params;
  const createdBy = asString(data.createdBy) ?? "";
  const [{ tokens, groupName }, name] = await Promise.all([
    getGroupTokens(groupId, createdBy),
    getMemberPseudo(groupId, createdBy),
  ]);
  await sendGroupNotification(tokens, groupName, `${name} a créé une note`, groupId, "notes");
});

import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { sendGroupNotification } from "../notifications/fcm";
import { asString, asStringArray } from "../shared/guards";
import { getGroupName, getMemberPseudo, getUsersTokens } from "../shared/members";

/** Notifie les participants (splitWith) sauf l'auteur de la modification. */
export const onExpenseUpdated = onDocumentUpdated("groups/{groupId}/expenses/{expenseId}", async (event) => {
  const after = event.data?.after.data();
  if (!after) return;
  const { groupId } = event.params;

  const updatedBy = asString(after.updatedBy);
  const actorUid = updatedBy ?? asString(after.paidBy) ?? "";
  const recipients = asStringArray(after.splitWith).filter((uid) => uid !== actorUid);
  if (recipients.length === 0) return;

  const [tokens, groupName] = await Promise.all([getUsersTokens(recipients), getGroupName(groupId)]);

  const actorName = updatedBy
    ? await getMemberPseudo(groupId, updatedBy)
    : (asString(after.paidByName) ?? "Quelqu'un");
  await sendGroupNotification(tokens, groupName, `${actorName} a modifié une dépense`, groupId, "expenses");
});

import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { sendGroupNotification } from "../notifications/fcm";
import { asString, asStringArray } from "../shared/guards";
import { getGroupName, getUsersTokens } from "../shared/members";

/** Notifie les participants (splitWith) sauf le payeur. */
export const onNewExpense = onDocumentCreated("groups/{groupId}/expenses/{expenseId}", async (event) => {
  const expense = event.data?.data();
  if (!expense) return;

  const { groupId } = event.params;
  const paidBy = asString(expense.paidBy) ?? "";
  const recipients = asStringArray(expense.splitWith).filter((uid) => uid !== paidBy);
  if (recipients.length === 0) return;

  const [tokens, groupName] = await Promise.all([getUsersTokens(recipients), getGroupName(groupId)]);
  if (tokens.length === 0) return;

  const paidByName = asString(expense.paidByName) ?? "Quelqu'un";
  await sendGroupNotification(tokens, groupName, `${paidByName} a ajouté une dépense`, groupId, "expenses");
});

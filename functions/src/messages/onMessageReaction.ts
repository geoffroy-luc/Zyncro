import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { sendGroupNotification } from "../notifications/fcm";
import { firstAddedReaction } from "../notifications/messages";
import { asReactions, asString } from "../shared/guards";
import { getGroupName, getMemberPseudo, getUsersTokens } from "../shared/members";

export const onMessageReaction = onDocumentUpdated("groups/{groupId}/messages/{messageId}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return;

  // Pas de nouvelle réaction (ex : suppression)
  const added = firstAddedReaction(asReactions(before.reactions), asReactions(after.reactions));
  if (!added) return;

  const recipientUid = asString(after.senderId);
  if (!recipientUid) return;

  // Pas de notification quand on réagit à son propre message
  if (added.reactorUid === recipientUid) return;

  const { groupId } = event.params;
  const [tokens, reactorName, groupName] = await Promise.all([
    getUsersTokens([recipientUid]),
    getMemberPseudo(groupId, added.reactorUid),
    getGroupName(groupId),
  ]);
  if (tokens.length === 0) return;

  await sendGroupNotification(
    tokens,
    groupName,
    `${reactorName} a réagi à ton message avec ${added.emoji}`,
    groupId,
    "chat",
  );
});

import { logger } from "firebase-functions/v2";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { sendGroupNotification } from "../notifications/fcm";
import { newMessageBody } from "../notifications/messages";
import { asString } from "../shared/guards";
import { getGroupTokens } from "../shared/members";

export const onNewMessage = onDocumentCreated("groups/{groupId}/messages/{messageId}", async (event) => {
  const message = event.data?.data();
  if (!message) return;

  // Pas de notification pour les messages système (« Bob a ajouté une dépense »)
  if (message.type === "system") return;

  const { groupId } = event.params;
  const { tokens, groupName } = await getGroupTokens(groupId, asString(message.senderId));

  logger.info(`[onNewMessage] type="${String(message.type)}" tokens=${tokens.length}`);
  if (tokens.length === 0) return;

  const senderName = asString(message.senderName) ?? "Quelqu'un";
  const body = newMessageBody(message.type, senderName, asString(message.content) ?? "");
  await sendGroupNotification(tokens, groupName, body, groupId, "chat");
});

import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { sendGroupNotification } from "../notifications/fcm";
import { asString } from "../shared/guards";
import { getGroupTokens, getMemberPseudo } from "../shared/members";

export const onEventCreated = onDocumentCreated("groups/{groupId}/events/{eventId}", async (event) => {
  const data = event.data?.data();
  if (!data) return;
  const { groupId } = event.params;
  const createdBy = asString(data.createdBy) ?? "";
  const creatorName = asString(data.creatorName);
  const [{ tokens, groupName }, name] = await Promise.all([
    getGroupTokens(groupId, createdBy),
    creatorName ? Promise.resolve(creatorName) : getMemberPseudo(groupId, createdBy),
  ]);
  await sendGroupNotification(tokens, groupName, `${name} a créé un événement`, groupId, "calendar");
});

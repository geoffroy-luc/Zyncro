// Point d'entrée des Cloud Functions : RÉ-EXPORTS UNIQUEMENT.
//
// ⚠️ Les noms d'export sont l'identité des functions déployées : en renommer
// un provoque une suppression puis une recréation (notifications perdues
// pendant la bascule). Ne pas les renommer sans plan de migration.

export { onGroupDeleted } from "./groups/onGroupDeleted";
export { onMemberRemoved } from "./groups/onMemberRemoved";
export { onNewMessage } from "./messages/onNewMessage";
export { onMessageReaction } from "./messages/onMessageReaction";
export { onNewExpense } from "./expenses/onNewExpense";
export { onExpenseUpdated } from "./expenses/onExpenseUpdated";
export { onEventCreated } from "./events/onEventCreated";
export { onEventUpdated } from "./events/onEventUpdated";
export { onEventDeleted } from "./events/onEventDeleted";
export { onNoteCreated } from "./notes/onNoteCreated";
export { onNoteUpdated } from "./notes/onNoteUpdated";
export { onNoteDeleted } from "./notes/onNoteDeleted";
export { joinGroupByCode } from "./invites/joinGroupByCode";
export { getInvitePreview } from "./invites/getInvitePreview";

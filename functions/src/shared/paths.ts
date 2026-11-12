// Chemins Firestore (identiques à ceux de l'app : zyncro/lib/core/firebase).

export const paths = {
  group: (groupId: string) => `groups/${groupId}`,
  member: (groupId: string, uid: string) => `groups/${groupId}/members/${uid}`,
  user: (uid: string) => `users/${uid}`,
} as const;

/** Sous-collections purgées à la suppression d'un groupe. */
export const GROUP_SUBCOLLECTIONS = ["members", "messages", "notes", "expenses", "events", "typing"] as const;

// Textes des notifications de messages (fonctions pures, testées).

const PREVIEW_MAX = 80;

/** Corps de la notification d'un nouveau message selon son type. */
export function newMessageBody(type: unknown, senderName: string, content: string): string {
  switch (type) {
    case "audio":
      return `${senderName} a envoyé un message vocal 🎤`;
    case "poll":
      return `${senderName} a créé un sondage 📊`;
    case "image":
      return `${senderName} a envoyé une photo 📷`;
    case "file":
      return `${senderName} a envoyé une vidéo 🎥`;
    default: {
      const preview = content.length > PREVIEW_MAX ? content.substring(0, PREVIEW_MAX) + "…" : content;
      return `${senderName}: ${preview}`;
    }
  }
}

/** Premier emoji ayant reçu un nouvel uid entre deux états de réactions. */
export function firstAddedReaction(
  before: Record<string, string[]>,
  after: Record<string, string[]>,
): { emoji: string; reactorUid: string } | null {
  for (const [emoji, uids] of Object.entries(after)) {
    const beforeUids = before[emoji] ?? [];
    const added = uids.filter((uid) => !beforeUids.includes(uid));
    if (added.length > 0) return { emoji, reactorUid: added[0] };
  }
  return null;
}

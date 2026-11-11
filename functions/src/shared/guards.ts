// Lecture typée des données de documents (écrites par les clients : jamais
// supposées valides).

export type DocData = Record<string, unknown>;

/** La valeur si c'est une chaîne, sinon undefined. */
export function asString(value: unknown): string | undefined {
  return typeof value === "string" ? value : undefined;
}

/** Les éléments chaînes d'un tableau (tableau vide si ce n'en est pas un). */
export function asStringArray(value: unknown): string[] {
  return Array.isArray(value) ? value.filter((v): v is string => typeof v === "string") : [];
}

/** Map emoji → liste d'uids (réactions / votes des messages). */
export function asReactions(value: unknown): Record<string, string[]> {
  if (value === null || typeof value !== "object") return {};
  const result: Record<string, string[]> = {};
  for (const [key, uids] of Object.entries(value as Record<string, unknown>)) {
    result[key] = asStringArray(uids);
  }
  return result;
}

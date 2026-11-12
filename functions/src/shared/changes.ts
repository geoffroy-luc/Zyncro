/** Égalité de contenu de deux documents, en ignorant les clés [ignored]
 *  (méta-données d'écriture). Ordre des clés indifférent ; les Timestamp
 *  Admin se comparent par leur sérialisation JSON (secondes, nanosecondes). */
export function sameContent(
  before: Record<string, unknown>,
  after: Record<string, unknown>,
  ignored: readonly string[] = ["updatedBy", "updatedAt"],
): boolean {
  return stable(strip(before, ignored)) === stable(strip(after, ignored));
}

function strip(doc: Record<string, unknown>, ignored: readonly string[]): Record<string, unknown> {
  return Object.fromEntries(Object.entries(doc).filter(([k]) => !ignored.includes(k)));
}

function stable(value: unknown): string {
  return JSON.stringify(value, (_key, v: unknown) =>
    v && typeof v === "object" && !Array.isArray(v)
      ? Object.fromEntries(
          Object.entries(v as Record<string, unknown>).sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0)),
        )
      : v,
  );
}

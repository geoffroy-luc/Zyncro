import { HttpsError } from "firebase-functions/v2/https";
import { db } from "./firebase";

/** Limitation de débit : au plus [max] appels par heure (fenêtre fixe) pour
 *  la clé [key] (`rate_limits/{key}`), en transaction. Lève
 *  `resource-exhausted` au-delà. */
export async function consumeAttempt(key: string, max: number): Promise<void> {
  const ref = db().doc(`rate_limits/${key}`);
  const now = Date.now();
  await db().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.data();
    const windowStart = typeof data?.windowStart === "number" ? data.windowStart : 0;
    const count = typeof data?.count === "number" ? data.count : 0;
    if (now - windowStart >= 3_600_000) {
      tx.set(ref, { windowStart: now, count: 1 });
      return;
    }
    if (count >= max) {
      throw new HttpsError("resource-exhausted", "Trop de tentatives, réessaie plus tard.");
    }
    tx.set(ref, { windowStart, count: count + 1 });
  });
}

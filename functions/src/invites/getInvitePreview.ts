import { logger } from "firebase-functions";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { db } from "../shared/firebase";
import { asString } from "../shared/guards";
import { paths } from "../shared/paths";
import { consumeAttempt } from "../shared/rateLimit";

/** Aperçu d'une invitation (écran « Tu as été invité·e à rejoindre … »).
 *
 *  Le nom et l'emoji viennent du document **actuel** de l'espace (lu avec
 *  l'Admin SDK : un non-membre ne peut pas le lire). La copie stockée dans
 *  `invite_codes` n'est écrite qu'à la création / régénération du code : elle
 *  ne suit pas un renommage (les rules interdisent de la modifier) et manque
 *  sur d'anciens codes. L'aperçu affichait alors « un espace Zyncro ».
 *
 *  Ne révèle rien de plus que `invite_codes`, déjà lisible par tout compte
 *  connecté ; limité à PREVIEWS_PER_HOUR appels par compte. */
export const PREVIEWS_PER_HOUR = 60;

export interface PreviewRequest {
  code?: unknown;
}

export interface PreviewResult {
  groupId: string | null;
  groupName: string | null;
  groupEmoji: string | null;
}

const NONE: PreviewResult = { groupId: null, groupName: null, groupEmoji: null };

export const getInvitePreview = onCall<PreviewRequest | null, Promise<PreviewResult>>(
  { enforceAppCheck: false },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Connexion requise.");
    const data: PreviewRequest = request.data ?? {};
    const code = (asString(data.code) ?? "").toUpperCase().trim();
    if (!/^[A-Z0-9]{6}$/.test(code)) {
      throw new HttpsError("invalid-argument", "Code d'invitation invalide.");
    }

    await consumeAttempt(`preview_${uid}`, PREVIEWS_PER_HOUR);

    const codeDoc = await db().doc(`invite_codes/${code}`).get();
    const invite = codeDoc.data();
    const groupId = asString(invite?.groupId);
    if (!codeDoc.exists || !groupId) return NONE;

    const groupDoc = await db().doc(paths.group(groupId)).get();
    if (!groupDoc.exists) {
      logger.info("[getInvitePreview] espace supprimé", { groupId });
      return NONE;
    }
    const group = groupDoc.data();
    return {
      groupId,
      groupName: asString(group?.name) ?? asString(invite?.groupName) ?? null,
      groupEmoji: asString(group?.emoji) ?? asString(invite?.groupEmoji) ?? null,
    };
  },
);

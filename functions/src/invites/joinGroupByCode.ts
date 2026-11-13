import { logger } from "firebase-functions";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";
import { asString } from "../shared/guards";
import { paths } from "../shared/paths";
import { consumeAttempt } from "../shared/rateLimit";

/** S3, phase 1 : adhésion à un espace par code, côté serveur.
 *
 *  Le client (release N) appelle cette fonction au lieu d'écrire lui-même
 *  `memberIds` et son document membre. Quand les anciennes versions auront
 *  disparu (hausse de `minimum_version`), les rules pourront retirer
 *  l'auto-ajout client (S3, phase 3) : seul ce code, après vérification du
 *  code d'invitation, ajoutera un membre.
 *
 *  - Code inconnu ou espace supprimé → `{ groupId: null }` (le client
 *    affiche « code invalide », comme avant).
 *  - Déjà membre → rien n'est écrit (BUG G5), pas de message d'arrivée.
 *  - Sinon : `memberIds`, document membre (`role: member`) et message
 *    système « 👋 X a rejoint le groupe », en un seul batch.
 *  - Limitation de débit : JOIN_ATTEMPTS_PER_HOUR tentatives par compte
 *    (énumération des codes).
 *  - App Check : enforcement en phase 3 (les tokens doivent d'abord être
 *    configurés dans la console et les anciennes versions retirées). */
export const JOIN_ATTEMPTS_PER_HOUR = 20;
const ENFORCE_APP_CHECK = false;

export interface JoinRequest {
  code?: unknown;
  displayName?: unknown;
  photoUrl?: unknown;
  showProfilePhoto?: unknown;
}

export interface JoinResult {
  groupId: string | null;
  alreadyMember: boolean;
}

export const joinGroupByCode = onCall<JoinRequest | null, Promise<JoinResult>>(
  { enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Connexion requise.");

    // `data` peut être null pour un client mal formé malgré le typage.
    const data: JoinRequest = request.data ?? {};
    const code = (asString(data.code) ?? "").toUpperCase().trim();
    if (!/^[A-Z0-9]{6}$/.test(code)) {
      throw new HttpsError("invalid-argument", "Code d'invitation invalide.");
    }
    const displayName = (asString(data.displayName) ?? "").trim();
    if (displayName.length === 0 || displayName.length > 50) {
      throw new HttpsError("invalid-argument", "Pseudo invalide.");
    }
    const rawPhoto = data.photoUrl;
    const photoUrl = typeof rawPhoto === "string" && rawPhoto.length <= 2048 ? rawPhoto : null;
    const showProfilePhoto = data.showProfilePhoto !== false;

    await consumeAttempt(`join_${uid}`, JOIN_ATTEMPTS_PER_HOUR);

    const codeDoc = await db().doc(`invite_codes/${code}`).get();
    const groupId = asString(codeDoc.data()?.groupId);
    if (!codeDoc.exists || !groupId) {
      logger.info("[joinGroupByCode] code inconnu");
      return { groupId: null, alreadyMember: false };
    }

    const groupRef = db().doc(paths.group(groupId));
    const groupDoc = await groupRef.get();
    if (!groupDoc.exists) {
      logger.info("[joinGroupByCode] espace supprimé", { groupId });
      return { groupId: null, alreadyMember: false };
    }

    const memberRef = db().doc(paths.member(groupId, uid));
    if ((await memberRef.get()).exists) return { groupId, alreadyMember: true };

    const batch = db().batch();
    batch.update(groupRef, { memberIds: FieldValue.arrayUnion(uid) });
    batch.set(memberRef, {
      uid,
      displayName,
      role: "member",
      joinedAt: FieldValue.serverTimestamp(),
      photoUrl: showProfilePhoto ? photoUrl : null,
      showProfilePhoto,
    });
    // Même forme que les messages système écrits par l'app (MessageMapper).
    batch.set(groupRef.collection("messages").doc(), {
      groupId,
      senderId: uid,
      senderName: null,
      content: `👋 ${displayName} a rejoint le groupe`,
      type: "system",
      timestamp: FieldValue.serverTimestamp(),
      notifScreen: "chat",
    });
    await batch.commit();
    return { groupId, alreadyMember: false };
  },
);

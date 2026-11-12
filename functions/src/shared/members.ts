import { admin, db } from "./firebase";
import { asString, asStringArray } from "./guards";
import { paths } from "./paths";

const SOMEONE = "Quelqu'un";

/** Pseudo du membre dans le groupe (displayName du doc members), avec repli
 *  sur le displayName Firebase Auth puis sur « Quelqu'un ». */
export async function getMemberPseudo(groupId: string, uid: string): Promise<string> {
  try {
    const memberDoc = await db().doc(paths.member(groupId, uid)).get();
    const pseudo = asString(memberDoc.data()?.displayName);
    if (pseudo) return pseudo;
    const user = await admin.auth().getUser(uid);
    return user.displayName ?? SOMEONE;
  } catch {
    return SOMEONE;
  }
}

/** Nom du groupe ("" si absent). */
export async function getGroupName(groupId: string): Promise<string> {
  const groupDoc = await db().doc(paths.group(groupId)).get();
  return asString(groupDoc.data()?.name) ?? "";
}

/** Tokens FCM des utilisateurs donnés (ceux sans token sont ignorés). */
export async function getUsersTokens(uids: string[]): Promise<string[]> {
  const tokens = await Promise.all(
    uids.map(async (uid) => {
      const userDoc = await db().doc(paths.user(uid)).get();
      return asString(userDoc.data()?.fcmToken);
    }),
  );
  return tokens.filter((t): t is string => !!t);
}

/** Tokens FCM de tous les membres du groupe sauf [excludeUid], et nom du
 *  groupe (doc déjà chargé : pas de requête supplémentaire). */
export async function getGroupTokens(
  groupId: string,
  excludeUid?: string,
): Promise<{ tokens: string[]; groupName: string }> {
  const groupDoc = await db().doc(paths.group(groupId)).get();
  const groupName = asString(groupDoc.data()?.name) ?? "";
  const memberIds = asStringArray(groupDoc.data()?.memberIds);
  const tokens = await getUsersTokens(memberIds.filter((uid) => uid !== excludeUid));
  return { tokens, groupName };
}

/** Auteur d'une écriture (trigger « WithAuthContext ») s'il est membre du
 *  groupe : `authId` n'est un uid que pour un utilisateur de l'app (pour un
 *  compte de service, c'est son e-mail). `undefined` sinon. */
export async function memberActor(groupId: string, authId: string | undefined): Promise<string | undefined> {
  if (!authId) return undefined;
  const groupDoc = await db().doc(paths.group(groupId)).get();
  return asStringArray(groupDoc.data()?.memberIds).includes(authId) ? authId : undefined;
}

// Harnais commun : environnement émulateur + reproduction EXACTE des écritures
// faites par l'app v1.1.3 (mêmes chemins, mêmes champs, mêmes batches).
// Source de chaque flux indiquée en commentaire (chemins relatifs à zyncro/lib/).
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { initializeTestEnvironment } from '@firebase/rules-unit-testing';
import {
  doc, collection, setDoc, writeBatch, arrayUnion, arrayRemove,
  serverTimestamp, Timestamp, updateDoc, deleteDoc, runTransaction, getDoc,
} from 'firebase/firestore';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..');

export async function createEnv() {
  return initializeTestEnvironment({
    projectId: 'demo-zyncro',
    firestore: {
      rules: readFileSync(resolve(root, 'firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
    storage: {
      rules: readFileSync(resolve(root, 'storage.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 9199,
    },
  });
}

/** Utilisateur authentifié (provider password par défaut, ou anonyme). */
export function as(env, uid, { anonymous = false } = {}) {
  return env.authenticatedContext(uid, {
    firebase: { sign_in_provider: anonymous ? 'anonymous' : 'password' },
  });
}

/**
 * Seed d'un groupe réaliste (rules désactivées) : owner + membres.
 * Retourne le groupId.
 */
export async function seedGroup(env, { groupId = 'g1', owner = 'alice', members = ['bob'], code = 'ABC234' } = {}) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, `groups/${groupId}`), {
      name: 'Famille', description: null, emoji: '🏠', photoUrl: null,
      memberIds: [owner, ...members], createdBy: owner,
      createdAt: Timestamp.now(), inviteCode: code,
    });
    for (const [uid, role] of [[owner, 'owner'], ...members.map((m) => [m, 'member'])]) {
      await setDoc(doc(db, `groups/${groupId}/members/${uid}`), {
        uid, displayName: uid, role, joinedAt: Timestamp.now(),
        photoUrl: null, showProfilePhoto: true,
      });
    }
    await setDoc(doc(db, `invite_codes/${code}`), { groupId, groupName: 'Famille', groupEmoji: '🏠' });
    await setDoc(doc(db, `groups/${groupId}/messages/m-alice`), {
      groupId, senderId: owner, senderName: owner, content: 'salut', type: 'text', timestamp: Timestamp.now(),
    });
    await setDoc(doc(db, `groups/${groupId}/messages/m-poll`), {
      groupId, senderId: owner, senderName: owner, type: 'poll', timestamp: Timestamp.now(),
      content: JSON.stringify({ question: 'Q ?', options: ['a', 'b'], multipleChoice: false }),
    });
  });
  return groupId;
}

// ── Flux v1.1.3 : groupes (features/groups/data/repositories/groups_repository.dart) ──

/** createGroup (l.25-71) : batch groupe + membre owner + code. */
export async function createGroup(db, uid, { groupId, code, name = 'Coloc', emoji = '🏡' }) {
  const groupRef = doc(db, `groups/${groupId}`);
  const batch = writeBatch(db);
  batch.set(groupRef, {
    name, description: null, emoji, photoUrl: null, memberIds: [uid],
    createdBy: uid, createdAt: Timestamp.now(), inviteCode: code,
  });
  batch.set(doc(db, `groups/${groupId}/members/${uid}`), {
    uid, displayName: uid, role: 'owner', joinedAt: serverTimestamp(),
    photoUrl: null, showProfilePhoto: true,
  });
  batch.set(doc(db, `invite_codes/${code}`), { groupId, groupName: name, groupEmoji: emoji });
  return batch.commit();
}

/** joinGroup (l.74-98) : arrayUnion + set du doc membre (sans merge). */
export async function joinGroup(db, uid, groupId) {
  const batch = writeBatch(db);
  batch.update(doc(db, `groups/${groupId}`), { memberIds: arrayUnion(uid) });
  batch.set(doc(db, `groups/${groupId}/members/${uid}`), {
    uid, displayName: uid, role: 'member', joinedAt: serverTimestamp(),
    photoUrl: null, showProfilePhoto: true,
  });
  return batch.commit();
}

/** removeMember (l.144-152) */
export async function removeMember(db, groupId, uid) {
  const batch = writeBatch(db);
  batch.update(doc(db, `groups/${groupId}`), { memberIds: arrayRemove(uid) });
  batch.delete(doc(db, `groups/${groupId}/members/${uid}`));
  return batch.commit();
}

/** leaveGroup (l.155-179) avec message système (timestamp serveur). */
export async function leaveGroup(db, groupId, uid) {
  const batch = writeBatch(db);
  batch.update(doc(db, `groups/${groupId}`), { memberIds: arrayRemove(uid) });
  batch.delete(doc(db, `groups/${groupId}/members/${uid}`));
  batch.set(doc(collection(db, `groups/${groupId}/messages`)), {
    groupId, senderId: uid, senderName: null, content: `${uid} a quitté le groupe`,
    type: 'system', timestamp: serverTimestamp(), notifScreen: 'chat',
  });
  return batch.commit();
}

/** transferOwnership (l.182-193) */
export async function transferOwnership(db, groupId, currentOwner, newOwner) {
  const batch = writeBatch(db);
  batch.update(doc(db, `groups/${groupId}`), { createdBy: newOwner });
  batch.update(doc(db, `groups/${groupId}/members/${newOwner}`), { role: 'owner' });
  batch.update(doc(db, `groups/${groupId}/members/${currentOwner}`), { role: 'member' });
  return batch.commit();
}

/** deleteGroup (l.196-203) */
export async function deleteGroup(db, groupId, code) {
  const batch = writeBatch(db);
  batch.delete(doc(db, `groups/${groupId}`));
  if (code) batch.delete(doc(db, `invite_codes/${code}`));
  return batch.commit();
}

/** generateInviteCode (l.218-240) */
export async function regenerateInviteCode(db, groupId, oldCode, newCode) {
  const batch = writeBatch(db);
  if (oldCode) batch.delete(doc(db, `invite_codes/${oldCode}`));
  batch.update(doc(db, `groups/${groupId}`), { inviteCode: newCode });
  batch.set(doc(db, `invite_codes/${newCode}`), { groupId, groupName: 'Famille', groupEmoji: '🏠' });
  return batch.commit();
}

/** updateGroupInfo (l.206-215) */
export function updateGroupInfo(db, groupId, name, description) {
  return updateDoc(doc(db, `groups/${groupId}`), { name, description });
}

/** updateMemberDisplayName (l.274-289) */
export function updateMemberDisplayName(db, groupId, uid, displayName) {
  return updateDoc(doc(db, `groups/${groupId}/members/${uid}`), { displayName });
}

// ── Messages (features/chat/data/repositories/messages_repository.dart) ──

export function messagePayload(groupId, uid, overrides = {}) {
  return {
    groupId, senderId: uid, senderName: uid, content: 'hello',
    type: 'text', timestamp: Timestamp.now(), ...overrides,
  };
}

export function sendMessage(db, groupId, uid, overrides = {}) {
  return setDoc(doc(collection(db, `groups/${groupId}/messages`)), messagePayload(groupId, uid, overrides));
}

/** sendSystemMessage (l.163-179) : senderName absent → null via toMap. */
export function sendSystemMessage(db, groupId, uid, content, notifScreen) {
  return setDoc(doc(collection(db, `groups/${groupId}/messages`)), {
    groupId, senderId: uid, senderName: null, content, type: 'system',
    timestamp: Timestamp.now(), notifScreen,
  });
}

/** toggleReaction (l.419-452) : transaction lecture puis update de `reactions`. */
export function toggleReaction(db, groupId, messageId, uid, emoji) {
  const ref = doc(db, `groups/${groupId}/messages/${messageId}`);
  return runTransaction(db, async (tx) => {
    const snap = await tx.get(ref);
    const reactions = { ...(snap.data()?.reactions ?? {}) };
    for (const k of Object.keys(reactions)) reactions[k] = reactions[k].filter((u) => u !== uid);
    reactions[emoji] = [...(reactions[emoji] ?? []), uid];
    for (const k of Object.keys(reactions)) if (reactions[k].length === 0) delete reactions[k];
    tx.update(ref, { reactions });
  });
}

/** markAsRead (l.358-377) */
export function markAsRead(db, groupId, uid, messageId) {
  return updateDoc(doc(db, `groups/${groupId}/members/${uid}`), {
    lastReadMessageId: messageId, lastReadAt: Timestamp.now(),
  });
}

export { doc, collection, setDoc, updateDoc, deleteDoc, getDoc, Timestamp, serverTimestamp, writeBatch, arrayUnion, arrayRemove };

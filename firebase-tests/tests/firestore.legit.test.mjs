// Flux LÉGITIMES de l'app v1.1.3 : tous doivent rester AUTORISÉS.
// Toute régression ici = clients en production cassés.
import { afterAll, beforeAll, beforeEach, describe, it } from 'vitest';
import { assertSucceeds } from '@firebase/rules-unit-testing';
import {
  createEnv, as, seedGroup, createGroup, joinGroup, removeMember, leaveGroup,
  transferOwnership, deleteGroup, regenerateInviteCode, updateGroupInfo,
  updateMemberDisplayName, sendMessage, sendSystemMessage, toggleReaction, markAsRead,
  doc, collection, setDoc, updateDoc, deleteDoc, getDoc, Timestamp, serverTimestamp,
  writeBatch,
} from './helpers.mjs';
import { getDocs, query, where, orderBy, limit } from 'firebase/firestore';

let env;
beforeAll(async () => { env = await createEnv(); });
afterAll(async () => { await env?.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await seedGroup(env);
});

const G = 'g1';
const ok = (p) => assertSucceeds(p);

describe('groupes & membres', () => {
  it('créer un groupe (batch groupe + membre owner + code)', async () => {
    await ok(createGroup(as(env, 'carol').firestore(), 'carol', { groupId: 'g2', code: 'XYZ789' }));
  });
  it('créer un groupe en invité (anonyme)', async () => {
    await ok(createGroup(as(env, 'anon1', { anonymous: true }).firestore(), 'anon1', { groupId: 'g3', code: 'ANO234' }));
  });
  it('résoudre un code (get invite_codes)', async () => {
    await ok(getDoc(doc(as(env, 'carol').firestore(), 'invite_codes/ABC234')));
  });
  it('rejoindre par code (non-membre)', async () => {
    const db = as(env, 'carol').firestore();
    await ok(getDoc(doc(db, 'invite_codes/ABC234')));
    await ok(joinGroup(db, 'carol', G));
    await ok(getDoc(doc(db, `groups/${G}`)));
    await ok(sendSystemMessage(db, G, 'carol', 'carol a rejoint le groupe', 'chat'));
  });
  it('re-rejoindre en étant déjà membre (comportement actuel conservé)', async () => {
    await ok(joinGroup(as(env, 'bob').firestore(), 'bob', G));
  });
  it('le propriétaire re-rejoint son propre groupe (comportement actuel conservé)', async () => {
    await ok(joinGroup(as(env, 'alice').firestore(), 'alice', G));
  });
  it('état incohérent hérité (dans memberIds sans doc membre) : re-rejoindre', async () => {
    await env.withSecurityRulesDisabled((ctx) => deleteDoc(doc(ctx.firestore(), `groups/${G}/members/bob`)));
    await ok(joinGroup(as(env, 'bob').firestore(), 'bob', G));
  });
  it('lister ses groupes (where memberIds arrayContains)', async () => {
    const db = as(env, 'bob').firestore();
    await ok(getDocs(query(collection(db, 'groups'), where('memberIds', 'array-contains', 'bob'))));
  });
  it('lire les membres', async () => {
    await ok(getDocs(collection(as(env, 'bob').firestore(), `groups/${G}/members`)));
  });
  it('quitter le groupe (membre) avec message système', async () => {
    await ok(leaveGroup(as(env, 'bob').firestore(), G, 'bob'));
  });
  it('le propriétaire retire un membre', async () => {
    await ok(removeMember(as(env, 'alice').firestore(), G, 'bob'));
  });
  it('le propriétaire transfère la propriété', async () => {
    await ok(transferOwnership(as(env, 'alice').firestore(), G, 'alice', 'bob'));
  });
  it('ancien propriétaire peut quitter après transfert', async () => {
    await ok(transferOwnership(as(env, 'alice').firestore(), G, 'alice', 'bob'));
    await ok(leaveGroup(as(env, 'alice').firestore(), G, 'alice'));
  });
  it('le propriétaire supprime le groupe (+ code)', async () => {
    await ok(deleteGroup(as(env, 'alice').firestore(), G, 'ABC234'));
  });
  it('régénérer le code (propriétaire)', async () => {
    await ok(regenerateInviteCode(as(env, 'alice').firestore(), G, 'ABC234', 'NEW234'));
  });
  it('régénérer le code (simple membre : pas de contrôle UI)', async () => {
    await ok(regenerateInviteCode(as(env, 'bob').firestore(), G, 'ABC234', 'NEW235'));
  });
  it('générer un premier code sans ancien code', async () => {
    await ok(regenerateInviteCode(as(env, 'alice').firestore(), G, null, 'NEW236'));
  });
  it('modifier nom/description', async () => {
    await ok(updateGroupInfo(as(env, 'alice').firestore(), G, 'Nouvelle', 'desc'));
  });
  it('modifier emoji et photoUrl du groupe (home_settings_screen.dart:139-199)', async () => {
    const db = as(env, 'alice').firestore();
    await ok(updateDoc(doc(db, `groups/${G}`), { emoji: '🎉' }));
    await ok(updateDoc(doc(db, `groups/${G}`), { photoUrl: 'https://x/y.jpg' }));
    await ok(updateDoc(doc(db, `groups/${G}`), { photoUrl: null }));
  });
  it('modifier son pseudo de groupe', async () => {
    await ok(updateMemberDisplayName(as(env, 'bob').firestore(), G, 'bob', 'Bobby'));
  });
  it('propagation photo de profil sur ses docs membres (user_profile_service.dart:117-139)', async () => {
    const db = as(env, 'bob').firestore();
    const batch = writeBatch(db);
    batch.update(doc(db, `groups/${G}/members/bob`), { photoUrl: 'https://p', showProfilePhoto: true });
    await ok(batch.commit());
  });
  it('markAsRead / markGroupAsRead', async () => {
    const db = as(env, 'bob').firestore();
    await ok(markAsRead(db, G, 'bob', 'm-alice'));
    await ok(updateDoc(doc(db, `groups/${G}/members/bob`), { lastReadAt: Timestamp.now() }));
  });
});

describe('messages', () => {
  const types = [
    ['texte', { content: 'hello' }],
    ['réponse', { content: 're', replyToId: 'm-alice', replyToSenderName: 'alice', replyToContent: 'salut' }],
    ['audio', { type: 'audio', content: JSON.stringify({ url: 'https://a', duration: 3 }) }],
    ['image', { type: 'image', content: JSON.stringify({ url: 'https://i', mimeType: 'image/jpeg' }) }],
    ['vidéo', { type: 'file', content: JSON.stringify({ url: 'https://v', mimeType: 'video/mp4' }) }],
    ['album', { type: 'image', content: JSON.stringify({ medias: [{ url: 'https://1', mimeType: 'image/jpeg' }] }) }],
    ['sondage', { type: 'poll', content: JSON.stringify({ question: 'Q', options: ['a', 'b'], multipleChoice: true }) }],
  ];
  for (const [label, payload] of types) {
    it(`envoyer : ${label}`, async () => {
      await ok(sendMessage(as(env, 'bob').firestore(), G, 'bob', payload));
    });
  }
  it('envoyer un message système (activité d\'une autre feature)', async () => {
    await ok(sendSystemMessage(as(env, 'bob').firestore(), G, 'bob', 'bob a ajouté une dépense', 'expenses'));
  });
  it('lire les 50 derniers + page précédente + médias + non-lus', async () => {
    const db = as(env, 'bob').firestore();
    const col = collection(db, `groups/${G}/messages`);
    await ok(getDocs(query(col, orderBy('timestamp', 'desc'), limit(50))));
    await ok(getDocs(query(col, orderBy('timestamp', 'desc'), where('timestamp', '<', Timestamp.now()), limit(50))));
    await ok(getDocs(query(col, where('type', 'in', ['image', 'file']))));
    await ok(getDocs(query(col, where('timestamp', '>', Timestamp.fromMillis(0)))));
  });
  it('éditer son message', async () => {
    await ok(updateDoc(doc(as(env, 'alice').firestore(), `groups/${G}/messages/m-alice`), {
      content: 'édité', editedAt: serverTimestamp(),
    }));
  });
  it('éditer son sondage (reset des votes)', async () => {
    await ok(updateDoc(doc(as(env, 'alice').firestore(), `groups/${G}/messages/m-poll`), {
      content: JSON.stringify({ question: 'Q2', options: ['a'], multipleChoice: false }),
      reactions: {}, editedAt: serverTimestamp(),
    }));
  });
  it('réagir au message d\'un autre', async () => {
    await ok(toggleReaction(as(env, 'bob').firestore(), G, 'm-alice', 'bob', '❤️'));
  });
  it('voter à un sondage d\'un autre', async () => {
    await ok(toggleReaction(as(env, 'bob').firestore(), G, 'm-poll', 'bob', '0'));
  });
  it('supprimer son message', async () => {
    await ok(deleteDoc(doc(as(env, 'alice').firestore(), `groups/${G}/messages/m-alice`)));
  });
  it('typing : écrire / effacer / lire', async () => {
    const db = as(env, 'bob').firestore();
    await ok(setDoc(doc(db, `groups/${G}/typing/bob`), { name: 'bob', updatedAt: serverTimestamp() }));
    await ok(getDocs(collection(db, `groups/${G}/typing`)));
    await ok(deleteDoc(doc(db, `groups/${G}/typing/bob`)));
  });
});

describe('dépenses / événements / notes', () => {
  const expense = (uid, extra = {}) => ({
    groupId: G, title: 'Courses', amount: 42.5, paidBy: uid, paidByName: uid,
    splitWith: ['alice', 'bob'], settled: false, category: 'Alimentation',
    date: Timestamp.now(), createdBy: uid, createdAt: Timestamp.now(),
    expenseType: 'expense', splitType: 'equal', ...extra,
  });
  it('dépense : créer, lister, modifier (par un autre membre), solder, supprimer', async () => {
    const bob = as(env, 'bob').firestore();
    const alice = as(env, 'alice').firestore();
    const ref = doc(collection(bob, `groups/${G}/expenses`));
    await ok(setDoc(ref, expense('bob', { splitAmounts: { alice: 20, bob: 22.5 }, splitType: 'amount' })));
    await ok(getDocs(query(collection(bob, `groups/${G}/expenses`), orderBy('date', 'desc'))));
    await ok(updateDoc(doc(alice, `groups/${G}/expenses/${ref.id}`), {
      ...expense('bob'), title: 'Courses 2', updatedBy: 'alice',
    }));
    await ok(updateDoc(doc(alice, `groups/${G}/expenses/${ref.id}`), { settled: true }));
    await ok(deleteDoc(doc(alice, `groups/${G}/expenses/${ref.id}`)));
  });
  it('dépense récurrente + remboursement', async () => {
    const bob = as(env, 'bob').firestore();
    await ok(setDoc(doc(collection(bob, `groups/${G}/expenses`)), expense('bob', {
      recurrence: { frequency: 'monthly', endType: 'count', count: 3 },
    })));
    await ok(setDoc(doc(collection(bob, `groups/${G}/expenses`)), expense('bob', {
      expenseType: 'reimbursement', splitType: 'amount', splitAmounts: { alice: 10 }, splitWith: ['alice'], category: null,
    })));
  });
  const event = (uid, extra = {}) => ({
    groupId: G, title: 'Dîner', description: null, startDate: Timestamp.now(), endDate: null,
    location: null, createdBy: uid, createdAt: Timestamp.now(), participantIds: [], ...extra,
  });
  it('événement : créer, lister, modifier (autre membre), supprimer', async () => {
    const bob = as(env, 'bob').firestore();
    const alice = as(env, 'alice').firestore();
    const ref = doc(collection(bob, `groups/${G}/events`));
    await ok(setDoc(ref, event('bob', { color: '#4F7CFF', recurrence: { frequency: 'weekly', endType: 'until', until: Timestamp.now() } })));
    await ok(getDocs(query(collection(bob, `groups/${G}/events`), orderBy('startDate'))));
    await ok(updateDoc(doc(alice, `groups/${G}/events/${ref.id}`), { ...event('bob'), title: 'Dîner 2', updatedBy: 'alice' }));
    await ok(deleteDoc(doc(alice, `groups/${G}/events/${ref.id}`)));
  });
  const note = (uid, extra = {}) => ({
    groupId: G, title: 'Liste', content: '', isPinned: false, color: null, isChecklist: true,
    checklist: [{ text: 'lait', done: false }], createdBy: uid,
    createdAt: Timestamp.now(), updatedAt: Timestamp.now(), ...extra,
  });
  it('note : créer, lister, modifier (autre membre), épingler, supprimer', async () => {
    const bob = as(env, 'bob').firestore();
    const alice = as(env, 'alice').firestore();
    const ref = doc(collection(bob, `groups/${G}/notes`));
    await ok(setDoc(ref, note('bob')));
    await ok(getDocs(query(collection(bob, `groups/${G}/notes`), orderBy('updatedAt', 'desc'))));
    await ok(updateDoc(doc(alice, `groups/${G}/notes/${ref.id}`), { ...note('bob'), title: 'Liste 2', updatedBy: 'alice' }));
    await ok(updateDoc(doc(alice, `groups/${G}/notes/${ref.id}`), { ...note('bob'), isPinned: true }));
    await ok(deleteDoc(doc(alice, `groups/${G}/notes/${ref.id}`)));
  });
});

describe('réglages, utilisateur, config', () => {
  it('tabSettings : lire et écrire (set merge)', async () => {
    const db = as(env, 'bob').firestore();
    await ok(getDoc(doc(db, `groups/${G}/config/tabSettings`)));
    await ok(setDoc(doc(db, `groups/${G}/config/tabSettings`), {
      customColors: ['#123456'], hiddenBaseColors: [], chatThemeColor: '#E85D75',
      expensesCurrency: 'EUR', expensesCategories: [{ name: 'X', iconKey: 'label', colorHex: '#4F7CFF' }],
      calendarDisplayMode: 'band', calendarCustomCategories: [], calendarFilters: { participantIds: [], recurrenceOnly: false, category: null },
      homePhotoUrl: null, chatBackgroundType: null, chatBackgroundValue: null,
    }, { merge: true }));
  });
  it('users/{uid} : token FCM, photo, préférence', async () => {
    const db = as(env, 'bob').firestore();
    await ok(setDoc(doc(db, 'users/bob'), { fcmToken: 't', updatedAt: serverTimestamp() }, { merge: true }));
    await ok(setDoc(doc(db, 'users/bob'), { photoUrl: 'https://p' }, { merge: true }));
    await ok(setDoc(doc(db, 'users/bob'), { showProfilePhoto: false }, { merge: true }));
    await ok(updateDoc(doc(db, 'users/bob'), { fcmToken: null }));
    await ok(getDoc(doc(db, 'users/bob')));
  });
  it('config/app_version lisible sans authentification', async () => {
    await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'config/app_version'), { minimum_version: '1.0.0' }));
    await ok(getDoc(doc(env.unauthenticatedContext().firestore(), 'config/app_version')));
  });
});

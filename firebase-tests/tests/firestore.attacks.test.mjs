// ATTAQUES : toutes doivent être REFUSÉES (cf. docs/refactor/AUDIT.md §10).
// Mallory = compte anonyme, membre d'aucun groupe. Bob = simple membre de g1.
import { afterAll, beforeAll, beforeEach, describe, it } from 'vitest';
import { assertFails } from '@firebase/rules-unit-testing';
import { getDocs, query, limit } from 'firebase/firestore';
import {
  createEnv, as, seedGroup, joinGroup, messagePayload,
  doc, collection, setDoc, updateDoc, deleteDoc, getDoc, Timestamp,
  writeBatch, arrayUnion, arrayRemove,
} from './helpers.mjs';

let env;
beforeAll(async () => { env = await createEnv(); });
afterAll(async () => { await env?.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await seedGroup(env);
});

const G = 'g1';
const ko = (p) => assertFails(p);
const mallory = () => as(env, 'mallory', { anonymous: true }).firestore();
const bob = () => as(env, 'bob').firestore();

describe('S-02 énumération des codes', () => {
  it('lister invite_codes', async () => {
    await ko(getDocs(collection(mallory(), 'invite_codes')));
    await ko(getDocs(query(collection(bob(), 'invite_codes'), limit(1))));
  });
});

describe('S-07 manipulation des codes', () => {
  it('créer un code pointant vers un groupe dont on n\'est pas membre', async () => {
    await ko(setDoc(doc(mallory(), 'invite_codes/EVIL22'), { groupId: G, groupName: 'Famille', groupEmoji: '🏠' }));
  });
  it('supprimer le code d\'un autre groupe', async () => {
    await ko(deleteDoc(doc(mallory(), 'invite_codes/ABC234')));
  });
  it('écraser un code existant', async () => {
    await ko(setDoc(doc(bob(), 'invite_codes/ABC234'), { groupId: 'autre', groupName: 'x', groupEmoji: null }));
  });
  it('ajouter des champs arbitraires à un code', async () => {
    await ko(setDoc(doc(bob(), 'invite_codes/NEW999'), { groupId: G, groupName: 'x', groupEmoji: null, admin: true }));
  });
});

describe('S-01 / S-03 adhésion et prise de contrôle', () => {
  it('créer son doc membre sans être dans memberIds', async () => {
    await ko(setDoc(doc(mallory(), `groups/${G}/members/mallory`), {
      uid: 'mallory', displayName: 'm', role: 'member', joinedAt: Timestamp.now(), photoUrl: null, showProfilePhoto: true,
    }));
  });
  it('rejoindre en se déclarant owner', async () => {
    const db = mallory();
    const batch = writeBatch(db);
    batch.update(doc(db, `groups/${G}`), { memberIds: arrayUnion('mallory') });
    batch.set(doc(db, `groups/${G}/members/mallory`), {
      uid: 'mallory', displayName: 'm', role: 'owner', joinedAt: Timestamp.now(), photoUrl: null, showProfilePhoto: true,
    });
    await ko(batch.commit());
  });
  it('non-membre : s\'ajouter ET modifier d\'autres champs', async () => {
    await ko(updateDoc(doc(mallory(), `groups/${G}`), { memberIds: arrayUnion('mallory'), createdBy: 'mallory' }));
    await ko(updateDoc(doc(mallory(), `groups/${G}`), { memberIds: ['mallory'] }));
    await ko(updateDoc(doc(mallory(), `groups/${G}`), { memberIds: arrayUnion('mallory'), name: 'pwned' }));
  });
  it('non-membre : ajouter quelqu\'un d\'autre', async () => {
    await ko(updateDoc(doc(mallory(), `groups/${G}`), { memberIds: arrayUnion('eve') }));
  });
  it('membre : se nommer propriétaire (createdBy)', async () => {
    await ko(updateDoc(doc(bob(), `groups/${G}`), { createdBy: 'bob' }));
  });
  it('membre : retirer un autre membre de memberIds', async () => {
    await ko(updateDoc(doc(bob(), `groups/${G}`), { memberIds: arrayRemove('alice') }));
  });
  it('membre : ajouter un tiers à memberIds', async () => {
    await ko(updateDoc(doc(bob(), `groups/${G}`), { memberIds: arrayUnion('eve') }));
  });
  it('membre : s\'auto-promouvoir owner dans son doc membre', async () => {
    await ko(updateDoc(doc(bob(), `groups/${G}/members/bob`), { role: 'owner' }));
    await ko(updateDoc(doc(bob(), `groups/${G}/members/bob`), { role: 'admin' }));
  });
  it('membre : modifier le doc membre d\'un autre', async () => {
    await ko(updateDoc(doc(bob(), `groups/${G}/members/alice`), { displayName: 'idiot' }));
    await ko(updateDoc(doc(bob(), `groups/${G}/members/alice`), { role: 'member' }));
  });
  it('membre : retirer un autre membre (delete doc)', async () => {
    await ko(deleteDoc(doc(bob(), `groups/${G}/members/alice`)));
  });
  it('membre : supprimer le groupe', async () => {
    await ko(deleteDoc(doc(bob(), `groups/${G}`)));
  });
  it('propriétaire : quitter sans transférer (groupe orphelin)', async () => {
    await ko(deleteDoc(doc(as(env, 'alice').firestore(), `groups/${G}/members/alice`)));
  });
  it('propriétaire : transférer à un non-membre', async () => {
    await ko(updateDoc(doc(as(env, 'alice').firestore(), `groups/${G}`), { createdBy: 'mallory' }));
  });
  it('chaîne complète de l\'audit (auto-ajout → lecture)', async () => {
    const db = mallory();
    await ko(setDoc(doc(db, `groups/${G}/members/mallory`), { uid: 'mallory', role: 'owner', displayName: 'x' }));
    await ko(getDocs(collection(db, `groups/${G}/messages`)));
    await ko(getDocs(collection(db, `groups/${G}/expenses`)));
    await ko(getDoc(doc(db, `groups/${G}`)));
  });
});

describe('S-04 messages', () => {
  it('usurper senderId', async () => {
    await ko(setDoc(doc(collection(bob(), `groups/${G}/messages`)), messagePayload(G, 'alice')));
  });
  it('message avec un groupId différent', async () => {
    await ko(setDoc(doc(collection(bob(), `groups/${G}/messages`)), { ...messagePayload(G, 'bob'), groupId: 'autre' }));
  });
  it('modifier le contenu du message d\'un autre', async () => {
    await ko(updateDoc(doc(bob(), `groups/${G}/messages/m-alice`), { content: 'faux' }));
  });
  it('réécrire l\'expéditeur ou l\'horodatage d\'un message', async () => {
    await ko(updateDoc(doc(as(env, 'alice').firestore(), `groups/${G}/messages/m-alice`), { senderId: 'bob' }));
    await ko(updateDoc(doc(bob(), `groups/${G}/messages/m-alice`), { timestamp: Timestamp.now(), reactions: {} }));
  });
  it('supprimer le message d\'un autre', async () => {
    await ko(deleteDoc(doc(bob(), `groups/${G}/messages/m-alice`)));
  });
  it('non-membre : envoyer un message', async () => {
    await ko(setDoc(doc(collection(mallory(), `groups/${G}/messages`)), messagePayload(G, 'mallory')));
  });
});

describe('S-08 validation des documents (mitigation D1)', () => {
  it('dépense malformée (amount non numérique)', async () => {
    await ko(setDoc(doc(collection(bob(), `groups/${G}/expenses`)), {
      groupId: G, title: 'x', amount: 'beaucoup', paidBy: 'bob', paidByName: 'bob', splitWith: [],
      settled: false, date: Timestamp.now(), createdBy: 'bob', createdAt: Timestamp.now(),
    }));
  });
  it('dépense créée au nom d\'un autre', async () => {
    await ko(setDoc(doc(collection(bob(), `groups/${G}/expenses`)), {
      groupId: G, title: 'x', amount: 1, paidBy: 'bob', paidByName: 'bob', splitWith: [],
      settled: false, date: Timestamp.now(), createdBy: 'alice', createdAt: Timestamp.now(),
    }));
  });
  it('événement sans startDate', async () => {
    await ko(setDoc(doc(collection(bob(), `groups/${G}/events`)), {
      groupId: G, title: 'x', createdBy: 'bob', createdAt: Timestamp.now(),
    }));
  });
  it('note avec titre non string', async () => {
    await ko(setDoc(doc(collection(bob(), `groups/${G}/notes`)), {
      groupId: G, title: 42, content: '', createdBy: 'bob', createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
    }));
  });
  it('document de config arbitraire', async () => {
    await ko(setDoc(doc(bob(), `groups/${G}/config/autre`), { x: 1 }));
  });
  it('message de type inconnu (casserait les anciens clients)', async () => {
    await ko(setDoc(doc(collection(bob(), `groups/${G}/messages`)), messagePayload(G, 'bob', { type: 'sticker' })));
  });
});

describe('non-membres : aucun accès', () => {
  for (const sub of ['messages', 'expenses', 'events', 'notes', 'members', 'typing', 'config']) {
    it(`lire ${sub}`, async () => {
      await ko(getDocs(collection(mallory(), `groups/${G}/${sub}`)));
    });
  }
  it('membre retiré : ne peut pas se ré-ajouter avec un rôle owner', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await updateDoc(doc(db, `groups/${G}`), { memberIds: ['alice'] });
      await deleteDoc(doc(db, `groups/${G}/members/bob`));
    });
    await ko(updateDoc(doc(bob(), `groups/${G}`), { memberIds: arrayUnion('bob'), createdBy: 'bob' }));
  });
});

// Limite connue (résiduelle jusqu'à S3, cf. PLAN) : un non-membre qui connaît un
// groupId peut encore s'ajouter comme simple membre via le flux joinGroup de la v1.1.3.
describe('résiduel documenté (S3)', () => {
  it.skip('non-membre connaissant le groupId : auto-adhésion simple (fermé en S3)', async () => {
    await ko(joinGroup(mallory(), 'mallory', G));
  });
});

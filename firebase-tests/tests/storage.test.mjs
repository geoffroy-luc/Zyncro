// Storage : flux légitimes v1.1.3 (AUTORISÉS) + attaques (REFUSÉES).
import { afterAll, beforeAll, beforeEach, describe, it } from 'vitest';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { ref, uploadString, uploadBytes, listAll, getBytes, getDownloadURL, deleteObject } from 'firebase/storage';
import { createEnv, as, seedGroup } from './helpers.mjs';

let env;
beforeAll(async () => { env = await createEnv(); });
afterAll(async () => { await env?.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.clearStorage();
  await seedGroup(env);
  await env.withSecurityRulesDisabled(async (ctx) => {
    const st = ctx.storage();
    await uploadString(ref(st, 'media/g1/m1.jpg'), 'IMG', 'raw', { contentType: 'image/jpeg' });
    await uploadString(ref(st, 'audio/g1/m2.m4a'), 'AUD', 'raw', { contentType: 'audio/m4a' });
    await uploadString(ref(st, 'group_photos/g1.jpg'), 'IMG', 'raw', { contentType: 'image/jpeg' });
    await uploadString(ref(st, 'chat_backgrounds/g1.jpg'), 'IMG', 'raw', { contentType: 'image/jpeg' });
    await uploadString(ref(st, 'profile_photos/alice.jpg'), 'IMG', 'raw', { contentType: 'image/jpeg' });
  });
});

const ok = (p) => assertSucceeds(p);
const ko = (p) => assertFails(p);
const st = (uid, anonymous = false) => as(env, uid, { anonymous }).storage();
const jpeg = { contentType: 'image/jpeg' };

describe('légitime (v1.1.3)', () => {
  it('membre : upload photo/vidéo/album + getDownloadURL (messages_repository.dart:218-308)', async () => {
    const s = st('bob');
    await ok(uploadString(ref(s, 'media/g1/abc.jpg'), 'IMG', 'raw', jpeg));
    await ok(uploadString(ref(s, 'media/g1/abc_0.mp4'), 'VID', 'raw', { contentType: 'video/mp4' }));
    await ok(getDownloadURL(ref(s, 'media/g1/abc.jpg')));
  });
  it('membre : upload audio (l.182-215)', async () => {
    const s = st('bob');
    await ok(uploadString(ref(s, 'audio/g1/abc.m4a'), 'AUD', 'raw', { contentType: 'audio/m4a' }));
    await ok(getDownloadURL(ref(s, 'audio/g1/abc.m4a')));
  });
  it('membre : lire les médias du groupe', async () => {
    await ok(getBytes(ref(st('bob'), 'media/g1/m1.jpg')));
    await ok(getBytes(ref(st('bob'), 'audio/g1/m2.m4a')));
  });
  it('membre : photo de groupe upload / url / suppression (home_settings_screen.dart:145-202)', async () => {
    const s = st('alice');
    await ok(uploadString(ref(s, 'group_photos/g1.jpg'), 'NEW', 'raw', jpeg));
    await ok(getDownloadURL(ref(s, 'group_photos/g1.jpg')));
    await ok(deleteObject(ref(s, 'group_photos/g1.jpg')));
  });
  it('non-membre connecté : lire la photo du groupe (aperçu d\'invitation, groups_repository.dart:257)', async () => {
    await ok(getDownloadURL(ref(st('carol'), 'group_photos/g1.jpg')));
  });
  it('membre : fond de chat (chat_settings_screen.dart:72-87)', async () => {
    const s = st('bob');
    await ok(uploadString(ref(s, 'chat_backgrounds/g1.jpg'), 'BG', 'raw', jpeg));
    await ok(getDownloadURL(ref(s, 'chat_backgrounds/g1.jpg')));
  });
  it('photo de profil : upload / lecture / suppression (user_profile_service.dart:42-147)', async () => {
    const s = st('bob');
    await ok(uploadString(ref(s, 'profile_photos/bob.jpg'), 'ME', 'raw', jpeg));
    await ok(getDownloadURL(ref(s, 'profile_photos/bob.jpg')));
    await ok(getDownloadURL(ref(st('carol'), 'profile_photos/alice.jpg')));
    await ok(deleteObject(ref(s, 'profile_photos/bob.jpg')));
  });
});

describe('attaques (AUDIT S-05)', () => {
  it('non-membre : lister / lire les médias d\'un groupe', async () => {
    const s = st('eve', true);
    await ko(listAll(ref(s, 'media/g1')));
    await ko(getBytes(ref(s, 'media/g1/m1.jpg')));
    await ko(getBytes(ref(s, 'audio/g1/m2.m4a')));
    await ko(getDownloadURL(ref(s, 'media/g1/m1.jpg')));
  });
  it('non-membre : uploader dans le Storage d\'un groupe', async () => {
    const s = st('eve', true);
    await ko(uploadString(ref(s, 'media/g1/x.jpg'), 'X', 'raw', jpeg));
    await ko(uploadString(ref(s, 'media/g999/x.jpg'), 'X', 'raw', jpeg));
    await ko(uploadString(ref(s, 'audio/g1/x.m4a'), 'X', 'raw', { contentType: 'audio/m4a' }));
  });
  it('non-membre : écraser / supprimer la photo ou le fond d\'un groupe', async () => {
    const s = st('eve', true);
    await ko(uploadString(ref(s, 'group_photos/g1.jpg'), 'PWN', 'raw', jpeg));
    await ko(deleteObject(ref(s, 'group_photos/g1.jpg')));
    await ko(uploadString(ref(s, 'chat_backgrounds/g1.jpg'), 'PWN', 'raw', jpeg));
    await ko(deleteObject(ref(s, 'chat_backgrounds/g1.jpg')));
  });
  it('lister les photos de groupe / de profil', async () => {
    await ko(listAll(ref(st('eve', true), 'group_photos')));
    await ko(listAll(ref(st('eve', true), 'profile_photos')));
  });
  it('photo de profil : type non image ou trop lourde', async () => {
    const s = st('eve', true);
    await ko(uploadString(ref(s, 'profile_photos/eve.jpg'), '<html>', 'raw', { contentType: 'text/html' }));
    await ko(uploadBytes(ref(s, 'profile_photos/eve.jpg'), new Uint8Array(6 * 1024 * 1024), jpeg));
  });
  it('photo de profil d\'un autre', async () => {
    await ko(uploadString(ref(st('eve', true), 'profile_photos/alice.jpg'), 'X', 'raw', jpeg));
  });
  it('média : mauvais type', async () => {
    await ko(uploadString(ref(st('bob'), 'media/g1/x.html'), '<html>', 'raw', { contentType: 'text/html' }));
  });
});

"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.onNewExpense = exports.onNoteDeleted = exports.onNoteUpdated = exports.onNoteCreated = exports.onEventDeleted = exports.onEventUpdated = exports.onEventCreated = exports.onExpenseUpdated = exports.onNewMessage = exports.onMemberRemoved = exports.onGroupDeleted = void 0;
const admin = require("firebase-admin");
const firestore_1 = require("firebase-functions/v2/firestore");
admin.initializeApp();
/** Notifie les membres et supprime toutes les sous-collections quand un groupe est supprimé. */
exports.onGroupDeleted = (0, firestore_1.onDocumentDeleted)("groups/{groupId}", async (event) => {
    var _a, _b, _c;
    const { groupId } = event.params;
    const db = admin.firestore();
    const groupRef = db.collection("groups").doc(groupId);
    // Données du groupe avant suppression (disponibles dans le snapshot)
    const groupData = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
    const groupName = (_b = groupData === null || groupData === void 0 ? void 0 : groupData.name) !== null && _b !== void 0 ? _b : "le groupe";
    const memberIds = (_c = groupData === null || groupData === void 0 ? void 0 : groupData.memberIds) !== null && _c !== void 0 ? _c : [];
    // ── 1. Notifier tous les membres ────────────────────────────────────────
    if (memberIds.length > 0) {
        const tokens = [];
        await Promise.all(memberIds.map(async (uid) => {
            var _a;
            const userDoc = await db.doc(`users/${uid}`).get();
            const token = (_a = userDoc.data()) === null || _a === void 0 ? void 0 : _a.fcmToken;
            if (token)
                tokens.push(token);
        }));
        if (tokens.length > 0) {
            await admin.messaging().sendEachForMulticast({
                tokens,
                notification: {
                    title: "Groupe supprimé",
                    body: `Le groupe « ${groupName} » a été supprimé.`,
                },
                data: { groupId },
                android: { priority: "high" },
                apns: { payload: { aps: { sound: "default" } } },
            });
        }
    }
    // ── 2. Supprimer toutes les sous-collections ─────────────────────────────
    const SUBCOLLECTIONS = ["members", "messages", "notes", "expenses", "events", "typing"];
    await Promise.all(SUBCOLLECTIONS.map(async (sub) => {
        const colRef = groupRef.collection(sub);
        // Supprime par batch de 500 (limite Firestore)
        let snap = await colRef.limit(500).get();
        while (!snap.empty) {
            const batch = db.batch();
            snap.docs.forEach((doc) => batch.delete(doc.ref));
            await batch.commit();
            snap = await colRef.limit(500).get();
        }
    }));
});
/** Notifie un membre quand il est retiré d'un groupe. */
exports.onMemberRemoved = (0, firestore_1.onDocumentDeleted)("groups/{groupId}/members/{userId}", async (event) => {
    var _a, _b, _c;
    const { groupId, userId } = event.params;
    const db = admin.firestore();
    // Token FCM du membre retiré
    const userDoc = await db.doc(`users/${userId}`).get();
    const token = (_a = userDoc.data()) === null || _a === void 0 ? void 0 : _a.fcmToken;
    if (!token)
        return;
    // Nom du groupe
    const groupDoc = await db.doc(`groups/${groupId}`).get();
    const groupName = (_c = (_b = groupDoc.data()) === null || _b === void 0 ? void 0 : _b.name) !== null && _c !== void 0 ? _c : "le groupe";
    await admin.messaging().send({
        token,
        notification: {
            title: "Retiré du groupe",
            body: `Tu as été retiré du groupe « ${groupName} ».`,
        },
        data: { groupId },
        android: { priority: "high" },
        apns: { payload: { aps: { sound: "default" } } },
    });
});
exports.onNewMessage = (0, firestore_1.onDocumentCreated)("groups/{groupId}/messages/{messageId}", async (event) => {
    var _a, _b, _c, _d, _e, _f, _g;
    const message = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
    if (!message)
        return;
    // Ne pas notifier les messages système (ex: "Bob a ajouté une dépense")
    if (message.type === "system")
        return;
    const { groupId } = event.params;
    // Récupère les membres du groupe
    const groupDoc = await admin
        .firestore()
        .doc(`groups/${groupId}`)
        .get();
    const groupName = (_c = (_b = groupDoc.data()) === null || _b === void 0 ? void 0 : _b.name) !== null && _c !== void 0 ? _c : "";
    const memberIds = (_e = (_d = groupDoc.data()) === null || _d === void 0 ? void 0 : _d.memberIds) !== null && _e !== void 0 ? _e : [];
    // Récupère les tokens FCM de chaque membre (sauf l'expéditeur)
    const tokens = [];
    await Promise.all(memberIds
        .filter((uid) => uid !== message.senderId)
        .map(async (uid) => {
        var _a;
        const userDoc = await admin.firestore().doc(`users/${uid}`).get();
        const token = (_a = userDoc.data()) === null || _a === void 0 ? void 0 : _a.fcmToken;
        if (token)
            tokens.push(token);
    }));
    if (tokens.length === 0)
        return;
    let preview;
    if (message.type === "audio") {
        preview = "a envoyé un message vocal 🎤";
    }
    else if (message.type === "poll") {
        preview = "a créé un sondage 📊";
    }
    else {
        const content = (_f = message.content) !== null && _f !== void 0 ? _f : "";
        preview = content.length > 80 ? content.substring(0, 80) + "…" : content;
    }
    await sendNotif(tokens, (_g = message.senderName) !== null && _g !== void 0 ? _g : "Nouveau message", preview, groupId, "chat", groupName);
});
// ── Helpers ──────────────────────────────────────────────────────────────────
/** Récupère le displayName Firebase Auth d'un utilisateur. */
async function getDisplayName(uid) {
    var _a;
    try {
        const user = await admin.auth().getUser(uid);
        return (_a = user.displayName) !== null && _a !== void 0 ? _a : "Quelqu'un";
    }
    catch (_b) {
        return "Quelqu'un";
    }
}
/** Récupère les tokens FCM de tous les membres du groupe, sauf excludeUid.
 *  Retourne aussi le nom du groupe (doc déjà chargé, pas de requête supplémentaire). */
async function getGroupTokens(db, groupId, excludeUid) {
    var _a, _b, _c, _d;
    const groupDoc = await db.doc(`groups/${groupId}`).get();
    const groupName = (_b = (_a = groupDoc.data()) === null || _a === void 0 ? void 0 : _a.name) !== null && _b !== void 0 ? _b : "";
    const memberIds = (_d = (_c = groupDoc.data()) === null || _c === void 0 ? void 0 : _c.memberIds) !== null && _d !== void 0 ? _d : [];
    const tokens = [];
    await Promise.all(memberIds
        .filter((uid) => uid !== excludeUid)
        .map(async (uid) => {
        var _a;
        const userDoc = await db.doc(`users/${uid}`).get();
        const token = (_a = userDoc.data()) === null || _a === void 0 ? void 0 : _a.fcmToken;
        if (token)
            tokens.push(token);
    }));
    return { tokens, groupName };
}
/** Récupère uniquement le nom du groupe. */
async function getGroupName(db, groupId) {
    var _a, _b;
    const groupDoc = await db.doc(`groups/${groupId}`).get();
    return (_b = (_a = groupDoc.data()) === null || _a === void 0 ? void 0 : _a.name) !== null && _b !== void 0 ? _b : "";
}
/** Envoie une notification multicast si la liste de tokens est non vide.
 *  Ajoute le nom du groupe dans le corps si fourni. */
async function sendNotif(tokens, title, body, groupId, screen, groupName) {
    if (tokens.length === 0)
        return;
    const fullBody = groupName ? `${groupName} — ${body}` : body;
    await admin.messaging().sendEachForMulticast({
        tokens,
        notification: { title, body: fullBody },
        data: { groupId, screen },
        android: { priority: "high" },
        apns: { payload: { aps: { sound: "default" } } },
    });
}
exports.onExpenseUpdated = (0, firestore_1.onDocumentUpdated)("groups/{groupId}/expenses/{expenseId}", async (event) => {
    var _a, _b, _c, _d, _e, _f, _g;
    const after = (_a = event.data) === null || _a === void 0 ? void 0 : _a.after.data();
    if (!after)
        return;
    const { groupId } = event.params;
    const db = admin.firestore();
    // Notifier les membres de splitWith sauf celui qui a modifié
    const actorUid = (_c = (_b = after.updatedBy) !== null && _b !== void 0 ? _b : after.paidBy) !== null && _c !== void 0 ? _c : "";
    const splitWith = (_d = after.splitWith) !== null && _d !== void 0 ? _d : [];
    const recipients = splitWith.filter((uid) => uid !== actorUid);
    if (recipients.length === 0)
        return;
    const [tokens, groupName] = await Promise.all([
        Promise.all(recipients.map(async (uid) => {
            var _a;
            const userDoc = await db.doc(`users/${uid}`).get();
            return (_a = userDoc.data()) === null || _a === void 0 ? void 0 : _a.fcmToken;
        })).then((ts) => ts.filter((t) => !!t)),
        getGroupName(db, groupId),
    ]);
    const actorName = after.updatedBy
        ? await getDisplayName(after.updatedBy)
        : ((_e = after.paidByName) !== null && _e !== void 0 ? _e : "Quelqu'un");
    const title = (_f = after.title) !== null && _f !== void 0 ? _f : "Dépense";
    const amount = (_g = after.amount) !== null && _g !== void 0 ? _g : 0;
    await sendNotif(tokens, `${actorName} a modifié une dépense`, `${title} · ${amount.toFixed(2)} €`, groupId, "expenses", groupName);
});
// ── Événements ────────────────────────────────────────────────────────────────
exports.onEventCreated = (0, firestore_1.onDocumentCreated)("groups/{groupId}/events/{eventId}", async (event) => {
    var _a, _b;
    const data = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
    if (!data)
        return;
    const { groupId } = event.params;
    const db = admin.firestore();
    const createdBy = data.createdBy;
    const [{ tokens, groupName }, name] = await Promise.all([
        getGroupTokens(db, groupId, createdBy),
        data.creatorName ? Promise.resolve(data.creatorName) : getDisplayName(createdBy),
    ]);
    await sendNotif(tokens, `${name} a créé un événement`, (_b = data.title) !== null && _b !== void 0 ? _b : "Événement", groupId, "calendar", groupName);
});
exports.onEventUpdated = (0, firestore_1.onDocumentUpdated)("groups/{groupId}/events/{eventId}", async (event) => {
    var _a, _b, _c, _d;
    const after = (_a = event.data) === null || _a === void 0 ? void 0 : _a.after.data();
    if (!after)
        return;
    const { groupId } = event.params;
    const db = admin.firestore();
    const actorUid = (_b = after.updatedBy) !== null && _b !== void 0 ? _b : after.createdBy;
    const [{ tokens, groupName }, name] = await Promise.all([
        getGroupTokens(db, groupId, actorUid),
        actorUid === after.createdBy
            ? Promise.resolve((_c = after.creatorName) !== null && _c !== void 0 ? _c : null).then((n) => n !== null && n !== void 0 ? n : getDisplayName(actorUid))
            : getDisplayName(actorUid),
    ]);
    await sendNotif(tokens, `${name} a modifié un événement`, (_d = after.title) !== null && _d !== void 0 ? _d : "Événement", groupId, "calendar", groupName);
});
exports.onEventDeleted = (0, firestore_1.onDocumentDeleted)("groups/{groupId}/events/{eventId}", async (event) => {
    var _a, _b;
    const before = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
    if (!before)
        return;
    const { groupId } = event.params;
    const db = admin.firestore();
    const createdBy = before.createdBy;
    const [{ tokens, groupName }, name] = await Promise.all([
        getGroupTokens(db, groupId),
        before.creatorName ? Promise.resolve(before.creatorName) : getDisplayName(createdBy),
    ]);
    await sendNotif(tokens, `${name} a supprimé un événement`, (_b = before.title) !== null && _b !== void 0 ? _b : "Événement", groupId, "calendar", groupName);
});
// ── Notes ─────────────────────────────────────────────────────────────────────
exports.onNoteCreated = (0, firestore_1.onDocumentCreated)("groups/{groupId}/notes/{noteId}", async (event) => {
    var _a, _b;
    const data = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
    if (!data)
        return;
    const { groupId } = event.params;
    const db = admin.firestore();
    const createdBy = data.createdBy;
    const [{ tokens, groupName }, name] = await Promise.all([
        getGroupTokens(db, groupId, createdBy),
        getDisplayName(createdBy),
    ]);
    await sendNotif(tokens, `${name} a créé une note`, (_b = data.title) !== null && _b !== void 0 ? _b : "Note", groupId, "notes", groupName);
});
exports.onNoteUpdated = (0, firestore_1.onDocumentUpdated)("groups/{groupId}/notes/{noteId}", async (event) => {
    var _a, _b, _c, _d;
    const before = (_a = event.data) === null || _a === void 0 ? void 0 : _a.before.data();
    const after = (_b = event.data) === null || _b === void 0 ? void 0 : _b.after.data();
    if (!before || !after)
        return;
    // Ignorer les changements de checklist uniquement (cocher/décocher une case)
    const contentChanged = before.title !== after.title || before.content !== after.content;
    if (!contentChanged)
        return;
    const { groupId } = event.params;
    const db = admin.firestore();
    const actorUid = (_c = after.updatedBy) !== null && _c !== void 0 ? _c : after.createdBy;
    const [{ tokens, groupName }, name] = await Promise.all([
        getGroupTokens(db, groupId, actorUid),
        getDisplayName(actorUid),
    ]);
    await sendNotif(tokens, `${name} a modifié une note`, (_d = after.title) !== null && _d !== void 0 ? _d : "Note", groupId, "notes", groupName);
});
exports.onNoteDeleted = (0, firestore_1.onDocumentDeleted)("groups/{groupId}/notes/{noteId}", async (event) => {
    var _a, _b;
    const before = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
    if (!before)
        return;
    const { groupId } = event.params;
    const db = admin.firestore();
    const createdBy = before.createdBy;
    const [{ tokens, groupName }, name] = await Promise.all([
        getGroupTokens(db, groupId),
        getDisplayName(createdBy),
    ]);
    await sendNotif(tokens, `${name} a supprimé une note`, (_b = before.title) !== null && _b !== void 0 ? _b : "Note", groupId, "notes", groupName);
});
exports.onNewExpense = (0, firestore_1.onDocumentCreated)("groups/{groupId}/expenses/{expenseId}", async (event) => {
    var _a, _b, _c, _d, _e, _f;
    const expense = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
    if (!expense)
        return;
    const { groupId } = event.params;
    const db = admin.firestore();
    // Notifier tous les membres de splitWith sauf le payeur
    const splitWith = (_b = expense.splitWith) !== null && _b !== void 0 ? _b : [];
    const paidBy = (_c = expense.paidBy) !== null && _c !== void 0 ? _c : "";
    const recipients = splitWith.filter((uid) => uid !== paidBy);
    if (recipients.length === 0)
        return;
    const [tokens, groupName] = await Promise.all([
        Promise.all(recipients.map(async (uid) => {
            var _a;
            const userDoc = await db.doc(`users/${uid}`).get();
            return (_a = userDoc.data()) === null || _a === void 0 ? void 0 : _a.fcmToken;
        })).then((ts) => ts.filter((t) => !!t)),
        getGroupName(db, groupId),
    ]);
    if (tokens.length === 0)
        return;
    const paidByName = (_d = expense.paidByName) !== null && _d !== void 0 ? _d : "Quelqu'un";
    const title = (_e = expense.title) !== null && _e !== void 0 ? _e : "Nouvelle dépense";
    const amount = (_f = expense.amount) !== null && _f !== void 0 ? _f : 0;
    await sendNotif(tokens, `${paidByName} a ajouté une dépense`, `${title} · ${amount.toFixed(2)} €`, groupId, "expenses", groupName);
});
//# sourceMappingURL=index.js.map
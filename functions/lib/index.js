"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.onNewExpense = exports.onMessageReaction = exports.onNoteDeleted = exports.onNoteUpdated = exports.onNoteCreated = exports.onEventDeleted = exports.onEventUpdated = exports.onEventCreated = exports.onExpenseUpdated = exports.onNewMessage = exports.onMemberRemoved = exports.onGroupDeleted = void 0;
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
                    title: groupName,
                    body: "Le groupe a été supprimé.",
                },
                data: { groupId },
                android: {
                    priority: "high",
                    collapseKey: groupId,
                    notification: { tag: groupId, channelId: "zyncro_high_importance" },
                },
                apns: {
                    headers: { "apns-collapse-id": groupId },
                    payload: { aps: { sound: "default", threadId: groupId } },
                },
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
            title: groupName,
            body: "Tu as été retiré du groupe.",
        },
        data: { groupId },
        android: {
            priority: "high",
            collapseKey: groupId,
            notification: { tag: groupId },
        },
        apns: {
            headers: { "apns-collapse-id": groupId },
            payload: { aps: { sound: "default", threadId: groupId } },
        },
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
    console.log(`[onNewMessage] type="${message.type}" tokens=${tokens.length}`);
    if (tokens.length === 0)
        return;
    const senderName = (_f = message.senderName) !== null && _f !== void 0 ? _f : "Quelqu'un";
    let body;
    if (message.type === "audio") {
        body = `${senderName} a envoyé un message vocal 🎤`;
    }
    else if (message.type === "poll") {
        body = `${senderName} a créé un sondage 📊`;
    }
    else if (message.type === "image") {
        body = `${senderName} a envoyé une photo 📷`;
    }
    else if (message.type === "file") {
        body = `${senderName} a envoyé une vidéo 🎥`;
    }
    else {
        const content = (_g = message.content) !== null && _g !== void 0 ? _g : "";
        const preview = content.length > 80 ? content.substring(0, 80) + "…" : content;
        body = `${senderName}: ${preview}`;
    }
    await sendNotif(tokens, groupName, body, groupId, "chat");
});
// ── Helpers ──────────────────────────────────────────────────────────────────
/** Récupère le pseudo du membre dans le groupe (displayName du sous-doc members).
 *  Fallback sur le displayName Firebase Auth si le doc membre est introuvable. */
async function getMemberPseudo(db, groupId, uid) {
    var _a, _b;
    try {
        const memberDoc = await db.doc(`groups/${groupId}/members/${uid}`).get();
        const pseudo = (_a = memberDoc.data()) === null || _a === void 0 ? void 0 : _a.displayName;
        if (pseudo)
            return pseudo;
        const user = await admin.auth().getUser(uid);
        return (_b = user.displayName) !== null && _b !== void 0 ? _b : "Quelqu'un";
    }
    catch (_c) {
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
 *  title = nom du groupe, body = action de l'utilisateur. */
async function sendNotif(tokens, groupName, body, groupId, screen) {
    if (tokens.length === 0)
        return;
    await admin.messaging().sendEachForMulticast({
        tokens,
        notification: { title: groupName, body },
        data: { groupId, screen },
        android: {
            priority: "high",
            collapseKey: groupId,
            notification: { tag: groupId, channelId: "zyncro_high_importance" },
        },
        apns: {
            headers: { "apns-collapse-id": groupId },
            payload: { aps: { sound: "default", threadId: groupId } },
        },
    });
}
exports.onExpenseUpdated = (0, firestore_1.onDocumentUpdated)("groups/{groupId}/expenses/{expenseId}", async (event) => {
    var _a, _b, _c, _d, _e;
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
        ? await getMemberPseudo(db, groupId, after.updatedBy)
        : ((_e = after.paidByName) !== null && _e !== void 0 ? _e : "Quelqu'un");
    await sendNotif(tokens, groupName, `${actorName} a modifié une dépense`, groupId, "expenses");
});
// ── Événements ────────────────────────────────────────────────────────────────
exports.onEventCreated = (0, firestore_1.onDocumentCreated)("groups/{groupId}/events/{eventId}", async (event) => {
    var _a;
    const data = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
    if (!data)
        return;
    const { groupId } = event.params;
    const db = admin.firestore();
    const createdBy = data.createdBy;
    const [{ tokens, groupName }, name] = await Promise.all([
        getGroupTokens(db, groupId, createdBy),
        data.creatorName ? Promise.resolve(data.creatorName) : getMemberPseudo(db, groupId, createdBy),
    ]);
    await sendNotif(tokens, groupName, `${name} a créé un événement`, groupId, "calendar");
});
exports.onEventUpdated = (0, firestore_1.onDocumentUpdated)("groups/{groupId}/events/{eventId}", async (event) => {
    var _a, _b;
    const after = (_a = event.data) === null || _a === void 0 ? void 0 : _a.after.data();
    if (!after)
        return;
    const { groupId } = event.params;
    const db = admin.firestore();
    const actorUid = (_b = after.updatedBy) !== null && _b !== void 0 ? _b : after.createdBy;
    const [{ tokens, groupName }, name] = await Promise.all([
        getGroupTokens(db, groupId, actorUid),
        getMemberPseudo(db, groupId, actorUid),
    ]);
    await sendNotif(tokens, groupName, `${name} a modifié un événement`, groupId, "calendar");
});
exports.onEventDeleted = (0, firestore_1.onDocumentDeleted)("groups/{groupId}/events/{eventId}", async (event) => {
    var _a;
    const before = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
    if (!before)
        return;
    const { groupId } = event.params;
    const db = admin.firestore();
    const createdBy = before.createdBy;
    const [{ tokens, groupName }, name] = await Promise.all([
        getGroupTokens(db, groupId),
        before.creatorName ? Promise.resolve(before.creatorName) : getMemberPseudo(db, groupId, createdBy),
    ]);
    await sendNotif(tokens, groupName, `${name} a supprimé un événement`, groupId, "calendar");
});
// ── Notes ─────────────────────────────────────────────────────────────────────
exports.onNoteCreated = (0, firestore_1.onDocumentCreated)("groups/{groupId}/notes/{noteId}", async (event) => {
    var _a;
    const data = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
    if (!data)
        return;
    const { groupId } = event.params;
    const db = admin.firestore();
    const createdBy = data.createdBy;
    const [{ tokens, groupName }, name] = await Promise.all([
        getGroupTokens(db, groupId, createdBy),
        getMemberPseudo(db, groupId, createdBy),
    ]);
    await sendNotif(tokens, groupName, `${name} a créé une note`, groupId, "notes");
});
exports.onNoteUpdated = (0, firestore_1.onDocumentUpdated)("groups/{groupId}/notes/{noteId}", async (event) => {
    var _a, _b, _c;
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
        getMemberPseudo(db, groupId, actorUid),
    ]);
    await sendNotif(tokens, groupName, `${name} a modifié une note`, groupId, "notes");
});
exports.onNoteDeleted = (0, firestore_1.onDocumentDeleted)("groups/{groupId}/notes/{noteId}", async (event) => {
    var _a;
    const before = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
    if (!before)
        return;
    const { groupId } = event.params;
    const db = admin.firestore();
    const createdBy = before.createdBy;
    const [{ tokens, groupName }, name] = await Promise.all([
        getGroupTokens(db, groupId),
        getMemberPseudo(db, groupId, createdBy),
    ]);
    await sendNotif(tokens, groupName, `${name} a supprimé une note`, groupId, "notes");
});
exports.onMessageReaction = (0, firestore_1.onDocumentUpdated)("groups/{groupId}/messages/{messageId}", async (event) => {
    var _a, _b, _c, _d, _e, _f;
    const before = (_a = event.data) === null || _a === void 0 ? void 0 : _a.before.data();
    const after = (_b = event.data) === null || _b === void 0 ? void 0 : _b.after.data();
    if (!before || !after)
        return;
    const beforeReactions = (_c = before.reactions) !== null && _c !== void 0 ? _c : {};
    const afterReactions = (_d = after.reactions) !== null && _d !== void 0 ? _d : {};
    // Trouver le premier emoji qui a un nouvel UID ajouté
    let newEmoji = null;
    let reactorUid = null;
    for (const [emoji, uids] of Object.entries(afterReactions)) {
        const beforeUids = (_e = beforeReactions[emoji]) !== null && _e !== void 0 ? _e : [];
        const added = uids.filter((uid) => !beforeUids.includes(uid));
        if (added.length > 0) {
            newEmoji = emoji;
            reactorUid = added[0];
            break;
        }
    }
    // Pas de nouvelle réaction (ex: suppression)
    if (!newEmoji || !reactorUid)
        return;
    const recipientUid = after.senderId;
    if (!recipientUid)
        return;
    // Pas de notif si on réagit à son propre message
    if (reactorUid === recipientUid)
        return;
    const { groupId } = event.params;
    const db = admin.firestore();
    const [recipientDoc, reactorName, groupName] = await Promise.all([
        db.doc(`users/${recipientUid}`).get(),
        getMemberPseudo(db, groupId, reactorUid),
        getGroupName(db, groupId),
    ]);
    const token = (_f = recipientDoc.data()) === null || _f === void 0 ? void 0 : _f.fcmToken;
    if (!token)
        return;
    await sendNotif([token], groupName, `${reactorName} a réagi à ton message avec ${newEmoji}`, groupId, "chat");
});
exports.onNewExpense = (0, firestore_1.onDocumentCreated)("groups/{groupId}/expenses/{expenseId}", async (event) => {
    var _a, _b, _c, _d;
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
    await sendNotif(tokens, groupName, `${paidByName} a ajouté une dépense`, groupId, "expenses");
});
//# sourceMappingURL=index.js.map
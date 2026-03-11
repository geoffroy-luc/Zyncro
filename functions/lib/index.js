"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.onNewMessage = exports.onGroupDeleted = void 0;
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
exports.onNewMessage = (0, firestore_1.onDocumentCreated)("groups/{groupId}/messages/{messageId}", async (event) => {
    var _a, _b, _c, _d, _e;
    const message = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
    if (!message)
        return;
    const { groupId } = event.params;
    // Récupère les membres du groupe
    const groupDoc = await admin
        .firestore()
        .doc(`groups/${groupId}`)
        .get();
    const memberIds = (_c = (_b = groupDoc.data()) === null || _b === void 0 ? void 0 : _b.memberIds) !== null && _c !== void 0 ? _c : [];
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
    const content = (_d = message.content) !== null && _d !== void 0 ? _d : "";
    const preview = content.length > 80 ? content.substring(0, 80) + "…" : content;
    await admin.messaging().sendEachForMulticast({
        tokens,
        notification: {
            title: (_e = message.senderName) !== null && _e !== void 0 ? _e : "Nouveau message",
            body: preview,
        },
        data: {
            groupId,
        },
        android: {
            priority: "high",
        },
        apns: {
            payload: {
                aps: {
                    sound: "default",
                },
            },
        },
    });
});
//# sourceMappingURL=index.js.map
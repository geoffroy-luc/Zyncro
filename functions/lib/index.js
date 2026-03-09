"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.onNewMessage = void 0;
const admin = require("firebase-admin");
const firestore_1 = require("firebase-functions/v2/firestore");
admin.initializeApp();
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
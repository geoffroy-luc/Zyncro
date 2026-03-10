"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.onNewMessage = void 0;
const admin = require("firebase-admin");
const firestore_1 = require("firebase-functions/v2/firestore");
admin.initializeApp();
exports.onNewMessage = (0, firestore_1.onDocumentCreated)("groups/{groupId}/messages/{messageId}", async (event) => {
    var _a, _b, _c, _d, _e, _f;
    const message = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
    if (!message)
        return;
    const { groupId } = event.params;
    const isSystemMessage = message.type === "system";
    // Récupère le groupe (membres + nom)
    const groupDoc = await admin.firestore().doc(`groups/${groupId}`).get();
    const groupData = groupDoc.data();
    const memberIds = (_b = groupData === null || groupData === void 0 ? void 0 : groupData.memberIds) !== null && _b !== void 0 ? _b : [];
    const groupName = (_c = groupData === null || groupData === void 0 ? void 0 : groupData.name) !== null && _c !== void 0 ? _c : "Zyncro";
    // On exclut toujours l'expéditeur (qu'il s'agisse d'un message texte ou système)
    const excludeUid = message.senderId;
    // Collecte les tokens FCM
    const tokens = [];
    await Promise.all(memberIds
        .filter((uid) => uid !== excludeUid)
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
    // Titre et écran cible selon le type de message
    const title = isSystemMessage
        ? groupName
        : ((_e = message.senderName) !== null && _e !== void 0 ? _e : "Nouveau message");
    const screen = isSystemMessage
        ? ((_f = message.notifScreen) !== null && _f !== void 0 ? _f : "chat")
        : "chat";
    await admin.messaging().sendEachForMulticast({
        tokens,
        notification: {
            title,
            body: preview,
        },
        data: {
            groupId,
            screen,
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
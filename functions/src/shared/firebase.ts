import * as admin from "firebase-admin";

// Initialisation unique de l'Admin SDK (importé par tous les triggers).
admin.initializeApp();

export { admin };

/** Instance Firestore (résolue à l'appel, comme dans la version d'origine). */
export function db(): admin.firestore.Firestore {
  return admin.firestore();
}

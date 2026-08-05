# Zyncro — Hébergement des liens d'invitation

Ce dossier héberge, via **Firebase Hosting**, la page de repli des liens
d'invitation ainsi que les fichiers de vérification des deep links.

Domaine : `https://zyncro-f5fdd.web.app` (et `.firebaseapp.com`).

## Contenu

| Fichier | Rôle |
|---|---|
| `public/invite.html` | Page ouverte sur `/i/CODE` quand l'app **n'est pas** installée : propose d'ouvrir l'app ou de la télécharger. |
| `public/index.html` | Page racine. |
| `public/.well-known/assetlinks.json` | Vérification **Android App Links** (`autoVerify`). |
| `public/.well-known/apple-app-site-association` | Vérification **iOS Universal Links**. |

## ⚠️ Avant de déployer

### 1. Empreinte Android (assetlinks.json)

Le fichier contient déjà les empreintes SHA-256 de :
- la clé de **debug** locale ;
- la clé d'**upload** locale (`zyncro-release.jks`).

👉 **Si l'app est distribuée via le Play Store avec _Play App Signing_**, il faut
AUSSI ajouter l'empreinte du certificat de signature Google :
`Play Console → (ton app) → Test et publication → Intégrité de l'app →
Certificat de la clé de signature de l'app → SHA-256`.
Copie cette valeur dans `sha256_cert_fingerprints`. Sans elle, la vérification
automatique échoue pour les installations issues du Play Store.

### 2. URL App Store (invite.html)

Remplace `APP_STORE_URL` (`id0000000000`) par l'identifiant réel de la fiche
App Store une fois l'app publiée sur iOS.

### 3. iOS — capability Associated Domains

Dans Xcode : cible **Runner → Signing & Capabilities → + Capability →
Associated Domains** (les domaines sont déjà déclarés dans
`ios/Runner/Runner.entitlements`). Nécessaire pour que les Universal Links
soient reconnus.

## Déploiement

```bash
# Depuis le dossier zyncro/
firebase deploy --only hosting
```

## Vérification

- **Android** : `https://zyncro-f5fdd.web.app/.well-known/assetlinks.json`
  doit être servi en `application/json`. Test :
  `adb shell pm verify-app-links --re-verify com.zyncro.app` puis
  `adb shell pm get-app-links com.zyncro.app`.
- **iOS** : `https://zyncro-f5fdd.web.app/.well-known/apple-app-site-association`
  doit être servi en `application/json` (déjà forcé dans `firebase.json`).
  La vérification peut prendre quelques minutes après installation.

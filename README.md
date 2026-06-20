# ESP SEKOU

**Plateforme d'intégration des Sekou de l'ESP UCAD Dakar.**

ESP SEKOU est une application mobile et web (Flutter) destinée aux **« Sekou »** — les nouveaux admis de l'École Supérieure Polytechnique (ESP) de l'UCAD, Dakar. Elle facilite leur intégration : se présenter, se connaître entre départements et commissions, échanger, découvrir la culture commune (chants, valeurs, serment) et rester informé via les annonces du Bureau.

> Disponible en **Web**, **Android** et **iOS** à partir d'une base de code unique.

---

## ✨ Fonctionnalités

- **Authentification Google + cycle de validation.** Connexion via Google Sign-In, puis création de profil. Chaque compte doit être **validé par le Bureau** (`isApproved`) avant d'accéder à l'app, en passant par une étape de **valeurs** et de **serment**. Les comptes peuvent être **verrouillés** (`isLocked`) par un administrateur. Trois rôles : `user`, `admin`, `super-admin`.
- **Annuaire & profils.** Membres organisés par **département** (Génie Informatique, Génie Civil, Génie Électrique, Génie Mécanique, Génie Chimique et Biologie Appliquée, Gestion) et par **commission** (Organisation, Communication, Santé, Culturel, Cuisine, + Deureudj). Profil avec photo, alias, bio, hobbies, rôle au Bureau.
- **Messagerie 1:1.** Conversations privées entre membres, avec **notification push** à la réception d'un message.
- **Classement & gamification.** Système de **points** (`InteractionStats`) qui valorise notamment les **interactions inter-départements**, avec badges, pour encourager le brassage entre les Sekou.
- **Boîte à idées.** Soumission d'idées par les membres, **votes**, et suivi de statut (`pending` → `planned` → `implemented`).
- **Espace culturel.** **Lecteur audio immersif** des chants communautaires et de département, avec affichage des paroles.



- **Annonces (broadcasts) & notifications push.** Le Bureau diffuse des annonces (urgent / événement / info / général) envoyées en push à tous les membres.
- **Dashboard admin.** Validation des nouveaux membres, verrouillage/déverrouillage de comptes, gestion de la configuration.
- **Configuration distante.** Activation/désactivation à distance de fonctionnalités (chat, classement, espace culturel, annonces, valeurs, serment), logos de départements et liens WhatsApp des commissions — sans redéploiement.

---

## 🧱 Stack technique

| Domaine | Technologie |
|---|---|
| Framework | Flutter (≥ 3.22) / Dart (≥ 3.4) |
| State management | Riverpod + flutter_hooks |
| Navigation | go_router |
| Backend | Firebase — Auth, Cloud Firestore, Storage, Cloud Functions (region `europe-west1`) |
| Temps réel | Supabase (realtime) |
| Upload d'images | Cloudinary |
| Notifications push | OneSignal + Firebase Cloud Messaging (via Cloud Functions) |
| Audio | just_audio |

---

## 📁 Structure du projet

```
lib/
├── main.dart              # Point d'entrée (init Firebase, Supabase, OneSignal)
├── core/
│   ├── constants.dart     # Départements, commissions, constantes
│   ├── router/            # Routing go_router + logique de redirection (auth/approval/lock)
│   ├── theme/             # Thèmes par département
│   └── services/          # Cloudinary, notifications, realtime bus, interop web
├── features/              # Un dossier par fonctionnalité (écran + provider)
│   ├── auth/  dashboard/  chat/  ideas/  ranking/  culturel/
│   ├── admin/ profile/  public_profile/  notifications/
│   ├── oath/  values/  landing/  shell/
├── models/                # UserProfile, Idea, Sound, Message, Conversation, AppConfig…
├── providers/             # Providers Riverpod globaux (auth, config, notifications)
└── shared/widgets/        # Widgets réutilisables

functions/                 # Cloud Functions (TypeScript) — push FCM & tâches planifiées
android/ ios/ web/ windows/ # Plateformes natives
```

---

## ✅ Prérequis

- **Flutter SDK ≥ 3.22** ([guide d'installation](https://docs.flutter.dev/get-started/install)) — fournit aussi Dart.
- **Un navigateur** (Chrome/Chromium recommandé pour `flutter run -d chrome`).
- **Node.js 20** *(uniquement si tu touches aux Cloud Functions)*.
- Un **accès au projet Firebase `esp-sekou`** si tu dois (re)générer la configuration Firebase.

Vérifie ton environnement avec :

```bash
flutter doctor
```

---

## 🔐 Fichiers sensibles à récupérer (NON versionnés)

> ⚠️ **Important.** Plusieurs fichiers contiennent des secrets et **ne sont pas dans le dépôt** (ils sont ignorés par `.gitignore`). Sans eux, l'application **ne démarre pas**.
>
> 👉 **Contacte le propriétaire du repo ou un collaborateur de l'app** pour obtenir ces fichiers (ou les autorisations nécessaires pour les régénérer).

| Fichier | Emplacement | Rôle | Requis pour |
|---|---|---|---|
| `.env` | racine du projet | Clés Supabase (**obligatoires**), Cloudinary, OneSignal | Toutes plateformes |
| `firebase_options.dart` | `lib/` | Configuration Firebase (générée par FlutterFire) | Toutes plateformes |
| `google-services.json` | `android/app/` | Configuration Firebase Android | Build Android |
| `GoogleService-Info.plist` | `ios/Runner/` | Configuration Firebase iOS | Build iOS |

- Pour le **`.env`**, un gabarit vide est fourni : [`.env.example`](.env.example). Copie-le en `.env` et remplis les valeurs fournies par un collaborateur.
- Pour **`lib/firebase_options.dart`**, si tu as accès au projet Firebase tu peux le régénérer :
  ```bash
  dart pub global activate flutterfire_cli
  flutterfire configure --project=esp-sekou
  ```

---

## 🚀 Installation & lancement

```bash
# 1. Cloner et entrer dans le projet
git clone <URL_DU_DEPOT>
cd sekou

# 2. Installer les dépendances Dart/Flutter
flutter pub get

# 3. Placer les fichiers sensibles (voir section ci-dessus)
#    - .env à la racine (depuis .env.example)
#    - lib/firebase_options.dart
#    - (Android) android/app/google-services.json

# 4. Lancer l'application
flutter run -d chrome          # Web (ouverture automatique dans Chrome)
# ou, sans Chrome installé :
flutter run -d web-server      # sert sur http://localhost:<port>, à ouvrir manuellement
# ou sur un appareil/émulateur Android connecté :
flutter run -d android
```

Build de production web :

```bash
flutter build web              # sortie dans build/web/
```

### Cloud Functions (optionnel)

```bash
cd functions
npm install                    # nécessite Node 20
npm run deploy                 # déploie les fonctions (firebase deploy --only functions)
npm run logs                   # consulte les logs
```

---

## 🌍 Variables d'environnement (`.env`)

| Clé | Usage | Obligatoire |
|---|---|---|
| `SUPABASE_URL` | URL du projet Supabase (realtime) | ✅ (crash au démarrage sinon) |
| `SUPABASE_ANON_KEY` | Clé anonyme Supabase | ✅ (crash au démarrage sinon) |
| `CLOUDINARY_CLOUD_NAME` | Nom du cloud Cloudinary (upload d'images) | Recommandé |
| `CLOUDINARY_UPLOAD_PRESET` | Preset d'upload Cloudinary | Recommandé |
| `ONESIGNAL_APP_ID` | App ID OneSignal (push) | Recommandé |
| `ONESIGNAL_REST_API_KEY` | Clé API REST OneSignal | Recommandé |

> Les clés Supabase sont chargées de façon stricte au démarrage ([`lib/main.dart`](lib/main.dart)) : sans elles, l'app plante immédiatement. Les autres ont des valeurs de repli — les fonctionnalités concernées seront simplement inactives si elles sont vides.

---

## ☁️ Déploiement

Le projet se déploie automatiquement sur **GitHub Pages** à chaque `push` sur la branche `main`, via le workflow [`.github/workflows/gh-pages.yml`](.github/workflows/gh-pages.yml).

Les secrets sont injectés au build par **GitHub Actions Secrets** (à configurer dans les paramètres du dépôt) :
`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_UPLOAD_PRESET`, `ONESIGNAL_APP_ID`, `ONESIGNAL_REST_API_KEY`, et `FIREBASE_OPTIONS_DART` (contenu de `lib/firebase_options.dart` encodé en base64).

---

## 🤝 Contribution

1. Crée une branche à partir de `main` (`git checkout -b fix/ma-correction`).
2. Vérifie le code : `flutter analyze` et, si pertinent, `flutter test`.
3. Ouvre une Pull Request vers `main`.

Pour toute question ou pour obtenir les accès/fichiers sensibles, **contacte le propriétaire du dépôt ou un collaborateur de l'application**.

# Munqabat Competition Admin App

A production-style Flutter admin app for managing a munqabat competition with role-based access, live scoring, and Firebase-backed workflows.

**Keywords:** Flutter, Dart, Firebase, Firestore, Firebase Auth, Riverpod, Google Sign-In, mobile app, admin dashboard, role-based access, real-time data, cross-platform.

---

## Highlights
- Role-based access: Admin and Judge experiences with guarded routes
- Real-time Firestore streams for sessions, candidates, and scores
- Google Sign-In authentication with automatic user provisioning
- Structured scoring workflow with live status and history
- Modular architecture (models, services, providers, screens, shared widgets)

---

## Screens and Features
- **Admin:** manage sessions, candidates, and judge roles
- **Judge:** active session scoring, history, and performance insights
- **Candidate profile:** stage summaries and score breakdowns
- **Session control:** active vs conducted status handling

---

## Tech Stack
- Flutter (Material)
- Firebase Auth (Google Sign-In)
- Cloud Firestore
- Riverpod state management
- Dart

---

## Project Structure

```
lib/
├── main.dart                         # App entry, auth gate, role router
├── theme/
│   └── app_theme.dart                # Colors, typography, component styles
├── models/
│   └── models.dart                   # AppUser, Candidate, Session, Score
├── services/
│   ├── firebase_service.dart         # Firestore + Auth operations
│   ├── providers.dart                # Riverpod providers
│   └── app_logger.dart               # Logger setup
├── widgets/
│   └── shared_widgets.dart           # Reusable UI widgets
└── screens/
    ├── main_shell.dart               # Admin bottom nav shell
    ├── auth/
    │   └── login_screen.dart
    ├── sessions/
    │   ├── sessions_screen.dart      # List of sessions
    │   └── session_form_screen.dart  # Create/edit session
    ├── judges/
    │   └── judges_screen.dart        # User list + role assignment
    └── candidates/
        ├── candidates_screen.dart    # List with search, sort, group
        ├── candidate_detail_sheet.dart  # Score breakdown
        └── candidate_form_screen.dart   # Create/edit candidate
```

---

## Setup

### 1) Firebase Project
1. Create a Firebase project at https://console.firebase.google.com
2. Enable **Authentication** → Google sign-in
3. Enable **Cloud Firestore** (start in production mode)
4. Add Android/iOS/Web apps and download config files

### 2) Add Firebase config files
- **Android**: `android/app/google-services.json`
- **iOS**: `ios/Runner/GoogleService-Info.plist`

### 3) Firestore Rules and Indexes
- Publish the rules from `firestore.rules`
- Create composite indexes in Firestore console:

| Collection | Fields | Order |
|---|---|---|
| `scores` | `sessionId` ASC, `judgeId` ASC | — |
| `scores` | `candidateId` ASC, `submittedAt` DESC | — |
| `scores` | `judgeId` ASC, `sessionId` ASC | — |
| `sessions` | `isActive` ASC, `date` DESC | — |

### 4) Create First Admin User
1. Sign in once with Google so a `users/{uid}` document is created
2. In Firestore, set the role to `admin`

Example document:
```json
{ "name": "Admin Name", "email": "admin@email.com", "role": "admin" }
```

---

## Run

```bash
flutter pub get
flutter run
```

---

## Firestore Schema

### `users/{userId}`
```
name: string
email: string
role: "admin" | "judge" | "neither"
```

### `candidates/{candidateId}`
```
name: string
fatherName: string
dob: timestamp
imageUrl: string
isSenior: bool
stage: number
createdBy: string
createdAt: timestamp
```

### `sessions/{sessionId}`
```
date: timestamp
stage: number
isSenior: bool
isActive: bool
isConducted: bool
candidateIds: string[]
judgeIds: string[]
createdBy: string
createdAt: timestamp
```

### `scores/{judgeId}_{candidateId}_{sessionId}`
```
judgeId, candidateId, sessionId: string
stage, isSenior: denormalized for fast queries
adaigi, tarz, awaaz, confidence, tazeem: number (0-20 each)
total: number
comments: string
submittedAt: timestamp
```

---

## Eligibility Rules
- Age < 15: Junior
- Age 15-25: Senior
- Age 26+: Ineligible

---

## Screenshots and Demo
Add a few key screenshots and a short walkthrough video. This is the fastest way to show product quality to recruiters.

Suggested screenshots:
- Admin dashboard (sessions list)
- Candidate details with scores
- Judge session scoring screen
- Role management screen

Example (replace with your images):
```
![Sessions](docs/screenshots/sessions.png)
![Candidates](docs/screenshots/candidates.png)
![Judge Scoring](docs/screenshots/judge_scoring.png)
```

---

## License
MIT (or your preferred license)

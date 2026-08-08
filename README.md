# University Companion (MVP)

Flutter + Firebase app for Philippine university students. This MVP covers
two features only: **Class Schedule** and **QPI Calculator**.

## What's included

```
lib/
  auth/                  # Login, signup, auth gate (routes by sign-in state)
  shared/
    models/              # AppUser, Term, ClassSession, GradeRecord, GradeScale
    services/            # AuthService, FirestoreService, TermController
    widgets/             # MainShell (bottom nav), HomeScreen, EmptyState,
                          # ColorPickerRow, TermSelector
  schedule/              # WeeklyGrid, ClassFormScreen (conflict detection), ScheduleScreen
  qpi_calculator/        # AddSubjectSheet, GradeScaleSection, QpiTrendSection, QpiScreen
firestore.rules          # Per-user read/write lock-down
```

Bottom navigation shows **Home / Schedule / QPI Calc** only — Chat/Board and
other social features are intentionally left out of the nav (not stubbed as
disabled tabs), since they're out of scope for this build. The Firestore
schema (`terms/{termId}/classes` and `terms/{termId}/grades` as sibling
subcollections) is unchanged from the spec, so those features can be added
later without a data migration.

## One-time setup

1. **Install Flutter** (stable channel) and run `flutter doctor` to confirm
   your Android/iOS toolchains are ready.

2. **Generate native platform folders.** This project ships only the `lib/`
   source — run this once from the project root to scaffold `android/` and
   `ios/` (and `web/` if you want it):
   ```bash
   flutter create .
   ```
   This will not overwrite the existing `lib/` files.

3. **Create a Firebase project** at https://console.firebase.google.com,
   then enable:
   - **Authentication → Sign-in method → Email/Password**
   - **Firestore Database** (start in production mode; rules are provided)

4. **Connect Firebase to the app** using the FlutterFire CLI:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   This overwrites `lib/firebase_options.dart` with your real project
   credentials — the checked-in version is a placeholder that will not
   connect to anything.

5. **Deploy the Firestore rules:**
   ```bash
   firebase deploy --only firestore:rules
   ```
   (requires `firebase-tools` and `firebase login` / `firebase use`).

6. **Install packages and run:**
   ```bash
   flutter pub get
   flutter run
   ```

## Notes on a few implementation choices

- **Conflict detection** compares start/end minutes for classes on the same
  `day` within the currently selected term. If a new/edited class overlaps
  an existing one, the user sees a dialog listing the conflicting subject(s)
  and can choose to save anyway rather than being hard-blocked (some
  students genuinely have overlapping cross-listed sections).
- **QPI persistence**: each subject added in "This Semester" is written
  immediately to `users/{uid}/terms/{termId}/grades` (so nothing is lost if
  the app closes mid-session). "Calculate & Save" recomputes the summary
  cards from that live data — there's no separate draft state to reconcile.
- **Grade scale** defaults to Ateneo's 4.0 scale but is referenced by
  `gradeScaleId` on each grade record rather than embedded, so adding a
  second scale later (e.g. a 1.00–5.00 scale) won't require touching
  existing grade documents.
- **QPI Trend chart** reduces every term's `grades` subcollection to one
  point (that term's semester QPI) and needs at least 2 terms with saved
  grades to render a line.

## Explicitly out of scope for this MVP

Community boards, chat, professor reviews, and marketplace — per the build
spec, these are not implemented, though the data model was kept flexible
enough not to block them later.

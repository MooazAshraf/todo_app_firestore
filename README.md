# Todo App — Flutter + Firestore (lightweight)

Only 2 dependencies (`firebase_core`, `cloud_firestore`), 3 Dart files, ~300 lines.
Tasks live in Cloud Firestore (collection `tasks`) and sync in real time; offline cache is built in.

## Setup

1. Create a project at https://console.firebase.google.com and enable **Firestore Database**.
2. In this folder:
   ```
   flutter create .              # generates android/ios folders (keeps lib/)
   dart pub global activate flutterfire_cli
   flutterfire configure         # creates lib/firebase_options.dart
   flutter pub get
   flutter run
   ```
3. Firestore rules (test mode, or lock down with auth later):
   ```
   rules_version = '2';
   service cloud.firestore {
     match /databases/{db}/documents {
       match /tasks/{id} { allow read, write: if true; }
     }
   }
   ```
   ⚠️ `if true` lets anyone read/write — fine for dev/portfolio demo only.

## Document shape (`tasks/{id}`)
`title: string, note: string, done: bool, priority: 0|1|2, createdAt: int (ms)`

## Why it's light
- One real-time stream; filtering is local (no extra reads, no composite indexes)
- No seed data, no extra packages (removed `cupertino_icons`, lints)
- Stock Material widgets, no shadows/animated containers, `const` everywhere
- Release size: build with `flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols`

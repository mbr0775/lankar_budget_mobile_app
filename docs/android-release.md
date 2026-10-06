# Preparing Lankar for Google Play

## Configure the upload key

Copy `android/key.properties.example` to `android/key.properties` and replace the
values with your upload keystore's location, alias, and passwords. Keep the
keystore and passwords private. They are ignored by Git.

If this application is already registered with Play, use its registered upload
key or Google's upload-key reset process. Do not create a replacement signing
identity casually. See [Flutter's Android signing instructions](https://docs.flutter.dev/deployment/android#sign-the-app).

Without `android/key.properties`, this project intentionally builds an **unsigned**
release bundle for validation. It cannot be uploaded to Play. Release builds no
longer fall back to the development/debug key.

## Complete the unfinished release features

- Publish a privacy policy that describes the actual account, budget, local
  storage, cloud sync, and sharing behavior. Connect the policy actions in both
  Profile and Settings to its public URL, and enter that URL in Play Console.
  Currently Profile is disabled and Settings has an empty tap handler.
- Provide an account-deletion request path in the app and a public webpage that
  works after the app is uninstalled. The deletion process must handle the
  Supabase account and its associated data. Clearing Hive or signing out does
  not delete the account. A link to a functioning deletion webpage can also be
  the in-app path. See [Google's account-deletion requirements](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en)
  and [User Data policy](https://support.google.com/googleplay/android-developer/answer/10144311?hl=en).
- Implement and test Premium subscriptions and purchase restoration, or hide
  the Premium promotion and purchase screen for the first release. Currently
  Subscribe only displays "In-app purchase coming soon!" and Restore does
  nothing. The displayed monthly price is hardcoded.

## Verify the production services and device behavior

Register package `com.tokilo.lankar` and the **Play app-signing certificate**
fingerprints with the Android Google OAuth client. The upload certificate and
Play app-signing certificate can differ. Verify Google login from an internal
Play installation, along with email confirmation and password-reset deep links.
See [Google Sign-In Android configuration](https://pub.dev/packages/google_sign_in_android).

Check Supabase row-level security with separate test accounts before release.
The client code and mocked tests do not establish the deployed database's access
rules. Complete Play's Data safety and app-access/reviewer declarations using
the actual production behavior.

Test a signed installation on Android: first launch, login, offline edits,
reconnection/sync, sign-out, PDF save/share, and account deletion. Include Android
16 and a 16 KB page-size device/emulator. Android's file picker now saves reports
without READ/WRITE_EXTERNAL_STORAGE or MANAGE_EXTERNAL_STORAGE.

`flutter doctor` still reports some optional/installed SDK licenses as unaccepted.
Review the prompts yourself with `flutter doctor --android-licenses`; this audit
did not accept license agreements on your behalf.

## Build and validate

From the project root:

```powershell
flutter analyze
flutter test
flutter build appbundle --release
```

The output is `build/app/outputs/bundle/release/app-release.aab`. Verify release
signing after configuring the upload key. Set a version/build number appropriate
for the existing Play listing; the current project is `1.0.0+1`.

The checks on 2026-10-05 passed: Flutter analysis (no issues), 53 automated tests,
Android release vital lint, release AAB compilation, and bundletool structure
validation. The merged manifest targets API 36 and has no broad storage permissions.
The bundle requests `PAGE_ALIGNMENT_16K`, and all nine native libraries have LOAD
alignment of at least 16 KB. These are packaging checks, not Android device smoke
tests or confirmation of store approval. No Android device was connected, and
the generated bundle is unsigned.

Current submission requirements are documented in [Google's target API policy](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en)
and [Android's 16 KB guidance](https://developer.android.com/guide/practices/page-sizes).

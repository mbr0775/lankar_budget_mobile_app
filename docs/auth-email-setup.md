# Confirmation and password recovery

The dashboard screenshot supplied on 2026-10-05 includes the correct mobile
redirect: `io.supabase.flutter://login-callback`. Keep that exact URL for signup
and confirmation resend. Also add `io.supabase.flutter://reset-callback` in
Authentication > URL Configuration > Redirect URLs for new recovery requests.
The app accepts both callback hosts for previous emails. The Supabase HTTPS
`/auth/v1/callback` endpoint is the OAuth provider callback, not the mobile return
destination.

## Dashboard checks still required

- Under Authentication email settings, configure a production SMTP sender.
  Supabase's default mail service restricts delivery to project team addresses;
  success responses alone do not establish inbox delivery. Check Auth logs and
  your mail provider's delivery logs for the failed request, without sharing
  passwords or full authentication links.
- Keep email confirmation enabled if accounts must verify their email.
- In both Confirm signup and Reset password templates, use the Supabase
  `{{ .ConfirmationURL }}` verification link. A link directly to SiteURL or
  RedirectTo does not itself verify a user. Disable SMTP-provider link tracking
  if it rewrites these links.
- Request a fresh email after changing settings. With the default PKCE flow,
  open it on the device and installation that requested it. Reinstalling or
  clearing app storage removes the pending verifier. Older or already used
  links may fail.

## App changes

Lankar's AuthCallbackHandler owns email callbacks through app_links. Supabase's
automatic URI observer and Flutter's native routing handler are disabled to avoid
duplicate handling. The callback handler exchanges PKCE codes, verifies older
token-fragment links with the server, and identifies recovery by the dedicated
callback host or the verified response/legacy recovery type. A callback without
credentials displays an error, even if a previous session exists. Navigation
waits for verification. Recovery is observed before storage
startup and takes priority over the splash/home redirect. Token refresh and
user-update events retain recovery mode until sign-out. Callback errors show
recovery actions without displaying private backend text. Signup now has a
confirmation screen and the login page offers confirmation resend. The reset
request form uses the scrolling authentication layout and contracts its illustration
when the keyboard opens.

## End-to-end verification before release

1. Install the updated build. Sign up using a test inbox outside the Supabase
   organization; confirm receipt and open the latest email on that installation.
2. Repeat with Lankar closed and with Lankar already open. Confirm the verified
   account reaches the app and can subsequently sign in.
3. Sign out, request a password reset, and open the newest email. Confirm the
   new-password screen appears in both cold and warm starts.
4. Save a new password, then sign in with it. Check that the old password fails.
5. Open an expired/used link and confirm that fresh-email actions are available.

Automated tests use mocked authentication responses. They do not establish SMTP
delivery, email-template correctness, OS dispatch, or production server behavior.

References: [Supabase SMTP](https://supabase.com/docs/guides/auth/auth-smtp),
[mobile links](https://supabase.com/docs/guides/auth/native-mobile-deep-linking?platform=flutter),
[Flutter plugin link handling](https://docs.flutter.dev/cookbook/navigation/set-up-app-links).

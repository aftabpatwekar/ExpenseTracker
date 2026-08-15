# Social login (Google / Apple) setup

The **buttons and the in-app OAuth flow are already built** (`Continue with
Google` / `Continue with Apple` on the sign-in screen). They stay inert until you
enable the provider in Supabase. Once configured, no app changes are needed.

The app opens the provider in the system browser and returns via the redirect
`expensetracker://login-callback` (already registered in the Android manifest and
iOS Info.plist).

## Google

1. **Google Cloud Console** → create an OAuth 2.0 Client ID (type: Web
   application). Add this authorized redirect URI:
   `https://dcbgcintizqbsczncmqe.supabase.co/auth/v1/callback`
2. Copy the **Client ID** and **Client secret**.
3. **Supabase → Authentication → Providers → Google** → enable, paste the
   Client ID + secret, save.
4. **Supabase → Authentication → URL Configuration → Redirect URLs** → add
   `expensetracker://login-callback`.

That's it — the Google button now signs users in.

## Apple (needed for the iOS App Store later)

1. Apple Developer → Certificates, IDs & Profiles → create a **Services ID** and
   enable *Sign in with Apple*; set the return URL to the same Supabase callback
   `https://dcbgcintizqbsczncmqe.supabase.co/auth/v1/callback`.
2. Create a **Sign in with Apple key**, note the Key ID + Team ID.
3. **Supabase → Authentication → Providers → Apple** → enable, fill in Services
   ID, Team ID, Key ID, and the key.
4. Ensure `expensetracker://login-callback` is in the redirect allow-list.

## Facebook (optional — same pattern)

Create a Facebook app → add Facebook Login → set the OAuth redirect to the
Supabase callback → enable Facebook in Supabase with the App ID + secret. Then
add a `_SocialButton` for `OAuthProvider.facebook` in `sign_in_screen.dart`.

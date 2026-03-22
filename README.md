# Pomogotchi

Pomogotchi is a Flutter prototype for a local-first Pomodoro companion pet. The app combines a focus timer, hydration and movement check-ins, magic-link email sign-in, and cross-device sync through Supabase + PowerSync. The current Flutter app targets Apple devices first, with macOS as the main runtime and iPhone as the companion client.

The repo is not a generic Flutter starter. It contains:

- `flutter_pomogotchi`: the Flutter app
- `supabase`: local Supabase config, auth config, and database migrations
- `powersync`: PowerSync CLI config, sync config, and Docker stack
- `docs`: product and technical planning documents

## What The App Currently Does

The `flutter_pomogotchi` app already includes:

- Email sign-in with Supabase magic links and 6-digit email codes
- Local SQLite-backed timer state with PowerSync replication
- Focus sessions and break sessions
- Hydration and movement event logging
- Daily activity summaries synced per authenticated user
- A Pomogotchi pet layer that reacts to timer and wellness events
- Cactus-backed local or hybrid AI pet responses, with app-side fallbacks

The synced database currently centers on:

- `sessions`
- `wellness_events`
- `daily_activity_summary`

## Prerequisites

Install these before running the project locally:

- [Flutter](https://docs.flutter.dev/get-started/install)
- [Docker](https://docs.docker.com/get-docker/)
- [Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started)
- [PowerSync CLI](https://docs.powersync.com/tools/cli): `npm install -g powersync`

## Local Setup

### 1. Create local env file

```bash
cp .env.template .env
```

### 2. Ensure Supabase signing keys exist

This repo expects `supabase/signing_keys.json`. If it is missing, generate it with:

```bash
supabase gen signing-key --output supabase/signing_keys.json
```

### 3. Start Supabase

From the repo root:

```bash
supabase start
```

Useful local services from `supabase/config.toml`:

- Supabase API: `http://127.0.0.1:54321`
- Supabase Studio: `http://127.0.0.1:54323`
- Local auth email inbox (`Mailpit`): `http://127.0.0.1:54324`

### 4. Start PowerSync

In a second terminal:

```bash
powersync docker start
```

PowerSync is exposed on `http://localhost:8080`.

### 5. Run the Flutter app

```bash
cd flutter_pomogotchi
flutter pub get

cp lib/app_config_template.dart lib/app_config.dart

flutter run -d macos
```

For iPhone development, run against an iOS simulator.

## Login Flow And Local Email Testing

The app uses Supabase email OTP sign-in. When you tap `Send magic link`, the email is delivered to the local `Mailpit` test inbox started by `supabase start`.

To complete sign-in locally:

1. Open `http://127.0.0.1:54324` in your browser.
2. Open the newest auth email for the address you entered in the app.
3. Use either of these flows:
   - Click the magic link on the same device you are using for the app.
   - Copy the 6-digit code from the email and enter it in the app under `Verify code`.

For simulator and local-device testing, the 6-digit code path is usually the most direct because it does not depend on deep-link handling in the browser.

## Flutter App Notes

- The app config lives in `flutter_pomogotchi/lib/app_config.dart`.
- Local development is already wired to `localhost` on Apple platforms
- The app uses Supabase auth plus PowerSync for authenticated sync

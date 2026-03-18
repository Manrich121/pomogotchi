# flutter_pomodoro

## Local PowerSync + Supabase setup

1. Ensure the local Supabase stack is running from the workspace root:

```bash
supabase start
```

2. Ensure the local PowerSync container is running from the workspace root:

```bash
docker compose --file ./docker/compose.yaml --env-file .env.local up -d
```

3. The app reads local connection details from `lib/app_config.dart`.
   The tracked defaults live in `lib/app_config_template.dart`.

4. Run the app:

```bash
flutter run
```

## Magic link sign-in

- The app uses Supabase email magic links instead of anonymous auth.
- Local emails are delivered to Mailpit at `http://127.0.0.1:54324`.
- The callback URL used by the app is `com.example.flutterpomodoro://login-callback`.
- If you change `supabase/config.toml`, restart the local Supabase stack before testing auth again.

## Web

To prepare the web SQLite runtime, run:

```bash
dart run powersync:setup_web --no-worker
```

## PowerSync tests

Repository and connector tests that instantiate `PowerSyncDatabase` require the
native PowerSync library to be available at the package root as
`libpowersync.dylib`.

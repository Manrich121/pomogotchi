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

## Web

To prepare the web SQLite runtime, run:

```bash
dart run powersync:setup_web --no-worker
```

## PowerSync tests

Repository and connector tests that instantiate `PowerSyncDatabase` require the
native PowerSync library to be available at the package root as
`libpowersync.dylib`.

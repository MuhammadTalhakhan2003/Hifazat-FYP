# Hifazat – Flutter App

The Flutter client for Hifazat. See the [main README](../README.md) for the full project overview.

## Run

```bash
flutter pub get
flutter run -d chrome
```

Set the backend URL in `lib/utils/constants.dart` (`apiBaseUrl`).

## Structure

| Folder | Contents |
|---|---|
| `lib/api/` | Dio client with JWT handling, models and API services |
| `lib/auth/` | Auth provider and token storage |
| `lib/providers/` | App state (incidents, stats, users, map, categories) |
| `lib/screens/` | Map, incidents feed, incident detail, report, analytics, profile, login and register |
| `lib/widgets/` | Reusable UI (incident card, comments, filters, …) |
| `test/` | Widget tests (`flutter test`) |

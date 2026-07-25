# Vital Fitness — Mobile

Flutter app for User and Coach. Package name remains `vital_fitness`.

```bash
cd mobile
flutter pub get
flutter run
```

## API URL

**Release / installed APKs** use the production API by default:

`https://vital-online-app-1.onrender.com/api`

Do **not** point release builds at `localhost` / `127.0.0.1` — those only work on the machine running the Node server.

### Local backend (optional)

```bash
# Android emulator → host machine
flutter run --dart-define=API_URL=http://10.0.2.2:5050/api

# Physical device on same Wi‑Fi (use your Mac's LAN IP)
flutter run --dart-define=API_URL=http://192.168.x.x:5050/api
```

### Release APK

```bash
flutter build apk --release
# Explicit (same as default):
flutter build apk --release --dart-define=API_URL=https://vital-online-app-1.onrender.com/api
```

See `lib/config/api_config.dart`.

# Vital Fitness Admin Dashboard

React admin website connected to the **same** Node.js API and MongoDB as the Flutter app.

## Shared API (required)

| Client | Base URL |
|--------|----------|
| Flutter (`ApiConfig.baseUrl`) | `http://127.0.0.1:5050/api` |
| Admin (`VITE_API_URL`) | `http://127.0.0.1:5050/api` |

Both use:
- Same server: port **5050**
- Same auth: `POST /auth/login` → JWT `Authorization: Bearer <token>`
- Same database: MongoDB `vitalguide`

Do **not** create a second backend or point Admin at a different URL.

## Architecture

```
Flutter App (User + Coach) ──┐
                             ├──► Existing Backend :5050/api ──► MongoDB vitalguide
Admin Dashboard (React) ─────┘
```

## Run

1. Backend: `cd backend && npm start`
2. Frontend: `cd frontend && npm run dev` → http://127.0.0.1:5174
3. Login as admin (`role=admin` only)

## Auth

- Login: `/api/auth/login`
- Session: `/api/auth/me`
- Protected admin routes require JWT + `role === "admin"`

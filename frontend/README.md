# Vital Fitness Admin Dashboard

React web app for Admin / Coach / Member. Uses the **same** Node API and MongoDB Atlas DB as the Flutter app.

## Production

| Layer | URL |
|--------|-----|
| API (Render) | `https://vital-online-app.onrender.com/api` |
| Database | MongoDB Atlas `vitalguide` |
| Web (Vercel) | set `CLIENT_URL` on Render to your Vercel URL |

Production builds (`vite build` / Vercel) read `frontend/.env.production` and call the Render API.

## Local development

| Client | Base URL |
|--------|----------|
| Flutter debug | `http://127.0.0.1:5050/api` |
| Admin (`npm run dev`) | `http://127.0.0.1:5050/api` |

```
Flutter App ──┐
Web (React) ──┼──► Backend API ──► MongoDB Atlas vitalguide
              ┘
```

1. Backend: `cd backend && npm start`
2. Frontend: `cd frontend && npm run dev` → http://127.0.0.1:5174

## Auth

- Login: `/api/auth/login`
- Session: `/api/auth/me`
- JWT: `Authorization: Bearer <token>`

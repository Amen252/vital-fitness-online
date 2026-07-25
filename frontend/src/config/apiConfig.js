/**
 * Shared API config — must match Flutter's ApiConfig
 * (mobile/lib/config/api_config.dart)
 *
 * Flutter default: http://127.0.0.1:5050/api
 * Admin default:   http://127.0.0.1:5050/api
 * Backend listen:  PORT=5050
 * Database:        existing Atlas MongoDB `vitalguide` (via backend MONGO_URI)
 *
 * Override with VITE_API_URL when deploying (same host/port as Flutter).
 * Do NOT point this at a different backend or database.
 */
const DEFAULT_API_URL = "http://127.0.0.1:5050/api";

export const API_BASE_URL = (
  import.meta.env.VITE_API_URL || DEFAULT_API_URL
).replace(/\/$/, "");

/** Origin without `/api` — used for Socket.IO and health checks */
export const API_ORIGIN = API_BASE_URL.replace(/\/api$/, "");

export const API_HEALTH_URL = `${API_ORIGIN}/api/health`;

export const SOCKET_URL =
  (import.meta.env.VITE_SOCKET_URL || API_ORIGIN).replace(/\/$/, "");

export default API_BASE_URL;

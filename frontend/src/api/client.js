import axios from "axios";
import { API_BASE_URL } from "../config/apiConfig";

const RETRYABLE_STATUSES = new Set([502, 503, 504]);
const MAX_RETRIES = 3;

/** Same base URL as Flutter ApiConfig.baseUrl → Existing Backend → MongoDB vitalguide */
export const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    "Content-Type": "application/json",
    Accept: "application/json",
  },
  timeout: 30000,
});

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

api.interceptors.request.use((config) => {
  const token = localStorage.getItem("vital_token") || localStorage.getItem("admin_token");
  if (token) {
    // Same JWT Bearer scheme as Flutter ApiService._headers()
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

api.interceptors.response.use(
  (response) => response,
  async (error) => {
    const config = error.config;
    const status = error.response?.status;

    if (config && RETRYABLE_STATUSES.has(status)) {
      config.__retryCount = config.__retryCount || 0;
      if (config.__retryCount < MAX_RETRIES) {
        config.__retryCount += 1;
        await sleep(350 * config.__retryCount);
        return api(config);
      }
    }

    if (status === 401 || status === 403) {
      const url = error.config?.url || "";
      const responseCode = error.response?.data?.code;

      // Forced password-change gate — redirect but keep the session token
      if (status === 403 && responseCode === "PASSWORD_CHANGE_REQUIRED") {
        if (!window.location.pathname.includes("/change-password")) {
          window.location.href = "/change-password";
        }
        return Promise.reject(error);
      }

      const isSessionProbe =
        url.includes("/admin/me") || url.includes("/auth/admin/login");
      if (isSessionProbe || status === 401) {
        localStorage.removeItem("vital_token");
        localStorage.removeItem("vital_user");
        localStorage.removeItem("admin_token");
        localStorage.removeItem("admin_user");
        if (status === 401 && !window.location.pathname.includes("/login")) {
          window.location.href = "/login";
        }
      }
    }
    return Promise.reject(error);
  },
);

export function getErrorMessage(error) {
  return (
    error?.response?.data?.message ||
    error?.response?.data?.errors?.[0]?.msg ||
    error?.message ||
    "Something went wrong"
  );
}

export default api;

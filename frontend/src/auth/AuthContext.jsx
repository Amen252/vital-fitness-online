import { createContext, useCallback, useContext, useEffect, useMemo, useState } from "react";
import { getMe, login as apiLogin, changePassword as apiChangePassword } from "../api/adminApi";
import { getErrorMessage } from "../api/client";

const AuthContext = createContext(null);
const TOKEN_KEY = "vital_token";
const USER_KEY = "vital_user";

export function AuthProvider({ children }) {
  const [user, setUser] = useState(() => {
    try { return JSON.parse(localStorage.getItem(USER_KEY) || localStorage.getItem("admin_user") || "null"); }
    catch { return null; }
  });
  const [token, setToken] = useState(() => localStorage.getItem(TOKEN_KEY) || localStorage.getItem("admin_token"));
  const [loading, setLoading] = useState(Boolean(localStorage.getItem(TOKEN_KEY) || localStorage.getItem("admin_token")));

  const logout = useCallback(() => {
    [TOKEN_KEY, USER_KEY, "admin_token", "admin_user"].forEach((key) => localStorage.removeItem(key));
    setToken(null); setUser(null);
  }, []);

  const refreshUser = useCallback(async () => {
    if (!token) return null;
    try {
      const data = await getMe();
      if (data?.user) {
        setUser(data.user);
        localStorage.setItem(USER_KEY, JSON.stringify(data.user));
        return data.user;
      }
    } catch (error) {
      if ([401, 403].includes(error?.response?.status)) logout();
    }
    return null;
  }, [token, logout]);

  useEffect(() => {
    if (!token) { setLoading(false); return; }
    refreshUser().finally(() => setLoading(false));
  }, [token, refreshUser]);

  async function login(username, password) {
    const data = await apiLogin(username, password);
    localStorage.setItem(TOKEN_KEY, data.token);
    localStorage.setItem(USER_KEY, JSON.stringify(data.user));
    setToken(data.token); setUser(data.user);
    return data.user;
  }

  const establishSession = useCallback((sessionToken, sessionUser) => {
    if (!sessionToken || !sessionUser) {
      throw new Error("Missing session after registration");
    }
    localStorage.setItem(TOKEN_KEY, sessionToken);
    localStorage.setItem(USER_KEY, JSON.stringify(sessionUser));
    setToken(sessionToken);
    setUser(sessionUser);
    return sessionUser;
  }, []);

  const clearPasswordChangeFlag = useCallback(() => {
    setUser((current) => {
      if (!current) return current;
      const updated = { ...current, must_change_password: false };
      localStorage.setItem(USER_KEY, JSON.stringify(updated));
      return updated;
    });
  }, []);

  async function changePassword(currentPassword, newPassword) {
    await apiChangePassword(currentPassword, newPassword);
    clearPasswordChangeFlag();
  }

  const value = useMemo(
    () => ({
      user,
      token,
      loading,
      login,
      establishSession,
      logout,
      changePassword,
      refreshUser,
      mustChangePassword: !!user?.must_change_password,
      errorMessage: getErrorMessage,
    }),
    [user, token, loading, logout, establishSession, clearPasswordChangeFlag, refreshUser],
  );
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within AuthProvider");
  return ctx;
}

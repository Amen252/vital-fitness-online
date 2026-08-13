import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { useAuth } from "../auth/AuthContext";
import { getErrorMessage } from "../api/client";
import { BrandMark, Button } from "../components/ui";
import { useTheme } from "../theme/ThemeContext";
import { Moon, Sun, Lock, ShieldCheck, Eye, EyeOff } from "lucide-react";
import { dashboardPath } from "../App";

export default function ChangePasswordPage() {
  const { user, changePassword, logout } = useAuth();
  const { isDark, toggleTheme } = useTheme();
  const navigate = useNavigate();

  const [currentPassword, setCurrentPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [showCurrent, setShowCurrent] = useState(false);
  const [showNew, setShowNew] = useState(false);
  const [error, setError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  async function handleSubmit(e) {
    e.preventDefault();
    setError("");

    if (newPassword.length < 6) {
      setError("New password must be at least 6 characters.");
      return;
    }
    if (newPassword !== confirmPassword) {
      setError("Passwords do not match.");
      return;
    }
    if (currentPassword === newPassword) {
      setError("New password must be different from the current one.");
      return;
    }

    setSubmitting(true);
    try {
      await changePassword(currentPassword, newPassword);
      navigate(dashboardPath(user?.role), { replace: true });
    } catch (err) {
      setError(getErrorMessage(err));
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className="relative flex min-h-screen items-center justify-center overflow-hidden px-4 py-10">
      <div
        className="absolute inset-0"
        style={{ background: "var(--vf-gradient)" }}
      />
      <div className="absolute inset-0 bg-[radial-gradient(circle_at_30%_30%,rgba(14,165,233,0.2),transparent_50%)]" />

      <button
        type="button"
        onClick={toggleTheme}
        className="absolute right-4 top-4 z-10 rounded-[12px] border border-white/20 bg-white/10 p-2 text-white backdrop-blur"
        aria-label="Toggle theme"
      >
        {isDark ? <Sun className="h-4 w-4" /> : <Moon className="h-4 w-4" />}
      </button>

      <div className="relative z-10 w-full max-w-md overflow-hidden rounded-[20px] border border-white/15 bg-[var(--vf-surface)] shadow-2xl">
        {/* Header */}
        <div
          className="flex flex-col items-center gap-3 p-8 text-white"
          style={{ background: "var(--vf-gradient)" }}
        >
          <BrandMark size="md" light />
          <div className="flex h-14 w-14 items-center justify-center rounded-full bg-white/20 backdrop-blur">
            <ShieldCheck className="h-7 w-7" />
          </div>
          <div className="text-center">
            <h1 className="text-2xl font-bold">Set Your Password</h1>
            <p className="mt-1 text-sm text-white/80">
              Welcome, <strong>{user?.username || user?.full_name}</strong>! You
              must set a new password before continuing.
            </p>
          </div>
        </div>

        {/* Form */}
        <div className="p-8">
          <form onSubmit={handleSubmit} className="space-y-4">
            {/* Current (6-digit) password */}
            <label className="block text-sm font-semibold text-[var(--vf-text)]">
              Current (temporary) password
              <div className="relative mt-1.5">
                <Lock className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-[var(--vf-muted)]" />
                <input
                  id="current-password"
                  type={showCurrent ? "text" : "password"}
                  required
                  autoComplete="current-password"
                  value={currentPassword}
                  onChange={(e) => setCurrentPassword(e.target.value)}
                  className="w-full rounded-[12px] border border-[var(--vf-border)] bg-[var(--vf-surface-muted)] py-2.5 pl-10 pr-10 outline-none ring-[var(--vf-accent)] focus:ring-2"
                  placeholder="6-digit code"
                />
                <button
                  type="button"
                  tabIndex={-1}
                  onClick={() => setShowCurrent((v) => !v)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-[var(--vf-muted)]"
                  aria-label="Toggle current password visibility"
                >
                  {showCurrent ? (
                    <EyeOff className="h-4 w-4" />
                  ) : (
                    <Eye className="h-4 w-4" />
                  )}
                </button>
              </div>
            </label>

            {/* New password */}
            <label className="block text-sm font-semibold text-[var(--vf-text)]">
              New password
              <div className="relative mt-1.5">
                <Lock className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-[var(--vf-muted)]" />
                <input
                  id="new-password"
                  type={showNew ? "text" : "password"}
                  required
                  minLength={6}
                  autoComplete="new-password"
                  value={newPassword}
                  onChange={(e) => setNewPassword(e.target.value)}
                  className="w-full rounded-[12px] border border-[var(--vf-border)] bg-[var(--vf-surface-muted)] py-2.5 pl-10 pr-10 outline-none ring-[var(--vf-accent)] focus:ring-2"
                  placeholder="At least 6 characters"
                />
                <button
                  type="button"
                  tabIndex={-1}
                  onClick={() => setShowNew((v) => !v)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-[var(--vf-muted)]"
                  aria-label="Toggle new password visibility"
                >
                  {showNew ? (
                    <EyeOff className="h-4 w-4" />
                  ) : (
                    <Eye className="h-4 w-4" />
                  )}
                </button>
              </div>
            </label>

            {/* Confirm password */}
            <label className="block text-sm font-semibold text-[var(--vf-text)]">
              Confirm new password
              <input
                id="confirm-password"
                type="password"
                required
                autoComplete="new-password"
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
                className="mt-1.5 w-full rounded-[12px] border border-[var(--vf-border)] bg-[var(--vf-surface-muted)] px-3 py-2.5 outline-none ring-[var(--vf-accent)] focus:ring-2"
                placeholder="Repeat new password"
              />
            </label>

            {/* Strength indicator */}
            {newPassword.length > 0 && (
              <div className="space-y-1">
                <div className="flex gap-1">
                  {[1, 2, 3, 4].map((i) => (
                    <div
                      key={i}
                      className={`h-1 flex-1 rounded-full transition-all duration-300 ${
                        newPassword.length >= i * 3
                          ? i <= 1
                            ? "bg-rose-500"
                            : i <= 2
                              ? "bg-amber-500"
                              : i <= 3
                                ? "bg-[var(--vf-accent)]"
                                : "bg-emerald-500"
                          : "bg-[var(--vf-border)]"
                      }`}
                    />
                  ))}
                </div>
                <p className="text-xs text-[var(--vf-muted)]">
                  {newPassword.length < 6
                    ? "Too short"
                    : newPassword.length < 9
                      ? "Fair"
                      : newPassword.length < 12
                        ? "Good"
                        : "Strong"}
                </p>
              </div>
            )}

            {/* Error */}
            {error && (
              <p className="rounded-[12px] border border-rose-200 bg-rose-50 px-3 py-2 text-sm text-rose-700 dark:border-rose-900/40 dark:bg-rose-950/40 dark:text-rose-200">
                {error}
              </p>
            )}

            <Button
              id="change-password-submit"
              type="submit"
              className="w-full"
              size="lg"
              disabled={submitting}
            >
              {"Set New Password & Continue"}
            </Button>
          </form>

          <button
            type="button"
            onClick={logout}
            className="mt-4 w-full text-center text-xs text-[var(--vf-muted)] underline-offset-2 hover:underline"
          >
            Sign out and use a different account
          </button>
        </div>
      </div>
    </div>
  );
}

import { useState } from "react";
import { useNavigate, useOutletContext } from "react-router-dom";
import { Eye, EyeOff, KeyRound } from "lucide-react";
import { useAuth } from "../../auth/AuthContext";
import { getErrorMessage } from "../../api/client";
import { Button, Card } from "../../components/ui";
import { fieldClass } from "./roleHelpers";

export default function RolePasswordPage({ role }) {
  const { changePassword } = useAuth();
  const { profile } = useOutletContext();
  const navigate = useNavigate();
  const [currentPassword, setCurrentPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [showCurrent, setShowCurrent] = useState(false);
  const [showNew, setShowNew] = useState(false);
  const [error, setError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  const home = role === "coach" ? "/coach/dashboard" : "/member/dashboard";

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
      navigate(home, { replace: true });
    } catch (err) {
      setError(getErrorMessage(err));
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <Card className="mx-auto max-w-lg p-6">
      <KeyRound className="h-6 w-6 text-[var(--vf-primary)]" />
      <h1 className="mt-4 text-2xl font-bold">Change password</h1>
      <p className="mt-2 text-sm text-[var(--vf-muted)]">
        Update the password for @{profile?.username || "your account"}.
      </p>
      <form onSubmit={handleSubmit} className="mt-5 space-y-4">
        <label className="block text-sm">
          Current password
          <div className="relative">
            <input
              type={showCurrent ? "text" : "password"}
              value={currentPassword}
              onChange={(e) => setCurrentPassword(e.target.value)}
              className={fieldClass}
              required
              autoComplete="current-password"
            />
            <button
              type="button"
              className="absolute right-2 top-1/2 -translate-y-1/2 p-1 text-[var(--vf-muted)]"
              onClick={() => setShowCurrent((v) => !v)}
              aria-label="Toggle current password"
            >
              {showCurrent ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
            </button>
          </div>
        </label>
        <label className="block text-sm">
          New password
          <div className="relative">
            <input
              type={showNew ? "text" : "password"}
              value={newPassword}
              onChange={(e) => setNewPassword(e.target.value)}
              className={fieldClass}
              required
              autoComplete="new-password"
            />
            <button
              type="button"
              className="absolute right-2 top-1/2 -translate-y-1/2 p-1 text-[var(--vf-muted)]"
              onClick={() => setShowNew((v) => !v)}
              aria-label="Toggle new password"
            >
              {showNew ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
            </button>
          </div>
        </label>
        <label className="block text-sm">
          Confirm new password
          <input
            type="password"
            value={confirmPassword}
            onChange={(e) => setConfirmPassword(e.target.value)}
            className={fieldClass}
            required
            autoComplete="new-password"
          />
        </label>
        {error ? <p className="text-sm text-[var(--vf-danger)]">{error}</p> : null}
        <Button type="submit" className="w-full" disabled={submitting}>
          {submitting ? "Saving…" : "Update password"}
        </Button>
      </form>
    </Card>
  );
}

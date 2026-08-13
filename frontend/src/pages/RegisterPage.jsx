import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { registerMember } from "../api/adminApi";
import { getErrorMessage } from "../api/client";
import { useAuth } from "../auth/AuthContext";
import { BrandMark, Button } from "../components/ui";

export default function RegisterPage() {
  const navigate = useNavigate();
  const { establishSession } = useAuth();
  const [form, setForm] = useState({
    full_name: "",
    username: "",
    phone: "",
    password: "",
    gender: "Male" });
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const [saving, setSaving] = useState(false);
  const set = (key, value) => setForm((current) => ({ ...current, [key]: value }));

  async function submit(event) {
    event.preventDefault();
    setSaving(true);
    setError("");
    try {
      const payload = {
        full_name: form.full_name,
        username: form.username,
        phone: form.phone,
        password: form.password,
        gender: form.gender };
      const result = await registerMember(payload);
      if (!result?.token || !result?.user) {
        throw new Error("Registration succeeded but sign-in failed. Please sign in.");
      }
      establishSession(result.token, result.user);
      setSuccess(
        result.message ||
          "Account created. Opening your dashboard so you can choose a coach…",
      );
      const dest =
        result.user.must_change_password
          ? "/change-password"
          : "/member/coaches";
      navigate(dest, { replace: true });
    } catch (err) {
      setError(getErrorMessage(err));
    } finally {
      setSaving(false);
    }
  }

  const input =
    "mt-1.5 w-full rounded-[12px] border border-[var(--vf-border)] bg-[var(--vf-surface-muted)] px-3 py-2.5 outline-none ring-[var(--vf-accent)] focus:ring-2";

  return (
    <div className="relative flex min-h-screen items-center justify-center overflow-hidden p-4">
      <div className="absolute inset-0" style={{ background: "var(--vf-gradient)" }} />
      <main className="relative w-full max-w-lg rounded-[20px] bg-[var(--vf-surface)] p-7 shadow-2xl">
        <BrandMark />
        <h1 className="mt-7 text-2xl font-bold">Create your fitness account</h1>
        <p className="mt-2 text-sm text-[var(--vf-muted)]">
          You are registering as a member. After signup you can browse coaches and send a coaching request.
          Member accounts stay as members — coach roles are assigned by administrators only.
        </p>
        <form onSubmit={submit} className="mt-6 grid gap-4 sm:grid-cols-2">
          <label className="text-sm font-semibold sm:col-span-2">
            Full name
            <input
              required
              value={form.full_name}
              onChange={(e) => set("full_name", e.target.value)}
              className={input}
            />
          </label>
          <label className="text-sm font-semibold">
            Email
            <input
              required
              type="email"
              autoComplete="email"
              value={form.username}
              onChange={(e) => set("username", e.target.value)}
              className={input}
              placeholder="you@example.com"
            />
          </label>
          <label className="text-sm font-semibold">
            Phone
            <input value={form.phone} onChange={(e) => set("phone", e.target.value)} className={input} />
          </label>
          <label className="text-sm font-semibold sm:col-span-2">
            Password
            <input
              type="password"
              minLength="6"
              required
              value={form.password}
              onChange={(e) => set("password", e.target.value)}
              className={input}
            />
          </label>
          <fieldset className="text-sm font-semibold sm:col-span-2">
            <legend>Gender</legend>
            <div className="mt-2 flex gap-4">
              {["Male", "Female"].map((gender) => (
                <label key={gender} className="font-normal">
                  <input
                    className="mr-2"
                    type="radio"
                    name="gender"
                    value={gender}
                    checked={form.gender === gender}
                    onChange={(e) => set("gender", e.target.value)}
                  />
                  {gender}
                </label>
              ))}
            </div>
          </fieldset>
          {error ? <p className="rounded bg-rose-50 p-3 text-sm text-rose-700 sm:col-span-2">{error}</p> : null}
          {success ? (
            <p className="rounded bg-emerald-50 p-3 text-sm text-emerald-700 sm:col-span-2">{success}</p>
          ) : null}
          <Button type="submit" className="sm:col-span-2" disabled={saving}>
            {"Create account"}
          </Button>
        </form>
        <p className="mt-5 text-center text-sm text-[var(--vf-muted)]">
          Already registered?{" "}
          <Link className="font-semibold text-[var(--vf-primary)]" to="/login">
            Sign in
          </Link>
        </p>
      </main>
    </div>
  );
}

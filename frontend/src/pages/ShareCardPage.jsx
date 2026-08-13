import { Link, useParams } from "react-router-dom";
import { useEffect, useState } from "react";
import { Droplets, Flame, HeartPulse, Share2, Dumbbell } from "lucide-react";
import { getShareCard } from "../api/memberApi";
import { getErrorMessage } from "../api/client";
import { BrandMark, Button, Card } from "../components/ui";

function Metric({ label, value, icon: Icon }) {
  return (
    <div className="rounded-[14px] bg-white/10 px-3 py-3 backdrop-blur-sm">
      <div className="flex items-center gap-2 text-xs uppercase tracking-wide text-white/70">
        {Icon ? <Icon className="h-3.5 w-3.5" /> : null}
        {label}
      </div>
      <p className="mt-1 text-xl font-bold text-white">{value ?? "—"}</p>
    </div>
  );
}

export default function ShareCardPage() {
  const { token } = useParams();
  const [card, setCard] = useState(null);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    getShareCard(token)
      .then((data) => {
        if (!cancelled) setCard(data);
      })
      .catch((err) => {
        if (!cancelled) setError(getErrorMessage(err));
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [token]);

  

  if (error) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-[var(--vf-bg)] p-4">
        <Card className="max-w-md p-8 text-center">
          <BrandMark />
          <h1 className="mt-6 text-xl font-bold">Share link unavailable</h1>
          <p className="mt-2 text-sm text-[var(--vf-muted)]">
            {error || "This card may have expired or been removed."}
          </p>
          <Link to="/register" className="mt-6 inline-block">
            <Button>Join Vital Fitness</Button>
          </Link>
        </Card>
      </div>
    );
  }

  if (!card) {
    return <div className="min-h-screen bg-[var(--vf-bg)]" />;
  }

  const p = card.payload || {};
  const isWorkout = card.type === "workout";
  const joinHref =
    card.joinPath ||
    (card.inviteCode ? `/register?ref=${encodeURIComponent(card.inviteCode)}` : "/register");

  return (
    <div className="relative flex min-h-screen items-center justify-center overflow-hidden p-4">
      <div className="absolute inset-0" style={{ background: "var(--vf-gradient)" }} />
      <main className="relative w-full max-w-lg">
        <div className="mb-4 flex justify-center">
          <BrandMark light />
        </div>
        <div
          className="overflow-hidden rounded-[24px] p-6 text-white shadow-2xl"
          style={{ background: "linear-gradient(145deg, #2b3a7a 0%, #3D4F9F 45%, #5B6FD6 100%)" }}
        >
          <div className="flex items-center gap-2 text-xs font-bold uppercase tracking-[0.18em] text-white/70">
            <Share2 className="h-4 w-4" />
            {isWorkout ? "Workout win" : card.type === "weekly" ? "Weekly win" : "Progress"}
          </div>
          <h1 className="mt-4 text-3xl font-bold">
            {isWorkout
              ? `${p.displayName} crushed a workout`
              : `${p.displayName}'s Vital Fitness progress`}
          </h1>
          <p className="mt-2 text-sm text-white/85">
            {isWorkout
              ? p.headline || "Just finished a workout"
              : p.periodLabel || "Last 7 days"}
            {p.coachedBy ? ` · Coached by ${p.coachedBy}` : ""}
          </p>

          {isWorkout ? (
            <div className="mt-6 rounded-[16px] bg-white/10 p-4">
              <div className="flex items-center gap-2 text-sm text-white/70">
                <Dumbbell className="h-4 w-4" />
                Session
              </div>
              <p className="mt-1 text-2xl font-bold">{p.workoutTitle || "Workout"}</p>
              {p.level ? <p className="mt-1 text-sm text-white/75">Level: {p.level}</p> : null}
            </div>
          ) : (
            <div className="mt-6 grid grid-cols-2 gap-3">
              <Metric label="Workouts" value={p.metrics?.workoutsCompleted ?? 0} icon={Dumbbell} />
              <Metric
                label="Diet adherence"
                value={
                  p.metrics?.dietAdherencePercent != null
                    ? `${p.metrics.dietAdherencePercent}%`
                    : "—"
                }
                icon={HeartPulse}
              />
              <Metric
                label="Water"
                value={
                  p.metrics?.waterMl != null
                    ? `${Math.round(p.metrics.waterMl / 100) / 10} L`
                    : "—"
                }
                icon={Droplets}
              />
              <Metric
                label="Calories out"
                value={p.metrics?.caloriesOut != null ? Math.round(p.metrics.caloriesOut) : "—"}
                icon={Flame}
              />
            </div>
          )}

          {!isWorkout && p.metrics?.bmi != null ? (
            <p className="mt-4 text-sm text-white/80">BMI snapshot: {p.metrics.bmi}</p>
          ) : null}
        </div>

        <Card className="mt-4 p-5 text-center">
          <p className="text-sm text-[var(--vf-muted)]">
            Inspired? Start your own journey with Vital Fitness.
          </p>
          <Link to={joinHref} className="mt-4 inline-block w-full sm:w-auto">
            <Button className="w-full">Join Vital Fitness</Button>
          </Link>
          <p className="mt-3 text-xs text-[var(--vf-muted)]">
            Already a member?{" "}
            <Link className="font-semibold text-[var(--vf-primary)]" to="/login">
              Sign in
            </Link>
          </p>
        </Card>
      </main>
    </div>
  );
}

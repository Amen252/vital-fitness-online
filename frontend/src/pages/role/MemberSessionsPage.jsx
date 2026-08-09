import { CalendarDays, CheckCircle2, Clock, Link2, Video, XCircle } from "lucide-react";
import { useCallback, useEffect, useState } from "react";
import { cancelSession, getSessions } from "../../api/sessionApi";
import { getErrorMessage } from "../../api/client";
import { Badge, Button, Card, Spinner, useToast } from "../../components/ui";
import { formatWhen } from "./roleHelpers";

const STATUS_TONE = {
  pending: "amber",
  confirmed: "green",
  in_progress: "blue",
  completed: "blue",
  cancelled: "red",
  rescheduled: "amber",
  no_show: "red",
};

const STATUS_ICON = {
  confirmed: <CheckCircle2 className="h-4 w-4 text-emerald-500" />,
  in_progress: <Video className="h-4 w-4 text-sky-500" />,
  completed: <CheckCircle2 className="h-4 w-4 text-[var(--vf-accent)]" />,
  pending: <Clock className="h-4 w-4 text-amber-500" />,
  rescheduled: <Clock className="h-4 w-4 text-amber-500" />,
  cancelled: <XCircle className="h-4 w-4 text-red-400" />,
  no_show: <XCircle className="h-4 w-4 text-red-500" />,
};

function statusLabel(status = "") {
  switch (status) {
    case "confirmed":
      return "Confirmed";
    case "in_progress":
      return "In Progress";
    case "no_show":
      return "Missed";
    default:
      return String(status).replaceAll("_", " ") || "Pending";
  }
}

function CoachAvatar({ coach = {} }) {
  const name = coach.full_name || coach.username || coach.name || "Coach";
  const photo = coach.avatar || coach.photoUrl || "";
  if (photo) {
    return <img src={photo} alt={name} className="h-11 w-11 rounded-full object-cover border border-[var(--vf-border)]" />;
  }
  return (
    <div className="flex h-11 w-11 items-center justify-center rounded-full bg-[color-mix(in_srgb,var(--vf-primary)_18%,white)] text-sm font-bold text-[var(--vf-primary)]">
      {name.trim().charAt(0).toUpperCase() || "C"}
    </div>
  );
}

export default function MemberSessionsPage() {
  const toast = useToast();
  const [sessions, setSessions] = useState([]);
  const [loading, setLoading] = useState(true);
  const [busyId, setBusyId] = useState("");
  const [filter, setFilter] = useState("upcoming");

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const data = await getSessions();
      setSessions(Array.isArray(data) ? data : []);
    } catch (err) {
      toast.error(getErrorMessage(err));
    } finally {
      setLoading(false);
    }
  }, [toast]);

  useEffect(() => {
    load();
  }, [load]);

  useEffect(() => {
    const id = window.setInterval(() => {
      getSessions().then((data) => setSessions(Array.isArray(data) ? data : [])).catch(() => {});
    }, 20000);
    const onFocus = () => {
      getSessions().then((data) => setSessions(Array.isArray(data) ? data : [])).catch(() => {});
    };
    window.addEventListener("focus", onFocus);
    return () => {
      window.clearInterval(id);
      window.removeEventListener("focus", onFocus);
    };
  }, []);

  async function handleCancel(id) {
    setBusyId(id);
    try {
      await cancelSession(id);
      setSessions((prev) =>
        prev.map((s) =>
          s._id === id || s.id === id ? { ...s, status: "cancelled" } : s,
        ),
      );
      toast.success("Session cancelled");
      void load();
    } catch (err) {
      toast.error(getErrorMessage(err));
    } finally {
      setBusyId("");
    }
  }

  const now = new Date();
  const filtered = sessions.filter((s) => {
    const dt = new Date(s.date);
    if (filter === "upcoming") {
      if (["completed", "cancelled", "no_show"].includes(s.status)) return false;
      if (s.status === "in_progress") return true;
      return dt >= new Date(now.getTime() - 60 * 60 * 1000);
    }
    if (filter === "past") {
      return ["completed", "cancelled", "no_show"].includes(s.status) || (dt < now && s.status !== "in_progress");
    }
    return true;
  });

  return (
    <>
      <div className="rounded-[20px] p-8 text-white" style={{ background: "var(--vf-gradient)" }}>
        <CalendarDays className="h-9 w-9" />
        <h1 className="mt-5 text-3xl font-bold">1-on-1 Sessions</h1>
        <p className="mt-2 text-white/85">
          Sessions your coach creates for you. Separate from appointment booking requests.
        </p>
      </div>

      <Card className="mt-5 p-6">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <h2 className="text-xl font-bold">Your sessions</h2>
          <div className="flex items-center gap-2">
            <select
              value={filter}
              onChange={(e) => setFilter(e.target.value)}
              className="rounded-[10px] border border-[var(--vf-border)] bg-[var(--vf-surface-muted)] px-3 py-2 text-sm"
            >
              <option value="upcoming">Upcoming</option>
              <option value="past">History</option>
              <option value="all">All</option>
            </select>
            <Button size="sm" variant="secondary" onClick={load} disabled={loading}>
              {loading ? "…" : "Refresh"}
            </Button>
          </div>
        </div>

        {loading ? (
          <div className="mt-6"><Spinner label="Loading sessions…" /></div>
        ) : (
          <ul className="mt-4 space-y-3">
            {filtered.length === 0 ? (
              <li className="rounded-[12px] border border-[var(--vf-border)] px-4 py-10 text-center">
                <CalendarDays className="mx-auto h-8 w-8 text-[var(--vf-muted)]" />
                <p className="mt-3 font-medium">No sessions yet</p>
                <p className="mt-1 text-sm text-[var(--vf-muted)]">
                  When your coach schedules a 1-on-1 session, it appears here automatically.
                </p>
              </li>
            ) : (
              filtered.map((s) => {
                const coach = s.coach || {};
                const canCancel = ["pending", "confirmed", "rescheduled"].includes(s.status);
                const canJoin =
                  Boolean(s.meetingLink) &&
                  ["confirmed", "rescheduled", "in_progress"].includes(s.status);
                return (
                  <li key={s._id} className="rounded-[12px] border border-[var(--vf-border)] bg-[var(--vf-surface)] px-4 py-4">
                    <div className="flex flex-wrap items-start justify-between gap-3">
                      <div className="flex flex-1 gap-3">
                        <CoachAvatar coach={coach} />
                        <div>
                          <div className="flex flex-wrap items-center gap-2">
                            {STATUS_ICON[s.status] || null}
                            <p className="font-semibold">
                              {coach.full_name || coach.username || coach.name || "Your coach"}
                            </p>
                            <Badge tone={STATUS_TONE[s.status] || "slate"}>{statusLabel(s.status)}</Badge>
                          </div>
                          <p className="mt-1 text-sm text-[var(--vf-muted)]">
                            {formatWhen(s.date)} · {s.durationMinutes || 60} min ·{" "}
                            {s.sessionMode === "online" ? "Online" : "In Person"}
                          </p>
                          {s.notes ? <p className="mt-2 text-sm"><span className="font-medium">Goal: </span>{s.notes}</p> : null}
                          {s.status === "completed" && s.coachNotes ? (
                            <p className="mt-2 rounded-[8px] bg-[color-mix(in_srgb,var(--vf-primary)_10%,white)] px-3 py-2 text-sm">
                              <span className="font-medium">Coach notes: </span>{s.coachNotes}
                            </p>
                          ) : null}
                          {Array.isArray(s.attachments) && s.attachments.length > 0 ? (
                            <div className="mt-2 text-sm">
                              {s.attachments.map((file, idx) => (
                                <a key={`${file.url}-${idx}`} href={file.url} target="_blank" rel="noreferrer" className="mr-3 text-[var(--vf-primary)]">
                                  {file.name || `Attachment ${idx + 1}`}
                                </a>
                              ))}
                            </div>
                          ) : null}
                        </div>
                      </div>
                      <div className="flex flex-wrap gap-2">
                        {canJoin ? (
                          <a
                            href={s.meetingLink}
                            target="_blank"
                            rel="noreferrer"
                            className="inline-flex items-center rounded-[10px] bg-[var(--vf-primary)] px-3 py-1.5 text-xs font-semibold text-white"
                          >
                            <Link2 className="mr-1 h-3.5 w-3.5" /> Join
                          </a>
                        ) : null}
                        {canCancel ? (
                          <Button size="sm" variant="danger" disabled={busyId === s._id} onClick={() => handleCancel(s._id)}>
                            {busyId === s._id ? "Cancelling…" : "Cancel"}
                          </Button>
                        ) : null}
                      </div>
                    </div>
                  </li>
                );
              })
            )}
          </ul>
        )}
      </Card>
    </>
  );
}

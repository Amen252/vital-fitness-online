import { CalendarDays, CheckCircle2, Clock, XCircle } from "lucide-react";
import { useCallback, useEffect, useState } from "react";
import { getUserAppointments, cancelUserAppointment } from "../../api/memberApi";
import { getErrorMessage } from "../../api/client";
import { Badge, Button, Card, Spinner, useToast } from "../../components/ui";
import { formatWhen } from "./roleHelpers";

const STATUS_TONE = {
  pending: "amber",
  approved: "green",
  completed: "blue",
  rejected: "red",
  cancelled: "red",
  rescheduled: "amber",
};

const STATUS_ICON = {
  approved: <CheckCircle2 className="h-4 w-4 text-emerald-500" />,
  completed: <CheckCircle2 className="h-4 w-4 text-[var(--vf-accent)]" />,
  pending: <Clock className="h-4 w-4 text-amber-500" />,
  rescheduled: <Clock className="h-4 w-4 text-amber-500" />,
  rejected: <XCircle className="h-4 w-4 text-red-500" />,
  cancelled: <XCircle className="h-4 w-4 text-red-400" />,
};

export default function MemberAppointmentsPage() {
  const toast = useToast();
  const [appointments, setAppointments] = useState([]);
  const [loading, setLoading] = useState(true);
  const [busyId, setBusyId] = useState("");
  const [filter, setFilter] = useState("upcoming");

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const data = await getUserAppointments();
      setAppointments(Array.isArray(data) ? data : []);
    } catch (err) {
      toast.error(getErrorMessage(err));
    } finally {
      setLoading(false);
    }
  }, [toast]);

  useEffect(() => {
    load();
  }, [load]);

  async function handleCancel(id) {
    setBusyId(id);
    try {
      await cancelUserAppointment(id);
      toast.success("Appointment cancelled");
      await load();
    } catch (err) {
      toast.error(getErrorMessage(err));
    } finally {
      setBusyId("");
    }
  }

  const now = new Date();
  const filtered = appointments.filter((a) => {
    const dt = new Date(a.dateTime || a.datetime);
    if (filter === "upcoming") return dt >= now && ["pending", "approved", "rescheduled"].includes(a.status);
    if (filter === "past") return dt < now || ["completed", "cancelled", "rejected"].includes(a.status);
    return true;
  });

  const stats = {
    total: appointments.length,
    upcoming: appointments.filter((a) => {
      const dt = new Date(a.dateTime || a.datetime);
      return dt >= now && ["pending", "approved", "rescheduled"].includes(a.status);
    }).length,
    completed: appointments.filter((a) => a.status === "completed").length,
  };

  return (
    <>
      {/* Hero */}
      <div className="rounded-[20px] p-8 text-white" style={{ background: "var(--vf-gradient)" }}>
        <CalendarDays className="h-9 w-9" />
        <h1 className="mt-5 text-3xl font-bold">My appointments</h1>
        <p className="mt-2 text-white/85">
          Track sessions scheduled by your coach.
        </p>
      </div>

      {/* Stats */}
      <div className="mt-5 grid gap-3 sm:grid-cols-3">
        <Card className="p-4">
          <p className="text-xs font-semibold uppercase tracking-wide text-[var(--vf-muted)]">Total</p>
          <p className="mt-2 text-2xl font-bold">{stats.total}</p>
        </Card>
        <Card className="p-4">
          <p className="text-xs font-semibold uppercase tracking-wide text-[var(--vf-muted)]">Upcoming</p>
          <p className="mt-2 text-2xl font-bold text-emerald-600">{stats.upcoming}</p>
        </Card>
        <Card className="p-4">
          <p className="text-xs font-semibold uppercase tracking-wide text-[var(--vf-muted)]">Completed</p>
          <p className="mt-2 text-2xl font-bold text-[var(--vf-accent)]">{stats.completed}</p>
        </Card>
      </div>

      {/* List */}
      <Card className="mt-5 p-6">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <h2 className="text-xl font-bold">Sessions</h2>
          <div className="flex items-center gap-2">
            <select
              value={filter}
              onChange={(e) => setFilter(e.target.value)}
              className="rounded-[10px] border border-[var(--vf-border)] bg-[var(--vf-surface-muted)] px-3 py-2 text-sm"
            >
              <option value="upcoming">Upcoming</option>
              <option value="past">Past</option>
              <option value="all">All</option>
            </select>
            <Button size="sm" variant="secondary" onClick={load} disabled={loading}>
              {loading ? "…" : "Refresh"}
            </Button>
          </div>
        </div>

        {loading ? (
          <div className="mt-6">
            <Spinner label="Loading appointments…" />
          </div>
        ) : (
          <ul className="mt-4 space-y-3">
            {filtered.length === 0 ? (
              <li className="rounded-[12px] border border-[var(--vf-border)] px-4 py-10 text-center">
                <CalendarDays className="mx-auto h-8 w-8 text-[var(--vf-muted)]" />
                <p className="mt-3 text-sm text-[var(--vf-muted)]">
                  {filter === "upcoming"
                    ? "No upcoming appointments. Your coach will schedule sessions for you."
                    : "No appointments found."}
                </p>
              </li>
            ) : (
              filtered.map((a) => {
                const coach = a.coach || {};
                const canCancel = ["pending", "approved", "rescheduled"].includes(a.status);
                return (
                  <li
                    key={a._id}
                    className="rounded-[12px] border border-[var(--vf-border)] bg-[var(--vf-surface)] px-4 py-4 transition-shadow hover:shadow-sm"
                  >
                    <div className="flex flex-wrap items-start justify-between gap-3">
                      <div className="flex-1">
                        <div className="flex items-center gap-2">
                          {STATUS_ICON[a.status] || null}
                          <p className="font-semibold">
                            {coach.full_name || coach.username || "Your coach"}
                          </p>
                          <Badge tone={STATUS_TONE[a.status] || "slate"}>
                            {a.status}
                          </Badge>
                        </div>
                        <p className="mt-1 text-sm text-[var(--vf-muted)]">
                          {formatWhen(a.dateTime || a.datetime)}
                          {a.durationMinutes ? ` · ${a.durationMinutes} min` : ""}
                        </p>
                        {a.notes ? (
                          <p className="mt-2 rounded-[8px] bg-[var(--vf-surface-muted)] px-3 py-2 text-sm">
                            <span className="font-medium">Notes: </span>{a.notes}
                          </p>
                        ) : null}
                        {a.coachNotes ? (
                          <p className="mt-2 rounded-[8px] bg-[color-mix(in_srgb,var(--vf-primary)_10%,white)] px-3 py-2 text-sm text-[var(--vf-primary-deep)] dark:bg-[color-mix(in_srgb,var(--vf-primary)_22%,black)] dark:text-[var(--vf-primary-light)]">
                            <span className="font-medium">Coach notes: </span>{a.coachNotes}
                          </p>
                        ) : null}
                      </div>
                      {canCancel ? (
                        <Button
                          size="sm"
                          variant="danger"
                          disabled={busyId === a._id}
                          onClick={() => handleCancel(a._id)}
                        >
                          {busyId === a._id ? "Cancelling…" : "Cancel"}
                        </Button>
                      ) : null}
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

import { useEffect, useMemo, useState } from "react";
import { CalendarDays, CheckCircle2, Clock, TrendingUp, XCircle } from "lucide-react";
import { getAppointments } from "../api/adminApi";
import { getErrorMessage, withHardTimeout } from "../api/client";
import {
  Badge,
  Breadcrumbs,
  Card,
  DataTable,
  ErrorState,
  PageHeader } from "../components/ui";

const TONE = {
  pending: "amber",
  approved: "green",
  completed: "blue",
  rejected: "red",
  cancelled: "red",
  rescheduled: "amber" };

function Stat({ icon: Icon, label, value, color = "text-[var(--vf-primary)]" }) {
  return (
    <Card className="p-5">
      <div className={`flex items-center gap-2 text-xs font-semibold uppercase tracking-wide text-[var(--vf-muted)]`}>
        <Icon className={`h-4 w-4 ${color}`} />
        {label}
      </div>
      <p className="mt-2 text-3xl font-bold">{value}</p>
    </Card>
  );
}

export default function AppointmentsPage() {
  const [appointments, setAppointments] = useState([]);
  const [status, setStatus] = useState("all");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  async function load() {
    setLoading(true);
    setError("");
    try {
      const data = await withHardTimeout(getAppointments({ status }));
      setAppointments(data.appointments || []);
    } catch (err) {
      setError(getErrorMessage(err));
      setAppointments([]);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    load();
  }, [status]);

  // Compute stats from ALL appointments (always fetch all for stats)
  const [allAppointments, setAllAppointments] = useState([]);
  useEffect(() => {
    getAppointments({ status: "all" })
      .then((d) => setAllAppointments(d.appointments || []))
      .catch(() => {});
  }, []);

  const stats = useMemo(() => {
    const now = new Date();
    return {
      total: allAppointments.length,
      upcoming: allAppointments.filter((a) => {
        const dt = new Date(a.dateTime);
        return dt >= now && ["pending", "approved", "rescheduled"].includes(a.status);
      }).length,
      completed: allAppointments.filter((a) => a.status === "completed").length,
      cancelled: allAppointments.filter((a) => ["cancelled", "rejected"].includes(a.status)).length };
  }, [allAppointments]);

  const columns = useMemo(
    () => [
      {
        key: "dateTime",
        header: "When",
        sortable: true,
        render: (row) =>
          row.dateTime ? new Date(row.dateTime).toLocaleString() : "—" },
      {
        key: "client.full_name",
        header: "Client",
        sortable: true,
        sortKey: "client.full_name",
        render: (row) => (
          <div>
            <p className="font-medium">{row.client?.full_name || row.client?.username || "—"}</p>
            <p className="text-xs text-[var(--vf-muted)]">@{row.client?.username}</p>
          </div>
        ) },
      {
        key: "coach.full_name",
        header: "Coach",
        sortable: true,
        sortKey: "coach.full_name",
        render: (row) => (
          <div>
            <p className="font-medium">{row.coach?.full_name || row.coach?.username || "—"}</p>
            <p className="text-xs text-[var(--vf-muted)]">@{row.coach?.username}</p>
          </div>
        ) },
      {
        key: "durationMinutes",
        header: "Duration",
        render: (row) => (
          <span className="text-sm text-[var(--vf-muted)]">
            {row.durationMinutes ? `${row.durationMinutes} min` : "—"}
          </span>
        ) },
      {
        key: "status",
        header: "Status",
        sortable: true,
        render: (row) => (
          <Badge tone={TONE[row.status] || "slate"}>{row.status}</Badge>
        ) },
      {
        key: "type",
        header: "Type",
        render: (row) => (
          <span className="text-xs text-[var(--vf-muted)]">
            {(row.type || "—").replace(/_/g, " ")}
          </span>
        ) },
    ],
    [],
  );

  return (
    <div>
      <PageHeader
        title="Appointments"
        subtitle="All coaching sessions across the platform"
        breadcrumbs={
          <Breadcrumbs
            items={[{ label: "Home", to: "/" }, { label: "Appointments" }]}
          />
        }
      />

      {/* Stats row */}
      <div className="mt-1 mb-6 grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <Stat icon={CalendarDays} label="Total" value={stats.total} />
        <Stat icon={Clock} label="Upcoming" value={stats.upcoming} color="text-emerald-500" />
        <Stat icon={CheckCircle2} label="Completed" value={stats.completed} color="text-[var(--vf-accent)]" />
        <Stat icon={XCircle} label="Cancelled / Rejected" value={stats.cancelled} color="text-red-400" />
      </div>

      
      {error ? <ErrorState message={error} onRetry={load} /> : null}

      {!loading && !error ? (
        <DataTable
          columns={columns}
          rows={appointments}
          searchKeys={[
            "client.full_name",
            "client.username",
            "coach.full_name",
            "coach.username",
          ]}
          searchPlaceholder="Search client or coach"
          emptyIcon={CalendarDays}
          emptyTitle="No appointments found"
          filters={
            <select
              value={status}
              onChange={(e) => setStatus(e.target.value)}
              className="rounded-[12px] border border-[var(--vf-border)] bg-[var(--vf-surface-muted)] px-3 py-2.5 text-sm"
            >
              <option value="all">All statuses</option>
              <option value="pending">Pending</option>
              <option value="approved">Approved</option>
              <option value="completed">Completed</option>
              <option value="rejected">Rejected</option>
              <option value="cancelled">Cancelled</option>
            </select>
          }
        />
      ) : null}
    </div>
  );
}

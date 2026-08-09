import {
  Area,
  AreaChart,
  Bar,
  BarChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import {
  Activity,
  CalendarDays,
  Droplets,
  Flame,
  RefreshCw,
  UserCheck,
  Users,
  UserRound,
  UtensilsCrossed,
  Dumbbell,
} from "lucide-react";
import { Link } from "react-router-dom";
import {
  getDashboard,
  getStatistics,
  getCoachApplications,
} from "../api/adminApi";
import { useEffect, useMemo, useState } from "react";
import useStableFetch from "../hooks/useStableFetch";
import { formatDate } from "../utils/profileDisplay";
import {
  Badge,
  Breadcrumbs,
  Button,
  Card,
  ErrorState,
  LoadingBlock,
  PageHeader,
  Skeleton,
  StatCard,
} from "../components/ui";

export default function DashboardPage() {
  const [coachApplications, setCoachApplications] = useState([]);

  const { data, loading, error, reload } = useStableFetch(
    () =>
      Promise.all([
        getDashboard(),
        getStatistics(),
      ]).then(([dashboard, statistics]) => ({
        stats: dashboard,
        charts: statistics,
        pendingApps: dashboard?.pendingCoachApplications ?? 0,
      })),
    [],
  );
  const stats = data?.stats;
  const charts = data?.charts;
  const pendingApps = data?.pendingApps ?? 0;

  async function loadCoachApplications() {
    try {
      const apps = await getCoachApplications("all");
      setCoachApplications(Array.isArray(apps) ? apps : []);
    } catch {
      /* keep last snapshot */
    }
  }

  useEffect(() => {
    loadCoachApplications();
    const timer = setInterval(loadCoachApplications, 12000);
    const onFocus = () => loadCoachApplications();
    window.addEventListener("focus", onFocus);
    const onVisibility = () => {
      if (document.visibilityState === "visible") onFocus();
    };
    document.addEventListener("visibilitychange", onVisibility);
    return () => {
      clearInterval(timer);
      window.removeEventListener("focus", onFocus);
      document.removeEventListener("visibilitychange", onVisibility);
    };
  }, []);

  const applicationCounts = useMemo(
    () => ({
      pending: coachApplications.filter((a) => a.status === "pending").length,
      approved: coachApplications.filter((a) => a.status === "approved").length,
      rejected: coachApplications.filter((a) => a.status === "rejected").length,
    }),
    [coachApplications],
  );

  const recentApplications = useMemo(
    () => coachApplications.slice(0, 8),
    [coachApplications],
  );

  function applicationStatusTone(status) {
    if (status === "approved") return "green";
    if (status === "rejected") return "red";
    return "amber";
  }

  if (loading && !stats) {
    return (
      <div>
        <PageHeader
          title="Dashboard"
          subtitle="Loading live metrics…"
          breadcrumbs={
            <Breadcrumbs items={[{ label: "Home" }, { label: "Dashboard" }]} />
          }
        />
        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
          {Array.from({ length: 8 }).map((_, i) => (
            <Skeleton key={i} className="h-28 w-full rounded-[16px]" />
          ))}
        </div>
        <div className="mt-6">
          <LoadingBlock rows={3} />
        </div>
      </div>
    );
  }

  if (error) return <ErrorState message={error} onRetry={reload} />;
  if (!stats)
    return (
      <ErrorState message="Dashboard data is unavailable" onRetry={reload} />
    );

  const growth = (charts?.userGrowth || []).map((row) => ({
    day: row._id,
    count: row.count,
  }));
  const meals = (charts?.mealsByDay || []).map((row) => ({
    day: row._id,
    calories: row.totalCalories,
  }));
  const water = (charts?.waterByDay || []).map((row) => ({
    day: row._id,
    ml: row.totalMl,
  }));
  const weekly = (charts?.weeklyActivity || []).map((row) => ({
    day: row._id,
    count: row.count,
    calories: row.calories,
  }));
  const workouts = (charts?.workoutCompletionsByDay || []).map((row) => ({
    day: row._id,
    count: row.count,
  }));
  const diet = (charts?.dietCompletionsByDay || []).map((row) => ({
    day: row._id,
    count: row.count,
  }));
  const appointments = (charts?.appointmentsByStatus || []).map((row) => ({
    status: row._id || "unknown",
    count: row.count,
  }));

  return (
    <div>
      <PageHeader
        title="Dashboard"
        subtitle="Realtime Vital Fitness metrics from the shared MongoDB"
        breadcrumbs={
          <Breadcrumbs
            items={[{ label: "Home", to: "/" }, { label: "Dashboard" }]}
          />
        }
        action={
          <Button
            onClick={() => {
              reload();
              loadCoachApplications();
            }}
          >
            <RefreshCw className="h-4 w-4" />
            Refresh
          </Button>
        }
      />

      <div
        className="mb-6 overflow-hidden rounded-[20px] p-6 text-white shadow-lg vf-animate-in"
        style={{ background: "var(--vf-gradient)" }}
      >
        <p className="text-xs uppercase tracking-[0.2em] text-white/75">
          Vital Fitness Admin
        </p>
        <h2 className="mt-2 text-2xl font-bold md:text-3xl">Welcome back</h2>
        <p className="mt-2 max-w-2xl text-sm text-white/85">
          Monitor users and activities, approve or reject coach applications, and manage coach
          accounts while keeping the platform running efficiently.
        </p>
      </div>

      {(pendingApps || 0) > 0 ? (
        <div className="mb-6 flex flex-wrap items-center justify-between gap-3 rounded-[16px] border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-950">
          <p>
            <strong>{pendingApps}</strong> coach application
            {pendingApps === 1 ? "" : "s"} waiting for your approval.
          </p>
          <Link
            to="/coaches?tab=applications"
            className="inline-flex items-center justify-center gap-2 rounded-[12px] border border-[var(--vf-border)] bg-[var(--vf-surface-muted)] px-3 py-1.5 text-xs font-semibold text-[var(--vf-text)] hover:bg-[var(--vf-border)]/40"
          >
            Review applications
          </Link>
        </div>
      ) : null}

      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard
          label="Total Users"
          value={stats.totalUsers}
          icon={Users}
          tone="primary"
        />
        <StatCard
          label="Active Users"
          value={stats.activeUsers}
          hint="status = active"
          icon={UserCheck}
          tone="success"
        />
        <StatCard
          label="Total Coaches"
          value={stats.totalCoaches}
          icon={UserRound}
          tone="accent"
        />
        <StatCard
          label="Pending Coach Approvals"
          value={pendingApps}
          hint="approve or reject registrations"
          icon={Activity}
          tone="warning"
        />
        <StatCard
          label="Appointments"
          value={stats.totalAppointments}
          hint={`${stats.pendingAppointments || 0} pending`}
          icon={CalendarDays}
          tone="warning"
        />
        <StatCard
          label="Total Diet Plans"
          value={stats.totalDietPlans}
          hint={`${stats.activeDietPlans || 0} active`}
          icon={UtensilsCrossed}
          tone="success"
        />
        <StatCard
          label="Completed Workouts"
          value={stats.completedWorkouts}
          icon={Dumbbell}
          tone="pink"
        />
        <StatCard
          label="Calories Burned"
          value={stats.totalCaloriesBurned}
          icon={Flame}
          tone="accent"
        />
        <StatCard
          label="Water Intake (ml)"
          value={stats.totalWaterMl}
          icon={Droplets}
          tone="accent"
        />
      </div>

      <Card className="mt-6 p-5 vf-animate-in">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h3 className="font-bold text-[var(--vf-text)]">Coach registration requests</h3>
            <p className="mt-1 text-sm text-[var(--vf-muted)]">
              Pending, approved, and rejected applications — synced from the database.
            </p>
          </div>
          <Link
            to="/coaches?tab=applications"
            className="inline-flex items-center justify-center rounded-[12px] border border-[var(--vf-border)] bg-[var(--vf-surface-muted)] px-3 py-1.5 text-xs font-semibold text-[var(--vf-text)] hover:bg-[var(--vf-border)]/40"
          >
            Manage registrations
          </Link>
        </div>
        <div className="mt-4 flex flex-wrap gap-2">
          <Badge tone="amber">Pending {applicationCounts.pending}</Badge>
          <Badge tone="green">Approved {applicationCounts.approved}</Badge>
          <Badge tone="red">Rejected {applicationCounts.rejected}</Badge>
        </div>
        <ul className="mt-4 space-y-2">
          {recentApplications.length === 0 ? (
            <li className="text-sm text-[var(--vf-muted)]">No coach registration requests yet.</li>
          ) : (
            recentApplications.map((app) => {
              const name =
                app.user?.full_name || app.user?.username || app.user?.email || "Applicant";
              const status = app.status || "pending";
              return (
                <li key={app._id}>
                  <Link
                    to={`/coaches/applications/${app._id}`}
                    className="flex flex-wrap items-center justify-between gap-3 rounded-[12px] border border-[var(--vf-border)] px-3 py-2 text-sm transition hover:border-[var(--vf-primary)] hover:bg-[var(--vf-surface-muted)]/50"
                  >
                    <div className="min-w-0">
                      <p className="truncate font-semibold">{name}</p>
                      <p className="truncate text-xs text-[var(--vf-muted)]">
                        {app.specialization || "—"}
                        {app.createdAt ? ` · Applied ${formatDate(app.createdAt)}` : ""}
                        {app.reviewedAt ? ` · Reviewed ${formatDate(app.reviewedAt)}` : ""}
                      </p>
                    </div>
                    <Badge tone={applicationStatusTone(status)}>
                      {status.charAt(0).toUpperCase() + status.slice(1)}
                    </Badge>
                  </Link>
                </li>
              );
            })
          )}
        </ul>
      </Card>

      <div className="mt-6 grid gap-4 xl:grid-cols-2">
        <ChartCard title="Weekly activity">
          <ResponsiveContainer width="100%" height={260}>
            <BarChart data={weekly}>
              <CartesianGrid strokeDasharray="3 3" stroke="var(--vf-border)" />
              <XAxis
                dataKey="day"
                tick={{ fill: "var(--vf-muted)", fontSize: 11 }}
              />
              <YAxis
                allowDecimals={false}
                tick={{ fill: "var(--vf-muted)", fontSize: 11 }}
              />
              <Tooltip />
              <Bar
                dataKey="count"
                name="Logs"
                fill="#3D4F9F"
                radius={[8, 8, 0, 0]}
              />
            </BarChart>
          </ResponsiveContainer>
        </ChartCard>

        <ChartCard title="Monthly user growth">
          <ResponsiveContainer width="100%" height={260}>
            <AreaChart data={growth}>
              <defs>
                <linearGradient id="growthFill" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor="#3D4F9F" stopOpacity={0.35} />
                  <stop offset="100%" stopColor="#3D4F9F" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="var(--vf-border)" />
              <XAxis
                dataKey="day"
                hide={growth.length > 10}
                tick={{ fill: "var(--vf-muted)", fontSize: 11 }}
              />
              <YAxis
                allowDecimals={false}
                tick={{ fill: "var(--vf-muted)", fontSize: 11 }}
              />
              <Tooltip />
              <Area
                type="monotone"
                dataKey="count"
                stroke="#3D4F9F"
                fill="url(#growthFill)"
                strokeWidth={2}
              />
            </AreaChart>
          </ResponsiveContainer>
        </ChartCard>

        <ChartCard title="Calories logged">
          <ResponsiveContainer width="100%" height={260}>
            <BarChart data={meals}>
              <CartesianGrid strokeDasharray="3 3" stroke="var(--vf-border)" />
              <XAxis
                dataKey="day"
                hide={meals.length > 10}
                tick={{ fill: "var(--vf-muted)", fontSize: 11 }}
              />
              <YAxis tick={{ fill: "var(--vf-muted)", fontSize: 11 }} />
              <Tooltip />
              <Bar dataKey="calories" fill="#0EA5E9" radius={[8, 8, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </ChartCard>

        <ChartCard title="Water intake">
          <ResponsiveContainer width="100%" height={260}>
            <BarChart data={water}>
              <CartesianGrid strokeDasharray="3 3" stroke="var(--vf-border)" />
              <XAxis
                dataKey="day"
                hide={water.length > 10}
                tick={{ fill: "var(--vf-muted)", fontSize: 11 }}
              />
              <YAxis tick={{ fill: "var(--vf-muted)", fontSize: 11 }} />
              <Tooltip />
              <Bar dataKey="ml" fill="#059669" radius={[8, 8, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </ChartCard>

        <ChartCard title="Workout completion">
          <ResponsiveContainer width="100%" height={260}>
            <AreaChart data={workouts}>
              <defs>
                <linearGradient id="workoutFill" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor="#DB2777" stopOpacity={0.35} />
                  <stop offset="100%" stopColor="#DB2777" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="var(--vf-border)" />
              <XAxis
                dataKey="day"
                hide={workouts.length > 10}
                tick={{ fill: "var(--vf-muted)", fontSize: 11 }}
              />
              <YAxis
                allowDecimals={false}
                tick={{ fill: "var(--vf-muted)", fontSize: 11 }}
              />
              <Tooltip />
              <Area
                type="monotone"
                dataKey="count"
                stroke="#DB2777"
                fill="url(#workoutFill)"
                strokeWidth={2}
              />
            </AreaChart>
          </ResponsiveContainer>
        </ChartCard>

        <ChartCard title="Diet completion">
          <ResponsiveContainer width="100%" height={260}>
            <BarChart data={diet}>
              <CartesianGrid strokeDasharray="3 3" stroke="var(--vf-border)" />
              <XAxis
                dataKey="day"
                hide={diet.length > 10}
                tick={{ fill: "var(--vf-muted)", fontSize: 11 }}
              />
              <YAxis
                allowDecimals={false}
                tick={{ fill: "var(--vf-muted)", fontSize: 11 }}
              />
              <Tooltip />
              <Bar dataKey="count" fill="#5B6FD6" radius={[8, 8, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </ChartCard>

        <Card className="p-5 vf-animate-in xl:col-span-2">
          <div className="grid gap-6 md:grid-cols-2">
            <div>
              <h3 className="font-bold text-[var(--vf-text)]">Appointments by status</h3>
              <div className="mt-4 space-y-3">
                {appointments.length === 0 ? (
                  <p className="text-sm text-[var(--vf-muted)]">
                    No appointment data yet.
                  </p>
                ) : (
                  appointments.map((row) => (
                    <div
                      key={row.status}
                      className="flex items-center justify-between rounded-[12px] bg-[var(--vf-surface-muted)] px-3 py-2 text-sm"
                    >
                      <span className="capitalize font-medium">
                        {row.status}
                      </span>
                      <span className="font-bold text-[var(--vf-primary)]">
                        {row.count}
                      </span>
                    </div>
                  ))
                )}
              </div>
            </div>
            <div>
              <h3 className="font-bold text-[var(--vf-text)]">Recent signups</h3>
              <ul className="mt-3 space-y-2">
                {(stats.recentSignups || []).length === 0 ? (
                  <li className="text-sm text-[var(--vf-muted)]">
                    No recent user signups.
                  </li>
                ) : (
                  stats.recentSignups.map((u) => (
                    <li
                      key={u._id || u.username}
                      className="flex items-center justify-between gap-3 rounded-[12px] border border-[var(--vf-border)] px-3 py-2 text-sm"
                    >
                      <div className="min-w-0">
                        <p className="truncate font-semibold">
                          {u.full_name || u.username || "—"}
                        </p>
                        <p className="truncate text-xs text-[var(--vf-muted)]">
                          @{u.username}
                          {u.self_registered ? " · self-registered" : ""}
                          {u.createdAt ? ` · ${formatDate(u.createdAt)}` : ""}
                        </p>
                      </div>
                      {u.self_registered ? (
                        <Badge tone="amber">Self-registered</Badge>
                      ) : (
                        <Badge tone="green">Admin-created</Badge>
                      )}
                    </li>
                  ))
                )}
              </ul>
            </div>
          </div>
        </Card>
      </div>
    </div>
  );
}

function ChartCard({ title, children }) {
  return (
    <Card className="p-5 vf-animate-in">
      <h3 className="mb-4 font-bold text-[var(--vf-text)]">{title}</h3>
      {children}
    </Card>
  );
}

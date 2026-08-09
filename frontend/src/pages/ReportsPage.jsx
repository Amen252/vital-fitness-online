import { useEffect, useState } from "react";
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
import { getReports } from "../api/adminApi";
import { getErrorMessage, withHardTimeout } from "../api/client";
import {
  Breadcrumbs,
  Button,
  Card,
  ErrorState,
  PageHeader,
  Spinner,
  StatCard,
} from "../components/ui";

export default function ReportsPage({ embedded = false }) {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  async function load() {
    setLoading(true);
    setError("");
    try {
      setData(await withHardTimeout(getReports()));
    } catch (err) {
      setError(getErrorMessage(err));
      setData(null);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    load();
  }, []);

  if (loading) return <Spinner label="Building analytics…" />;
  if (error) return <ErrorState message={error} onRetry={load} />;
  if (!data) return <ErrorState message="Unable to load data" onRetry={load} />;

  const meals = (data.mealsByDay || []).map((row) => ({
    day: row._id,
    calories: row.totalCalories,
  }));
  const water = (data.waterByDay || []).map((row) => ({
    day: row._id,
    ml: row.totalMl,
  }));
  const weight = (data.weightSeries || []).map((row) => ({
    day: row._id,
    weight: Number(row.avgWeight?.toFixed?.(1) ?? row.avgWeight),
  }));
  const workouts = (data.workoutCompletionsByDay || []).map((row) => ({
    day: row._id,
    count: row.count,
  }));
  const activities = (data.activityByType || []).map((row) => ({
    type: row._id || "Unknown",
    total: row.total,
  }));
  const growth = (data.userGrowth || []).map((row) => ({
    day: row._id,
    count: row.count,
  }));

  return (
    <div>
      {embedded ? null : (
        <PageHeader
          title="Reports"
          subtitle="Progress analytics from live collections"
          breadcrumbs={
            <Breadcrumbs
              items={[{ label: "Home", to: "/" }, { label: "Reports" }]}
            />
          }
          action={<Button onClick={load}>Refresh</Button>}
        />
      )}

      <div className="mb-6 grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
        <StatCard label="Users" value={data.totals?.users} />
        <StatCard label="Coaches" value={data.totals?.coaches} tone="accent" />
        <StatCard
          label="Appointments"
          value={data.totals?.appointments}
          tone="warning"
        />
        <StatCard label="Meal logs" value={data.totals?.meals} tone="success" />
        <StatCard
          label="Water (ml)"
          value={data.totals?.waterMl}
          tone="accent"
        />
        <StatCard
          label="Activities"
          value={data.totals?.activities}
          tone="pink"
        />
      </div>

      <div className="grid gap-4 xl:grid-cols-2">
        <ChartCard title="User growth">
          <ResponsiveContainer width="100%" height={250}>
            <AreaChart data={growth}>
              <defs>
                <linearGradient id="repGrowth" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor="#3D4F9F" stopOpacity={0.35} />
                  <stop offset="100%" stopColor="#3D4F9F" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="var(--vf-border)" />
              <XAxis
                dataKey="day"
                hide={growth.length > 12}
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
                fill="url(#repGrowth)"
                strokeWidth={2}
              />
            </AreaChart>
          </ResponsiveContainer>
        </ChartCard>

        <ChartCard title="Calories">
          <ResponsiveContainer width="100%" height={250}>
            <BarChart data={meals}>
              <CartesianGrid strokeDasharray="3 3" stroke="var(--vf-border)" />
              <XAxis
                dataKey="day"
                hide={meals.length > 12}
                tick={{ fill: "var(--vf-muted)", fontSize: 11 }}
              />
              <YAxis tick={{ fill: "var(--vf-muted)", fontSize: 11 }} />
              <Tooltip />
              <Bar dataKey="calories" fill="#0EA5E9" radius={[8, 8, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </ChartCard>

        <ChartCard title="Water intake">
          <ResponsiveContainer width="100%" height={250}>
            <BarChart data={water}>
              <CartesianGrid strokeDasharray="3 3" stroke="var(--vf-border)" />
              <XAxis
                dataKey="day"
                hide={water.length > 12}
                tick={{ fill: "var(--vf-muted)", fontSize: 11 }}
              />
              <YAxis tick={{ fill: "var(--vf-muted)", fontSize: 11 }} />
              <Tooltip />
              <Bar dataKey="ml" fill="#059669" radius={[8, 8, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </ChartCard>

        <ChartCard title="Weight changes">
          <ResponsiveContainer width="100%" height={250}>
            <AreaChart data={weight}>
              <CartesianGrid strokeDasharray="3 3" stroke="var(--vf-border)" />
              <XAxis
                dataKey="day"
                hide={weight.length > 12}
                tick={{ fill: "var(--vf-muted)", fontSize: 11 }}
              />
              <YAxis tick={{ fill: "var(--vf-muted)", fontSize: 11 }} />
              <Tooltip />
              <Area
                type="monotone"
                dataKey="weight"
                stroke="#D97706"
                fill="rgba(217,119,6,0.2)"
                strokeWidth={2}
              />
            </AreaChart>
          </ResponsiveContainer>
        </ChartCard>

        <ChartCard title="Completed workouts">
          <ResponsiveContainer width="100%" height={250}>
            <BarChart data={workouts}>
              <CartesianGrid strokeDasharray="3 3" stroke="var(--vf-border)" />
              <XAxis
                dataKey="day"
                hide={workouts.length > 12}
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

        <ChartCard title="Activity by type">
          <ResponsiveContainer width="100%" height={250}>
            <BarChart data={activities}>
              <CartesianGrid strokeDasharray="3 3" stroke="var(--vf-border)" />
              <XAxis
                dataKey="type"
                tick={{ fill: "var(--vf-muted)", fontSize: 11 }}
              />
              <YAxis tick={{ fill: "var(--vf-muted)", fontSize: 11 }} />
              <Tooltip />
              <Bar dataKey="total" fill="#DB2777" radius={[8, 8, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </ChartCard>
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

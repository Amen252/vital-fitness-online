import { useEffect, useState } from "react";
import {
  approveExercise,
  getExercises,
  getWorkoutsOverview,
  rejectExercise,
} from "../api/adminApi";
import { getErrorMessage } from "../api/client";
import {
  Badge,
  Breadcrumbs,
  Button,
  Card,
  ErrorState,
  PageHeader,
  Spinner,
  StatCard,
  useToast,
} from "../components/ui";
import { Dumbbell, Flame, Timer } from "lucide-react";

export default function WorkoutsPage({ embedded = false }) {
  const toast = useToast();
  const [overview, setOverview] = useState(null);
  const [exercises, setExercises] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  async function load() {
    const hasContent = overview != null || exercises != null;
    if (!hasContent) setLoading(true);
    setError("");
    try {
      const [workouts, ex] = await Promise.all([
        getWorkoutsOverview(),
        getExercises(),
      ]);
      setOverview(workouts);
      setExercises(ex);
    } catch (err) {
      setError(getErrorMessage(err));
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    load();
  }, []);

  async function approve(id) {
    try {
      await approveExercise(id);
      toast.success("Exercise approved");
      await load();
    } catch (err) {
      toast.error(getErrorMessage(err));
    }
  }

  async function reject(id) {
    try {
      await rejectExercise(id);
      toast.warning("Exercise rejected");
      await load();
    } catch (err) {
      toast.error(getErrorMessage(err));
    }
  }

  if (loading && overview == null && exercises == null) return <Spinner />;
  if (error && overview == null && exercises == null) return <ErrorState message={error} onRetry={load} />;

  return (
    <div>
      {embedded ? null : (
        <PageHeader
          title="Workout Management"
          subtitle="Exercise plans, completions, and activity approvals"
          breadcrumbs={
            <Breadcrumbs
              items={[{ label: "Home", to: "/" }, { label: "Workouts" }]}
            />
          }
          action={<Button onClick={load}>Refresh</Button>}
        />
      )}

      <div className="mb-6 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard
          label="Activity logs"
          value={overview.totalActivities}
          icon={Dumbbell}
        />
        <StatCard
          label="Calories burned"
          value={overview.totalCaloriesBurned}
          icon={Flame}
          tone="warning"
        />
        <StatCard
          label="Avg duration (min)"
          value={overview.avgDurationMinutes}
          icon={Timer}
          tone="accent"
        />
        <StatCard
          label="Completions"
          value={(overview.completions || []).length}
          tone="success"
        />
      </div>

      <div className="grid gap-6 xl:grid-cols-2">
        <Card className="p-5">
          <h3 className="font-bold">Pending exercise approvals</h3>
          <div className="mt-4 space-y-3">
            {(exercises?.pendingLogs || []).length === 0 ? (
              <p className="text-sm text-[var(--vf-muted)]">
                No pending activities.
              </p>
            ) : (
              exercises.pendingLogs.map((log) => (
                <div
                  key={log._id}
                  className="rounded-[12px] border border-[var(--vf-border)] px-3 py-3 text-sm"
                >
                  <div className="flex items-start justify-between gap-3">
                    <div>
                      <p className="">{log.activityType}</p>
                      <p className="text-[var(--vf-muted)]">
                        {log.user?.name || "User"} · {log.caloriesBurned || 0}{" "}
                        kcal
                      </p>
                    </div>
                    <div className="flex gap-2">
                      <Button size="sm" onClick={() => approve(log._id)}>
                        Approve
                      </Button>
                      <Button
                        size="sm"
                        variant="danger"
                        onClick={() => reject(log._id)}
                      >
                        Reject
                      </Button>
                    </div>
                  </div>
                </div>
              ))
            )}
          </div>
        </Card>

        <Card className="p-5">
          <h3 className="font-bold">Completed workouts</h3>
          <div className="mt-4 space-y-3">
            {(overview.completions || [])
              .filter((c) => c.status === "completed")
              .slice(0, 20).length === 0 ? (
              <p className="text-sm text-[var(--vf-muted)]">
                No workout completions recorded.
              </p>
            ) : (
              overview.completions
                .filter((c) => c.status === "completed")
                .slice(0, 20)
                .map((item) => (
                  <div
                    key={item._id}
                    className="flex items-center justify-between rounded-[12px] bg-[var(--vf-surface-muted)] px-3 py-2 text-sm"
                  >
                    <div>
                      <p className="">
                        {item.exercisePlan?.title || "Workout"}
                      </p>
                      <p className="text-[var(--vf-muted)]">
                        {item.user?.name} · coach {item.coach?.name}
                      </p>
                    </div>
                    <Badge tone="green">{item.status}</Badge>
                  </div>
                ))
            )}
          </div>
        </Card>

        <Card className="p-5 xl:col-span-2">
          <h3 className="font-bold">Active exercise plans</h3>
          <div className="mt-4 overflow-x-auto">
            <table className="min-w-full text-left text-sm">
              <thead className="text-[var(--vf-muted)]">
                <tr>
                  <th className="px-2 py-2 uppercase tracking-wide text-xs">
                    Title
                  </th>
                  <th className="px-2 py-2 uppercase tracking-wide text-xs">
                    Coach
                  </th>
                  <th className="px-2 py-2 uppercase tracking-wide text-xs">
                    Client / Group
                  </th>
                  <th className="px-2 py-2 uppercase tracking-wide text-xs">
                    Level
                  </th>
                  <th className="px-2 py-2 uppercase tracking-wide text-xs">
                    Exercises
                  </th>
                </tr>
              </thead>
              <tbody>
                {(overview.plans || []).map((plan) => (
                  <tr
                    key={plan._id}
                    className="border-t border-[var(--vf-border)]"
                  >
                    <td className="px-2 py-2 ">{plan.title}</td>
                    <td className="px-2 py-2">{plan.coach?.name || "—"}</td>
                    <td className="px-2 py-2">
                      {plan.client?.name || plan.fitnessClass?.title || "—"}
                    </td>
                    <td className="px-2 py-2">{plan.level}</td>
                    <td className="px-2 py-2">{plan.exercises?.length || 0}</td>
                  </tr>
                ))}
                {(overview.plans || []).length === 0 ? (
                  <tr>
                    <td
                      colSpan={5}
                      className="px-2 py-6 text-[var(--vf-muted)]"
                    >
                      No active exercise plans.
                    </td>
                  </tr>
                ) : null}
              </tbody>
            </table>
          </div>
        </Card>
      </div>
    </div>
  );
}

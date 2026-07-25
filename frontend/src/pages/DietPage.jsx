import { useEffect, useMemo, useState } from "react";
import { UtensilsCrossed } from "lucide-react";
import { getDietAdherence, getDietPlans } from "../api/adminApi";
import { getErrorMessage } from "../api/client";
import {
  Badge,
  Breadcrumbs,
  Button,
  Card,
  DataTable,
  ErrorState,
  PageHeader,
  Spinner,
  StatCard,
} from "../components/ui";

export default function DietPage({ embedded = false }) {
  const [plans, setPlans] = useState([]);
  const [adherence, setAdherence] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [status, setStatus] = useState("all");

  async function load() {
    setLoading(true);
    setError("");
    try {
      const [planData, adherenceData] = await Promise.all([
        getDietPlans({ status }),
        getDietAdherence({ days: 30 }),
      ]);
      setPlans(planData.plans || []);
      setAdherence(adherenceData);
    } catch (err) {
      setError(getErrorMessage(err));
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    load();
  }, [status]);

  const summary = adherence?.summary || {};

  const columns = useMemo(
    () => [
      {
        key: "title",
        header: "Plan",
        sortable: true,
        render: (row) => <span className="">{row.title}</span>,
      },
      {
        key: "assigneeName",
        header: "Assignee",
        sortable: true,
        render: (row) => (
          <div>
            <p>{row.assigneeName}</p>
            <p className="text-xs text-[var(--vf-muted)]">{row.assigneeType}</p>
          </div>
        ),
      },
      {
        key: "coach.name",
        header: "Coach",
        sortable: true,
        sortKey: "coach.name",
        render: (row) => row.coach?.name || "—",
      },
      { key: "dailyCalories", header: "Calories", sortable: true },
      {
        key: "meals",
        header: "Meals",
        render: (row) => (
          <span className="text-[var(--vf-muted)]">
            {(row.mealTypes || []).join(", ") || "—"}
          </span>
        ),
      },
      {
        key: "status",
        header: "Status",
        sortable: true,
        render: (row) => (
          <Badge tone={row.status === "active" ? "green" : "slate"}>
            {row.status}
          </Badge>
        ),
      },
    ],
    [],
  );

  return (
    <div>
      {embedded ? null : (
        <PageHeader
          title="Diet Management"
          subtitle="Plans and meal completion from DietPlan / DietAdherence"
          breadcrumbs={
            <Breadcrumbs
              items={[{ label: "Home", to: "/" }, { label: "Diet" }]}
            />
          }
          action={
            <Button variant="secondary" onClick={load}>
              Refresh
            </Button>
          }
        />
      )}

      {loading ? <Spinner /> : null}
      {error ? <ErrorState message={error} onRetry={load} /> : null}

      {!loading && !error ? (
        <>
          <div className="mb-6 grid gap-4 sm:grid-cols-2 xl:grid-cols-5">
            <StatCard
              label="Avg adherence"
              value={`${summary.avgAdherence || 0}%`}
              tone="primary"
            />
            <StatCard
              label="Breakfast done"
              value={summary.breakfast || 0}
              tone="warning"
            />
            <StatCard
              label="Lunch done"
              value={summary.lunch || 0}
              tone="accent"
            />
            <StatCard
              label="Dinner done"
              value={summary.dinner || 0}
              tone="success"
            />
            <StatCard
              label="Snacks done"
              value={summary.snacks || 0}
              tone="pink"
            />
          </div>

          <DataTable
            columns={columns}
            rows={plans}
            searchKeys={["title", "assigneeName", "coach.name"]}
            emptyIcon={UtensilsCrossed}
            emptyTitle="No diet plans yet"
            filters={
              <select
                value={status}
                onChange={(e) => setStatus(e.target.value)}
                className="rounded-[12px] border border-[var(--vf-border)] bg-[var(--vf-surface-muted)] px-3 py-2.5 text-sm"
              >
                <option value="all">All plans</option>
                <option value="active">Active</option>
                <option value="completed">Completed</option>
                <option value="draft">Draft</option>
                <option value="archived">Archived</option>
              </select>
            }
          />

          <Card className="mt-6 p-5">
            <h3 className="font-bold">Recent meal adherence</h3>
            <div className="mt-4 space-y-3">
              {(adherence?.records || []).slice(0, 20).map((record) => (
                <div
                  key={record._id}
                  className="rounded-[12px] bg-[var(--vf-surface-muted)] px-4 py-3 text-sm"
                >
                  <div className="flex flex-wrap items-center justify-between gap-2">
                    <p className="">{record.user?.name || "User"}</p>
                    <Badge tone="blue">{record.adherencePercent || 0}%</Badge>
                  </div>
                  <p className="mt-1 text-[var(--vf-muted)]">
                    {record.date
                      ? new Date(record.date).toLocaleDateString()
                      : "—"}{" "}
                    ·{" "}
                    {(record.mealAdherence || [])
                      .map((m) => `${m.type}${m.followed ? "✓" : "✗"}`)
                      .join(" ")}
                  </p>
                </div>
              ))}
              {(adherence?.records || []).length === 0 ? (
                <p className="text-sm text-[var(--vf-muted)]">
                  No adherence records yet.
                </p>
              ) : null}
            </div>
          </Card>
        </>
      ) : null}
    </div>
  );
}

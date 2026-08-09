import { useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { Activity } from "lucide-react";
import { getCoachingProgress } from "../api/adminApi";
import { getErrorMessage, withHardTimeout } from "../api/client";
import {
  Badge,
  Breadcrumbs,
  Button,
  DataTable,
  ErrorState,
  PageHeader,
  Spinner,
} from "../components/ui";

function formatWhen(value) {
  if (!value) return "—";
  try {
    return new Date(value).toLocaleString();
  } catch {
    return "—";
  }
}

export default function CoachingProgressPage({ embedded = false }) {
  const [pairs, setPairs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  async function load() {
    setLoading(true);
    setError("");
    try {
      const data = await withHardTimeout(getCoachingProgress());
      setPairs(data.pairs || []);
    } catch (err) {
      setError(getErrorMessage(err));
      setPairs([]);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    load();
  }, []);

  const columns = useMemo(
    () => [
      {
        key: "coach",
        header: "Coach",
        sortable: true,
        sortKey: "coach.full_name",
        render: (row) => (
          <div>
            <Link className="font-semibold text-[var(--vf-primary)]" to={`/coaches/${row.coach?._id}`}>
              {row.coach?.full_name || row.coach?.username || "—"}
            </Link>
            <p className="text-xs text-[var(--vf-muted)]">@{row.coach?.username}</p>
          </div>
        ),
      },
      {
        key: "client",
        header: "Client",
        sortable: true,
        sortKey: "client.full_name",
        render: (row) => (
          <div>
            <Link className="font-semibold text-[var(--vf-primary)]" to={`/users/${row.client?._id}`}>
              {row.client?.full_name || row.client?.username || "—"}
            </Link>
            <p className="text-xs text-[var(--vf-muted)]">@{row.client?.username}</p>
          </div>
        ),
      },
      {
        key: "loggedWeight",
        header: "Logged weight",
        render: (row) => (
          <div className="text-sm">
            <p className="text-[var(--vf-muted)]">
              {row.progress?.weightKg != null ? `${row.progress.weightKg} kg` : "No weight logged"}
            </p>
          </div>
        ),
      },
      {
        key: "progress",
        header: "Recent progress (7 logs)",
        render: (row) => (
          <div className="text-sm">
            <p>In {Math.round(row.progress?.caloriesIn || 0)} · Out {Math.round(row.progress?.caloriesOut || 0)}</p>
            <p className="text-xs text-[var(--vf-muted)]">
              Water {(Math.round((row.progress?.hydrationMl || 0) / 100) / 10)} L · {row.progress?.logCount || 0} logs
            </p>
          </div>
        ),
      },
      {
        key: "appointments",
        header: "Appointments",
        render: (row) => (
          <div className="text-sm">
            <p>
              <Badge tone="green">{row.appointments?.completed || 0} done</Badge>{" "}
              <Badge tone="amber">{row.appointments?.upcoming || 0} upcoming</Badge>
            </p>
            <p className="mt-1 text-xs text-[var(--vf-muted)]">
              Next: {row.appointments?.next ? formatWhen(row.appointments.next.dateTime) : "—"}
            </p>
          </div>
        ),
      },
      {
        key: "assignedAt",
        header: "Linked",
        sortable: true,
        render: (row) => formatWhen(row.assignedAt),
      },
    ],
    [],
  );

  return (
    <div>
      {embedded ? null : (
        <PageHeader
          title="Coach–client progress"
          subtitle={`${pairs.length} linked coach–member pair${pairs.length === 1 ? "" : "s"} (read-only overview)`}
          breadcrumbs={
            <Breadcrumbs
              items={[
                { label: "Home", to: "/" },
                { label: "Coach–client progress" },
              ]}
            />
          }
          action={
            <Button variant="secondary" onClick={load}>
              Refresh
            </Button>
          }
        />
      )}

      {loading ? <Spinner label="Loading coaching progress…" /> : null}
      {error ? <ErrorState message={error} onRetry={load} /> : null}
      {!loading && !error ? (
        <DataTable
          columns={columns}
          rows={pairs}
          searchKeys={["coach.full_name", "coach.username", "client.full_name", "client.username"]}
          searchPlaceholder="Search coach or client…"
          pageSize={0}
          emptyIcon={Activity}
          emptyTitle="No linked coach–member pairs yet"
        />
      ) : null}
    </div>
  );
}

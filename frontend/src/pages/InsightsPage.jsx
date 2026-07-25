import { useState } from "react";
import { useSearchParams } from "react-router-dom";
import { Activity, ChartColumn, Dumbbell, UtensilsCrossed } from "lucide-react";
import { Breadcrumbs, Button, PageHeader } from "../components/ui";
import CoachingProgressPage from "./CoachingProgressPage";
import DietPage from "./DietPage";
import WorkoutsPage from "./WorkoutsPage";
import ReportsPage from "./ReportsPage";

const TABS = [
  { key: "progress", label: "Progress", icon: Activity, Component: CoachingProgressPage },
  { key: "diet", label: "Diet", icon: UtensilsCrossed, Component: DietPage },
  { key: "workouts", label: "Workouts", icon: Dumbbell, Component: WorkoutsPage },
  { key: "reports", label: "Reports", icon: ChartColumn, Component: ReportsPage },
];

export default function InsightsPage() {
  const [params, setParams] = useSearchParams();
  const [refreshKey, setRefreshKey] = useState(0);

  const requested = params.get("tab");
  const active = TABS.find((t) => t.key === requested) ? requested : TABS[0].key;
  const ActiveComponent = TABS.find((t) => t.key === active).Component;

  return (
    <div>
      <PageHeader
        title="Insights"
        subtitle="Monitor member progress, diet, workouts, and platform analytics in one place"
        breadcrumbs={
          <Breadcrumbs items={[{ label: "Home", to: "/" }, { label: "Insights" }]} />
        }
        action={
          <Button variant="secondary" onClick={() => setRefreshKey((k) => k + 1)}>
            Refresh
          </Button>
        }
      />

      <div className="mb-6 flex flex-wrap gap-1 rounded-[14px] border border-[var(--vf-border)] bg-[var(--vf-surface-muted)] p-1">
        {TABS.map((tab) => {
          const Icon = tab.icon;
          const isActive = tab.key === active;
          return (
            <button
              key={tab.key}
              type="button"
              onClick={() => setParams({ tab: tab.key }, { replace: true })}
              className={`flex flex-1 items-center justify-center gap-2 rounded-[10px] px-3 py-2 text-sm font-semibold transition ${
                isActive
                  ? "bg-[var(--vf-surface)] text-[var(--vf-primary)] shadow-sm"
                  : "text-[var(--vf-muted)] hover:text-[var(--vf-text)]"
              }`}
            >
              <Icon className="h-4 w-4" />
              <span>{tab.label}</span>
            </button>
          );
        })}
      </div>

      <ActiveComponent key={`${active}-${refreshKey}`} embedded />
    </div>
  );
}

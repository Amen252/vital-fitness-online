import { Bell } from "lucide-react";
import { useCallback, useEffect, useState } from "react";
import { useOutletContext } from "react-router-dom";
import { getMyNotifications, markMyNotificationRead } from "../../api/adminApi";
import { getErrorMessage } from "../../api/client";
import { logMemberDietAdherence } from "../../api/memberApi";
import { Badge, Button, Card, Modal } from "../../components/ui";
import { formatWhen } from "./roleHelpers";

function isMealReminder(n) {
  if (n?.data?.kind === "meal_reminder") return true;
  const msg = String(n?.message || "").toLowerCase();
  return n?.type === "reminder" && msg.includes("meal reminder");
}

function nutritionLabel(data = {}) {
  const parts = [];
  if (Number(data.calories) > 0) parts.push(`${data.calories} kcal`);
  if (Number(data.protein) > 0) parts.push(`P ${data.protein}g`);
  if (Number(data.carbs) > 0) parts.push(`C ${data.carbs}g`);
  if (Number(data.fats) > 0) parts.push(`F ${data.fats}g`);
  return parts.join(" · ");
}

function foodLabel(data = {}) {
  const items = Array.isArray(data.foodItems)
    ? data.foodItems.map((item) => String(item || "").trim()).filter(Boolean)
    : [];
  if (items.length) return items.join(", ");
  return String(data.description || "").trim();
}

export default function RoleNotificationsPage() {
  const { setUnreadCount } = useOutletContext();
  const [notifications, setNotifications] = useState([]);
  const [loading, setLoading] = useState(false);
  const [selected, setSelected] = useState(null);
  const [completing, setCompleting] = useState(false);
  const [actionError, setActionError] = useState("");
  const [actionNotice, setActionNotice] = useState("");

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const notifs = await getMyNotifications().catch(() => []);
      const list = Array.isArray(notifs) ? notifs : [];
      setNotifications(list);
      setUnreadCount?.(list.filter((n) => !n.read).length);
    } finally {
      setLoading(false);
    }
  }, [setUnreadCount]);

  useEffect(() => {
    load();
  }, [load]);

  async function markRead(id) {
    try {
      await markMyNotificationRead(id);
      setNotifications((list) => {
        const next = list.map((n) => (n._id === id ? { ...n, read: true } : n));
        setUnreadCount?.(next.filter((n) => !n.read).length);
        return next;
      });
    } catch (error) {
      console.error(getErrorMessage(error));
    }
  }

  async function openNotification(n) {
    setActionError("");
    setActionNotice("");
    if (!n.read) await markRead(n._id);
    if (isMealReminder(n)) {
      setSelected(n);
    }
  }

  async function markMealCompleted() {
    const data = selected?.data || {};
    const mealType = data.mealType;
    if (!mealType) {
      setActionError("This reminder is missing meal type details.");
      return;
    }
    setCompleting(true);
    setActionError("");
    setActionNotice("");
    try {
      await logMemberDietAdherence({ mealType, followed: true });
      setActionNotice("Meal marked complete. Diet progress updated.");
    } catch (error) {
      setActionError(getErrorMessage(error));
    } finally {
      setCompleting(false);
    }
  }

  const unreadCount = notifications.filter((n) => !n.read).length;
  const mealData = selected?.data || {};
  const food = foodLabel(mealData);
  const nutrition = nutritionLabel(mealData);
  const coachNotes = [mealData.prepInstructions, mealData.mealNotes]
    .map((v) => String(v || "").trim())
    .filter(Boolean)
    .join(" · ");

  return (
    <Card className="p-6">
      <div className="flex items-center justify-between gap-3">
        <div className="flex items-center gap-2">
          <Bell className="h-5 w-5 text-[var(--vf-primary)]" />
          <h1 className="text-2xl font-bold">Notifications</h1>
          {unreadCount > 0 ? <Badge tone="amber">{unreadCount} new</Badge> : null}
        </div>
        <Button size="sm" variant="secondary" onClick={load} disabled={loading}>
          {loading ? "Loading…" : "Refresh"}
        </Button>
      </div>
      <ul className="mt-4 space-y-2">
        {notifications.length === 0 ? (
          <li className="rounded-[12px] border border-[var(--vf-border)] px-3 py-6 text-center text-sm text-[var(--vf-muted)]">
            No notifications yet.
          </li>
        ) : (
          notifications.map((n) => (
            <li
              key={n._id}
              className={`rounded-[12px] border px-3 py-3 text-sm ${
                n.read
                  ? "border-[var(--vf-border)] bg-[var(--vf-surface)]"
                  : "border-emerald-200 bg-emerald-50"
              }`}
            >
              <div className="flex flex-wrap items-start justify-between gap-2">
                <button
                  type="button"
                  className="flex-1 text-left"
                  onClick={() => openNotification(n)}
                >
                  <p className="font-semibold">{n.title || "Notification"}</p>
                  <p className="mt-1 whitespace-pre-line text-[var(--vf-text)]">{n.message}</p>
                  <p className="mt-1 text-xs text-[var(--vf-muted)]">{formatWhen(n.createdAt)}</p>
                  {isMealReminder(n) ? (
                    <p className="mt-1 text-xs font-semibold text-[var(--vf-primary)]">
                      Tap to view meal details
                    </p>
                  ) : null}
                </button>
                {!n.read ? (
                  <Button size="sm" variant="secondary" onClick={() => markRead(n._id)}>
                    Mark read
                  </Button>
                ) : (
                  <Badge tone="green">Read</Badge>
                )}
              </div>
            </li>
          ))
        )}
      </ul>

      <Modal
        open={Boolean(selected)}
        onClose={() => setSelected(null)}
        title="Meal Reminder"
        footer={
          <div className="flex flex-wrap justify-end gap-2">
            <Button variant="secondary" onClick={() => setSelected(null)}>
              Close
            </Button>
            {mealData.mealType ? (
              <Button onClick={markMealCompleted} disabled={completing}>
                {completing ? "Saving…" : "Mark meal completed"}
              </Button>
            ) : null}
          </div>
        }
      >
        {selected ? (
          <div className="space-y-3 text-sm">
            <div>
              <p className="text-xs uppercase tracking-wide text-[var(--vf-muted)]">Meal</p>
              <p className="text-lg font-bold">
                {mealData.mealName || mealData.mealLabel || "Meal"}
              </p>
            </div>
            {mealData.reminderTime ? (
              <div>
                <p className="text-xs uppercase tracking-wide text-[var(--vf-muted)]">Scheduled time</p>
                <p className="font-semibold">{mealData.reminderTime}</p>
              </div>
            ) : null}
            {food ? (
              <div>
                <p className="text-xs uppercase tracking-wide text-[var(--vf-muted)]">Food items</p>
                <p>{food}</p>
              </div>
            ) : null}
            {mealData.portionSize ? (
              <div>
                <p className="text-xs uppercase tracking-wide text-[var(--vf-muted)]">Portion</p>
                <p>{mealData.portionSize}</p>
              </div>
            ) : null}
            {nutrition ? (
              <div>
                <p className="text-xs uppercase tracking-wide text-[var(--vf-muted)]">Nutrition</p>
                <p className="font-semibold">{nutrition}</p>
              </div>
            ) : null}
            {coachNotes ? (
              <div>
                <p className="text-xs uppercase tracking-wide text-[var(--vf-muted)]">Coach notes</p>
                <p>{coachNotes}</p>
              </div>
            ) : null}
            {!food && !nutrition && selected.message ? (
              <p className="whitespace-pre-line text-[var(--vf-muted)]">{selected.message}</p>
            ) : null}
            {actionError ? <p className="text-[var(--vf-danger)]">{actionError}</p> : null}
            {actionNotice ? <p className="text-emerald-700">{actionNotice}</p> : null}
          </div>
        ) : null}
      </Modal>
    </Card>
  );
}

import { Bell } from "lucide-react";
import { useCallback, useEffect, useState } from "react";
import { useOutletContext } from "react-router-dom";
import { getMyNotifications, markMyNotificationRead } from "../../api/adminApi";
import { getErrorMessage } from "../../api/client";
import { Badge, Button, Card } from "../../components/ui";
import { formatWhen } from "./roleHelpers";

export default function RoleNotificationsPage() {
  const { setUnreadCount } = useOutletContext();
  const [notifications, setNotifications] = useState([]);
  const [loading, setLoading] = useState(false);

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

  const unreadCount = notifications.filter((n) => !n.read).length;

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
                <div>
                  <p className="font-semibold">{n.title || "Notification"}</p>
                  <p className="mt-1 text-[var(--vf-text)]">{n.message}</p>
                  <p className="mt-1 text-xs text-[var(--vf-muted)]">{formatWhen(n.createdAt)}</p>
                </div>
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
    </Card>
  );
}

import { Users } from "lucide-react";
import { useCallback, useEffect, useState } from "react";
import { getErrorMessage } from "../../api/client";
import {
  approveCoachRequest,
  getCoachIncomingRequests,
  rejectCoachRequest,
} from "../../api/memberApi";
import { Badge, Button, Card, Spinner } from "../../components/ui";
import { fetchCoachDashboard } from "./CoachDashboardPage";
import { formatWhen } from "./roleHelpers";

export default function CoachClientsPage() {
  const [assignments, setAssignments] = useState([]);
  const [requests, setRequests] = useState([]);
  const [loading, setLoading] = useState(true);
  const [busyId, setBusyId] = useState("");
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");

  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const [dashboard, pending] = await Promise.all([
        fetchCoachDashboard(),
        getCoachIncomingRequests().catch(() => []),
      ]);
      setAssignments(dashboard?.assignments || []);
      setRequests(Array.isArray(pending) ? pending : []);
    } catch (err) {
      setError(getErrorMessage(err));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  useEffect(() => {
    if (requests.length === 0) return undefined;
    const timer = setInterval(load, 15000);
    return () => clearInterval(timer);
  }, [requests.length, load]);

  async function approve(id) {
    setBusyId(`approve-${id}`);
    setError("");
    setNotice("");
    try {
      await approveCoachRequest(id);
      setNotice("Request accepted. The member is now linked to you.");
      await load();
    } catch (err) {
      setError(getErrorMessage(err));
    } finally {
      setBusyId("");
    }
  }

  async function reject(id) {
    setBusyId(`reject-${id}`);
    setError("");
    setNotice("");
    try {
      await rejectCoachRequest(id);
      setNotice("Request declined. The member can choose another coach.");
      await load();
    } catch (err) {
      setError(getErrorMessage(err));
    } finally {
      setBusyId("");
    }
  }

  return (
    <div className="space-y-5">
      <Card className="p-6">
        <Users className="h-6 w-6 text-[var(--vf-primary)]" />
        <h1 className="mt-4 text-2xl font-bold">My clients</h1>
        <p className="mt-2 text-sm text-[var(--vf-muted)]">
          Review coaching requests and manage members currently linked to you.
        </p>
        {loading ? <div className="mt-5"><Spinner label="Loading clients…" /></div> : null}
        {error ? <p className="mt-5 text-sm text-[var(--vf-danger)]">{error}</p> : null}
        {notice ? <p className="mt-5 text-sm text-emerald-700">{notice}</p> : null}
      </Card>

      {!loading ? (
        <Card className="p-6">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <h2 className="font-bold">Pending coach requests</h2>
            <Badge tone="amber">{requests.length} pending</Badge>
          </div>
          <p className="mt-1 text-sm text-[var(--vf-muted)]">
            Accept to link the member, or decline so they can choose another coach.
          </p>
          <ul className="mt-4 space-y-2">
            {requests.length === 0 ? (
              <li className="rounded-[12px] border border-[var(--vf-border)] px-3 py-6 text-center text-sm text-[var(--vf-muted)]">
                No pending coaching requests.
              </li>
            ) : (
              requests.map((req) => {
                const id = req.id || req._id;
                const user = req.user || {};
                return (
                  <li
                    key={id}
                    className="rounded-[12px] border border-[var(--vf-border)] px-4 py-3"
                  >
                    <div className="flex flex-wrap items-start justify-between gap-3">
                      <div>
                        <p className="font-semibold">{user.full_name || user.username || "Member"}</p>
                        <p className="text-xs text-[var(--vf-muted)]">
                          @{user.username || "—"}
                          {user.phone ? ` · ${user.phone}` : ""}
                        </p>
                        {req.message ? (
                          <p className="mt-2 text-sm italic text-[var(--vf-muted)]">“{req.message}”</p>
                        ) : null}
                        <p className="mt-1 text-xs text-[var(--vf-muted)]">
                          Requested {formatWhen(req.createdAt) || "—"}
                        </p>
                      </div>
                      <div className="flex flex-wrap gap-2">
                        <Button
                          size="sm"
                          disabled={Boolean(busyId)}
                          onClick={() => approve(id)}
                        >
                          {busyId === `approve-${id}` ? "Accepting…" : "Accept"}
                        </Button>
                        <Button
                          size="sm"
                          variant="secondary"
                          disabled={Boolean(busyId)}
                          onClick={() => reject(id)}
                        >
                          {busyId === `reject-${id}` ? "Declining…" : "Decline"}
                        </Button>
                      </div>
                    </div>
                  </li>
                );
              })
            )}
          </ul>
        </Card>
      ) : null}

      {!loading ? (
        <Card className="p-6">
          <h2 className="font-bold">Linked clients</h2>
          <p className="mt-1 text-sm text-[var(--vf-muted)]">
            Members who selected you and whose requests you accepted.
          </p>
          <ul className="mt-4 space-y-2">
            {assignments.length === 0 ? (
              <li className="rounded-[12px] border border-[var(--vf-border)] px-3 py-6 text-center text-sm text-[var(--vf-muted)]">
                No linked clients yet. Members appear here after you accept their coaching request.
              </li>
            ) : (
              assignments.map((a) => {
                const user = a.user || {};
                return (
                  <li
                    key={a.id || a._id || user._id}
                    className="rounded-[12px] border border-[var(--vf-border)] px-4 py-3"
                  >
                    <div className="flex flex-wrap items-start justify-between gap-2">
                      <div>
                        <p className="font-semibold">{user.full_name || user.username || "Client"}</p>
                        <p className="text-xs text-[var(--vf-muted)]">
                          @{user.username || "—"}
                          {user.phone ? ` · ${user.phone}` : ""}
                        </p>
                      </div>
                      <p className="text-xs text-[var(--vf-muted)]">
                        Linked {formatWhen(a.assigned_at) || "—"}
                      </p>
                    </div>
                  </li>
                );
              })
            )}
          </ul>
        </Card>
      ) : null}
    </div>
  );
}

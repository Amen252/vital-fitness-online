import { Users } from "lucide-react";
import { useCallback, useEffect, useState } from "react";
import { getErrorMessage } from "../../api/client";
import { getCoachClientDetail } from "../../api/coachApi";
import {
  approveCoachRequest,
  getCoachIncomingRequests,
  rejectCoachRequest,
} from "../../api/memberApi";
import { Badge, Button, Card, Modal, Spinner } from "../../components/ui";
import { fetchCoachDashboard } from "./CoachDashboardPage";
import { formatWhen } from "./roleHelpers";

function fitnessGoalLabel(goal) {
  switch (goal) {
    case "lose_weight":
      return "Weight Loss";
    case "gain_muscle":
      return "Muscle Gain";
    case "maintain":
      return "Fitness / Maintain";
    case "other":
      return "Other";
    default:
      return goal || "";
  }
}

function activityLevelLabel(level) {
  switch (level) {
    case "sedentary":
      return "Sedentary";
    case "moderate":
      return "Moderate";
    case "active":
      return "Active";
    default:
      return level || "";
  }
}

function displayValue(value, suffix = "") {
  if (value === null || value === undefined) return "Not specified";
  const text = String(value).trim();
  if (!text) return "Not specified";
  return suffix ? `${text}${suffix}` : text;
}

function ClientProfileModal({ open, onClose, clientId }) {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [detail, setDetail] = useState(null);

  useEffect(() => {
    if (!open || !clientId) return undefined;
    let cancelled = false;
    setLoading(true);
    setError("");
    setDetail(null);
    getCoachClientDetail(clientId)
      .then((data) => {
        if (!cancelled) setDetail(data);
      })
      .catch((err) => {
        if (!cancelled) setError(getErrorMessage(err));
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [open, clientId]);

  const user = detail?.user || {};
  const clientData = user.clientData || {};
  const name = user.full_name || user.name || user.username || "Client";
  const email = user.email || user.username || "";
  const phone = user.phone || "";
  const photo = user.avatar || user.photoUrl || "";
  const fitnessGoal = fitnessGoalLabel(clientData.fitness_goal);
  const activityLevel = activityLevelLabel(clientData.activity_level);

  const rows = [
    ["Full name", displayValue(name)],
    ["Email", displayValue(email)],
    ["Phone", displayValue(phone)],
    ["Age", displayValue(clientData.age)],
    ["Gender", displayValue(clientData.gender)],
    ["Height", displayValue(clientData.height, " cm")],
    ["Weight", displayValue(clientData.weight, " kg")],
    ["Fitness goal", displayValue(fitnessGoal)],
    ["Activity level", displayValue(activityLevel)],
    ["Medical notes", displayValue(clientData.medical_notes)],
  ];

  return (
    <Modal open={open} onClose={onClose} title="Client profile" wide>
      {loading ? <Spinner label="Loading profile…" /> : null}
      {error ? <p className="text-sm text-[var(--vf-danger)]">{error}</p> : null}
      {!loading && !error && detail ? (
        <div className="space-y-5">
          <div className="flex items-center gap-4">
            {photo ? (
              <img
                src={photo}
                alt={name}
                className="h-16 w-16 rounded-full object-cover"
              />
            ) : (
              <div className="flex h-16 w-16 items-center justify-center rounded-full bg-[var(--vf-primary)]/15 text-xl font-bold text-[var(--vf-primary)]">
                {(name[0] || "C").toUpperCase()}
              </div>
            )}
            <div>
              <p className="text-lg font-bold">{name}</p>
              {email ? <p className="text-sm text-[var(--vf-muted)]">{email}</p> : null}
              {phone ? <p className="text-sm text-[var(--vf-muted)]">{phone}</p> : null}
            </div>
          </div>
          <dl className="grid gap-3 sm:grid-cols-2">
            {rows.map(([label, value]) => (
              <div
                key={label}
                className="rounded-[12px] border border-[var(--vf-border)] px-3 py-2"
              >
                <dt className="text-xs uppercase tracking-wide text-[var(--vf-muted)]">{label}</dt>
                <dd className="mt-1 text-sm font-semibold text-[var(--vf-text)]">{value}</dd>
              </div>
            ))}
          </dl>
        </div>
      ) : null}
    </Modal>
  );
}

export default function CoachClientsPage() {
  const [assignments, setAssignments] = useState([]);
  const [requests, setRequests] = useState([]);
  const [loading, setLoading] = useState(true);
  const [busyId, setBusyId] = useState("");
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [selectedClientId, setSelectedClientId] = useState("");

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
            Members who selected you and whose requests you accepted. Open a profile to review fitness details.
          </p>
          <ul className="mt-4 space-y-2">
            {assignments.length === 0 ? (
              <li className="rounded-[12px] border border-[var(--vf-border)] px-3 py-6 text-center text-sm text-[var(--vf-muted)]">
                No linked clients yet. Members appear here after you accept their coaching request.
              </li>
            ) : (
              assignments.map((a) => {
                const user = a.user || {};
                const clientId = user._id || user.id;
                return (
                  <li
                    key={a.id || a._id || clientId}
                    className="rounded-[12px] border border-[var(--vf-border)] px-4 py-3"
                  >
                    <div className="flex flex-wrap items-start justify-between gap-2">
                      <div>
                        <p className="font-semibold">{user.full_name || user.username || "Client"}</p>
                        <p className="text-xs text-[var(--vf-muted)]">
                          @{user.username || "—"}
                          {user.phone ? ` · ${user.phone}` : ""}
                        </p>
                        <p className="mt-1 text-xs text-[var(--vf-muted)]">
                          Linked {formatWhen(a.assigned_at) || "—"}
                        </p>
                      </div>
                      <Button
                        size="sm"
                        variant="secondary"
                        disabled={!clientId}
                        onClick={() => setSelectedClientId(String(clientId))}
                      >
                        View profile
                      </Button>
                    </div>
                  </li>
                );
              })
            )}
          </ul>
        </Card>
      ) : null}

      <ClientProfileModal
        open={Boolean(selectedClientId)}
        clientId={selectedClientId}
        onClose={() => setSelectedClientId("")}
      />
    </div>
  );
}

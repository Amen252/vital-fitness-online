import { useEffect, useState } from "react";
import { Link, Navigate, useNavigate, useParams } from "react-router-dom";
import { deleteCoach, getCoachDetail } from "../api/adminApi";
import { getErrorMessage } from "../api/client";
import {
  Badge,
  Breadcrumbs,
  Button,
  Card,
  ErrorState,
  Modal,
  PageHeader,
  Spinner,
  StatCard,
  useToast,
} from "../components/ui";
import { CalendarDays, MapPin, UserRound, Users } from "lucide-react";
import ProfileDetails from "../components/ProfileDetails";
import { formatDate } from "../utils/profileDisplay";
import {
  coachDisplayEmail,
  coachDisplayName,
  coachProfileFromUser,
  memberDisplayEmail,
  memberDisplayName,
} from "../utils/coachDisplay";

/** Coach profile for admins — view details and permanently delete accounts. */
export default function CoachDetailPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const toast = useToast();
  const [data, setData] = useState(null);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(true);
  const [redirectToUser, setRedirectToUser] = useState(false);
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [deleting, setDeleting] = useState(false);

  async function load() {
    setLoading(true);
    setError("");
    setRedirectToUser(false);
    try {
      const detail = await getCoachDetail(id);
      if (detail?.user?.role !== "coach") {
        setError("Only coach profiles can be viewed here.");
        setData(null);
        return;
      }
      setData(detail);
    } catch (err) {
      if (err?.response?.data?.code === "ROLE_USER") {
        setRedirectToUser(true);
        return;
      }
      setError(getErrorMessage(err));
      setData(null);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    load();
  }, [id]);

  async function handleDeleteCoach() {
    if (!id || deleting) return;
    setDeleting(true);
    const name = coachDisplayName(data?.user || { username: "Coach" });
    try {
      await deleteCoach(id);
      toast.success(`${name} has been permanently deleted`);
      setConfirmDelete(false);
      navigate("/coaches", { replace: true });
    } catch (err) {
      toast.error(getErrorMessage(err));
    } finally {
      setDeleting(false);
    }
  }

  if (loading) return <Spinner label="Loading coach profile…" />;
  if (redirectToUser) return <Navigate to={`/users/${id}`} replace />;
  if (error) return <ErrorState message={error} onRetry={load} />;
  if (!data?.user)
    return <ErrorState message="Coach not found" onRetry={load} />;

  const coach = data.user;
  const profile = coachProfileFromUser(coach);
  const clients = data.coaching?.clients || [];
  const teaching = data.classes?.teaching || [];
  const application = data.coachApplication;
  const coachName = coachDisplayName(coach);
  const coachEmail = coachDisplayEmail(coach);

  return (
    <div>
      <PageHeader
        title={coachName}
        subtitle="Coach profile. Permanently delete only when this account should be removed from the system."
        breadcrumbs={
          <Breadcrumbs
            items={[
              { label: "Home", to: "/" },
              { label: "Coaches", to: "/coaches" },
              { label: coachName },
            ]}
          />
        }
        action={
          <div className="flex flex-wrap gap-2">
            <Link to="/coaches">
              <Button variant="secondary">Back to coaches</Button>
            </Link>
            <Button
              variant="danger"
              disabled={deleting}
              onClick={() => setConfirmDelete(true)}
            >
              Delete coach
            </Button>
          </div>
        }
      />

      <div className="mb-4 flex flex-wrap gap-2">
        <Badge tone="primary">coach</Badge>
        <Badge tone={coach.status === "active" ? "green" : "amber"}>
          {coach.status}
        </Badge>
        {application?.status ? (
          <Badge
            tone={
              application.status === "approved"
                ? "green"
                : application.status === "pending"
                  ? "amber"
                  : "red"
            }
          >
            application: {application.status}
          </Badge>
        ) : null}
      </div>

      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard
          label="Linked clients"
          value={data.coaching?.activeClientCount ?? clients.length}
          icon={Users}
          tone="primary"
        />
        <StatCard
          label="Classes teaching"
          value={teaching.length}
          icon={CalendarDays}
          tone="accent"
        />
        <StatCard
          label="Experience"
          value={
            profile.yearsExperience != null
              ? `${profile.yearsExperience} yrs`
              : "—"
          }
          icon={UserRound}
          tone="success"
        />
        <StatCard
          label="Location"
          value={profile.location || "—"}
          icon={MapPin}
          tone="warning"
        />
      </div>

      <div className="mt-6 grid gap-4 xl:grid-cols-2">
        <Card className="p-5">
          <h3 className="font-bold">Account</h3>
          <dl className="mt-3 space-y-2 text-sm">
            <Row label="Email" value={coachEmail} />
            <Row label="Joined" value={formatDate(coach.createdAt)} />
            <Row label="Last updated" value={formatDate(coach.updatedAt)} />
            <Row
              label="Application status"
              value={application?.status || "—"}
            />
          </dl>
        </Card>

        <Card className="p-5 xl:col-span-2">
          <h3 className="font-bold">Full profile</h3>
          <div className="mt-4">
            <ProfileDetails
              profile={profile}
              extras={
                application
                  ? [
                      {
                        label: "Application message",
                        value: application.message || "—",
                        fullWidth: true,
                      },
                    ]
                  : []
              }
            />
          </div>
        </Card>

        <Card className="p-5">
          <h3 className="font-bold">Linked clients</h3>
          <ul className="mt-3 space-y-2 text-sm">
            {clients.length === 0 ? (
              <li className="text-[var(--vf-muted)]">
                No members linked yet. Members appear here after this coach accepts their request.
              </li>
            ) : (
              clients.map((client) => (
                <li
                  key={client._id || client.email}
                  className="flex items-center justify-between gap-3 rounded-[12px] bg-[var(--vf-surface-muted)] px-3 py-2"
                >
                  <div className="min-w-0">
                    <p className="truncate">{memberDisplayName(client)}</p>
                    <p className="truncate text-xs text-[var(--vf-muted)]">
                      {memberDisplayEmail(client)}
                    </p>
                  </div>
                  {client._id ? (
                    <Link
                      to={`/users/${client._id}`}
                      className="shrink-0 text-xs text-[var(--vf-primary)]"
                    >
                      User profile
                    </Link>
                  ) : null}
                </li>
              ))
            )}
          </ul>
        </Card>

        <Card className="p-5 xl:col-span-2">
          <h3 className="font-bold">Classes teaching</h3>
          <div className="mt-3 grid gap-2 sm:grid-cols-2">
            {teaching.length === 0 ? (
              <p className="text-sm text-[var(--vf-muted)]">
                No classes yet.
              </p>
            ) : (
              teaching.map((cls) => (
                <div
                  key={cls._id}
                  className="rounded-[12px] border border-[var(--vf-border)] px-3 py-2 text-sm"
                >
                  <p>{cls.title}</p>
                  <p className="text-[var(--vf-muted)]">
                    {cls.category || "General"} · {cls.enrolledCount ?? 0}{" "}
                    enrolled
                  </p>
                </div>
              ))
            )}
          </div>
        </Card>
      </div>

      <Modal
        open={confirmDelete}
        title="Delete coach?"
        onClose={() => (!deleting ? setConfirmDelete(false) : null)}
        footer={
          <div className="flex justify-end gap-2">
            <Button
              variant="secondary"
              disabled={deleting}
              onClick={() => setConfirmDelete(false)}
            >
              Cancel
            </Button>
            <Button variant="danger" disabled={deleting} onClick={handleDeleteCoach}>
              {deleting ? "Deleting…" : "Delete permanently"}
            </Button>
          </div>
        }
      >
        <div className="space-y-3 text-sm">
          <p>
            Are you sure you want to delete this coach? Permanently delete{" "}
            <strong>{coachName}</strong>?
          </p>
          <p className="rounded-[12px] border border-amber-200 bg-amber-50 p-3 text-amber-900">
            This removes the coach account and all related coach data from the
            database. This cannot be undone.
          </p>
        </div>
      </Modal>
    </div>
  );
}

function Row({ label, value }) {
  return (
    <div className="flex justify-between gap-4">
      <dt className="text-[var(--vf-muted)]">{label}</dt>
      <dd className="text-right">{value}</dd>
    </div>
  );
}

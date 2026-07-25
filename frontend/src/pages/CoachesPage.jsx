import { useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { UserRound } from "lucide-react";
import {
  approveCoachApplication,
  deleteCoach,
  getCoachApplications,
  getTrainersMeta,
  rejectCoachApplication,
} from "../api/adminApi";
import { getErrorMessage } from "../api/client";
import { formatDate, formatList } from "../utils/profileDisplay";
import { coachDisplayEmail, coachDisplayName, coachProfileFromUser } from "../utils/coachDisplay";
import ProfileDetails from "../components/ProfileDetails";
import {
  Badge,
  Breadcrumbs,
  Button,
  Card,
  DataTable,
  ErrorState,
  Modal,
  PageHeader,
  Spinner,
  useToast,
} from "../components/ui";

function approvalOf(coach) {
  return (
    coach?.approval_status ||
    coach?.applicationStatus ||
    coach?.coachData?.approval_status ||
    "approved"
  );
}

function isApprovedCoach(coach) {
  if (!coach) return false;
  if (coach.role && coach.role !== "coach") return false;
  if (["suspended", "deleted", "pending"].includes(String(coach.status || ""))) {
    return false;
  }
  const approval = approvalOf(coach);
  return approval === "approved" || approval == null;
}

function specializationLabel(coach) {
  const fromRow = coach.specialization;
  if (Array.isArray(fromRow) && fromRow.length) return formatList(fromRow);
  if (typeof fromRow === "string" && fromRow.trim()) return fromRow;
  const profile = coachProfileFromUser(coach);
  return formatList(profile.specialization) || "—";
}

function photoUrl(coach) {
  return (
    coach.photoUrl ||
    coach.avatar ||
    coachProfileFromUser(coach).photoUrl ||
    ""
  );
}

export default function CoachesPage() {
  const toast = useToast();
  const [tab, setTab] = useState("all");
  const [reviewingId, setReviewingId] = useState(null);
  const [allCoaches, setAllCoaches] = useState([]);
  const [pendingApps, setPendingApps] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [pendingDelete, setPendingDelete] = useState(null);
  const [deleting, setDeleting] = useState(false);

  function removeCoachFromLists(deletedId) {
    const id = String(deletedId);
    setAllCoaches((prev) => prev.filter((c) => String(c._id) !== id));
    setPendingApps((prev) =>
      prev.filter((a) => {
        const userId = a.user?._id ?? a.user;
        return String(userId) !== id;
      }),
    );
  }

  async function confirmDeleteCoach() {
    if (!pendingDelete?._id || deleting) return;
    setDeleting(true);
    const deletedId = pendingDelete._id;
    const name = coachDisplayName(pendingDelete);
    try {
      await deleteCoach(deletedId);
      removeCoachFromLists(deletedId);
      setPendingDelete(null);
      toast.success(`${name} has been permanently deleted`);
      await load({ silent: true });
    } catch (err) {
      toast.error(getErrorMessage(err));
    } finally {
      setDeleting(false);
    }
  }

  async function load({ silent = false } = {}) {
    if (!silent) {
      setLoading(true);
      setError("");
    }
    try {
      const [trainers, apps] = await Promise.all([
        getTrainersMeta(),
        getCoachApplications("pending"),
      ]);
      const items = Array.isArray(trainers?.items) ? trainers.items : [];
      setAllCoaches(items);
      setPendingApps(Array.isArray(apps) ? apps.filter((a) => a.status === "pending") : []);
    } catch (err) {
      if (!silent) {
        setError(getErrorMessage(err));
        setAllCoaches([]);
        setPendingApps([]);
      }
    } finally {
      if (!silent) setLoading(false);
    }
  }

  useEffect(() => {
    load();
  }, []);

  // Keep dashboard in sync when new coaches register or applications change.
  useEffect(() => {
    const timer = setInterval(() => load({ silent: true }), 12000);
    const onFocus = () => load({ silent: true });
    const onVisibility = () => {
      if (document.visibilityState === "visible") onFocus();
    };
    window.addEventListener("focus", onFocus);
    document.addEventListener("visibilitychange", onVisibility);
    return () => {
      clearInterval(timer);
      window.removeEventListener("focus", onFocus);
      document.removeEventListener("visibilitychange", onVisibility);
    };
  }, []);

  const activeCoaches = useMemo(
    () => allCoaches.filter(isApprovedCoach),
    [allCoaches],
  );

  const columns = useMemo(
    () => [
      {
        key: "full_name",
        header: "Coach",
        sortable: true,
        render: (row) => {
          const name = coachDisplayName(row);
          const email = coachDisplayEmail(row);
          const photo = photoUrl(row);
          return (
            <div className="flex items-center gap-3">
              {photo ? (
                <img
                  src={photo}
                  alt=""
                  className="h-10 w-10 rounded-full object-cover"
                />
              ) : (
                <div className="flex h-10 w-10 items-center justify-center rounded-full bg-[var(--vf-surface-muted)] text-sm font-bold text-[var(--vf-primary)]">
                  {(name || "?").charAt(0).toUpperCase()}
                </div>
              )}
              <div>
                <p className="font-semibold text-[var(--vf-text)]">{name}</p>
                <p className="text-xs text-[var(--vf-muted)]">{email || "—"}</p>
              </div>
            </div>
          );
        },
      },
      {
        key: "status",
        header: "Account",
        sortable: true,
        render: (row) => (
          <Badge tone={row.status === "active" ? "green" : "amber"}>
            {row.status || "—"}
          </Badge>
        ),
      },
      {
        key: "approval_status",
        header: "Approval",
        sortable: true,
        render: (row) => {
          const approval = approvalOf(row);
          const tone =
            approval === "approved" ? "green" : approval === "pending" ? "amber" : "red";
          return <Badge tone={tone}>{approval}</Badge>;
        },
      },
      {
        key: "phone",
        header: "Phone",
        render: (row) => row.phone || coachProfileFromUser(row).phone || "—",
      },
      {
        key: "specialization",
        header: "Specialization",
        render: (row) => specializationLabel(row),
      },
      {
        key: "activeClients",
        header: "Linked clients",
        sortable: true,
        render: (row) => row.activeClients ?? 0,
      },
      {
        key: "createdAt",
        header: "Registered",
        sortable: true,
        render: (row) => formatDate(row.createdAt),
      },
      {
        key: "actions",
        header: "",
        render: (row) => (
          <div className="flex flex-wrap items-center gap-2" onClick={(e) => e.stopPropagation()}>
            {row.role === "coach" ? (
              <Link to={`/coaches/${row._id}`}>
                <Button size="sm" variant="secondary">
                  View
                </Button>
              </Link>
            ) : (
              <span className="text-xs text-[var(--vf-muted)]">Awaiting approval</span>
            )}
            <Button
              size="sm"
              variant="danger"
              disabled={deleting}
              onClick={() => setPendingDelete(row)}
            >
              Delete
            </Button>
          </div>
        ),
      },
    ],
    [deleting],
  );

  async function approve(id) {
    if (reviewingId) return;
    setReviewingId(id);
    try {
      await approveCoachApplication(id);
      toast.success("Coach approved — now listed under Active Coaches");
      await load();
      setTab("coaches");
    } catch (err) {
      toast.error(getErrorMessage(err));
    } finally {
      setReviewingId(null);
    }
  }

  async function reject(id) {
    if (reviewingId) return;
    setReviewingId(id);
    try {
      await rejectCoachApplication(id, "Rejected by admin");
      toast.warning("Application rejected");
      await load();
      setTab("applications");
    } catch (err) {
      toast.error(getErrorMessage(err));
    } finally {
      setReviewingId(null);
    }
  }

  function renderApplicationCard(app) {
    const displayName =
      app.user?.full_name ||
      app.user?.name ||
      app.user?.username ||
      "Applicant";
    const displayIdentity =
      app.user?.username || app.user?.email || app.user?.phone || "";
    const profile = app.profile || {
      phone: app.phone,
      location: app.location,
      age: app.age,
      yearsExperience: app.yearsExperience,
      certifications: app.certifications,
      specialization: app.specialization,
      bio: app.bio,
      experience: app.experience,
      workingDays: app.workingDays,
      appointmentDays: app.appointmentDays,
      dayAvailability: app.dayAvailability,
      appointmentDurationMinutes: app.appointmentDurationMinutes,
    };
    return (
      <Card key={app._id} className="p-5 vf-animate-in">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h3 className="font-bold">{displayName}</h3>
            {displayIdentity ? (
              <p className="text-sm text-[var(--vf-muted)]">{displayIdentity}</p>
            ) : null}
            <p className="mt-2 text-sm font-medium">
              {app.specialization || formatList(profile.specialization)}
            </p>
          </div>
          <Badge tone="amber">pending</Badge>
        </div>
        <div className="mt-4">
          <ProfileDetails
            profile={profile}
            extras={
              app.message
                ? [{ label: "Application message", value: app.message, fullWidth: true }]
                : []
            }
          />
        </div>
        <div className="mt-4 flex flex-wrap gap-2">
          <Button
            disabled={reviewingId === app._id || deleting}
            onClick={() => approve(app._id)}
          >
            {reviewingId === app._id ? "Approving…" : "Approve"}
          </Button>
          <Button
            variant="danger"
            disabled={Boolean(reviewingId) || deleting}
            onClick={() => reject(app._id)}
          >
            {reviewingId === app._id ? "Rejecting…" : "Reject"}
          </Button>
          {app.user?._id || app.user ? (
            <Button
              variant="secondary"
              disabled={deleting}
              onClick={() =>
                setPendingDelete({
                  _id: app.user?._id || app.user,
                  full_name: displayName,
                  username: app.user?.username,
                  email: app.user?.email,
                })
              }
            >
              Delete account
            </Button>
          ) : null}
        </div>
      </Card>
    );
  }

  return (
    <div>
      <PageHeader
        title="Coaches"
        subtitle="View all coaches, approve or reject registration requests, and permanently delete coach accounts when needed."
        breadcrumbs={
          <Breadcrumbs
            items={[{ label: "Home", to: "/" }, { label: "Coaches" }]}
          />
        }
        action={
          <div className="flex flex-wrap gap-2">
            <Button
              variant={tab === "all" ? "primary" : "secondary"}
              onClick={() => setTab("all")}
            >
              All Coaches ({allCoaches.length})
            </Button>
            <Button
              variant={tab === "applications" ? "primary" : "secondary"}
              onClick={() => setTab("applications")}
            >
              Applications ({pendingApps.length})
            </Button>
            <Button
              variant={tab === "coaches" ? "primary" : "secondary"}
              onClick={() => setTab("coaches")}
            >
              Active Coaches ({activeCoaches.length})
            </Button>
          </div>
        }
      />

      {loading ? <Spinner label="Loading coaches…" /> : null}
      {error ? <ErrorState message={error} onRetry={() => load()} /> : null}

      {!loading && !error && tab === "all" ? (
        <>
          <p className="mb-4 text-sm text-[var(--vf-muted)]">
            Every coach account and pending applicant from the database. Approve actions are only on Applications.
          </p>
          <DataTable
            columns={columns}
            rows={allCoaches}
            searchKeys={[
              "full_name",
              "username",
              "phone",
              "coachData.bio",
              "coachData.specialties",
            ]}
            searchPlaceholder="Search all coaches…"
            pageSize={0}
            pageSizeOptions={[10, 25, 50, 0]}
            emptyIcon={UserRound}
            emptyTitle="No coaches found in the database"
          />
        </>
      ) : null}

      {!loading && !error && tab === "applications" ? (
        <div className="space-y-3">
          <p className="text-sm text-[var(--vf-muted)]">
            Pending registration requests only. Approve adds them to Active Coaches; Reject removes the application.
          </p>
          {pendingApps.map((app) => renderApplicationCard(app))}
          {pendingApps.length === 0 ? (
            <p className="rounded-[12px] border border-[var(--vf-border)] px-4 py-8 text-center text-[var(--vf-muted)]">
              No pending coach applications.
            </p>
          ) : null}
        </div>
      ) : null}

      {!loading && !error && tab === "coaches" ? (
        <>
          <p className="mb-4 text-sm text-[var(--vf-muted)]">
            Approved coaches only. Members can browse this list and send coaching requests.
          </p>
          <DataTable
            columns={columns}
            rows={activeCoaches}
            searchKeys={[
              "full_name",
              "username",
              "phone",
              "coachData.bio",
              "coachData.specialties",
            ]}
            searchPlaceholder="Search active coaches…"
            pageSize={0}
            pageSizeOptions={[10, 25, 50, 0]}
            emptyIcon={UserRound}
            emptyTitle="No approved coaches yet"
          />
        </>
      ) : null}

      <Modal
        open={Boolean(pendingDelete)}
        title="Delete coach?"
        onClose={() => (!deleting ? setPendingDelete(null) : null)}
        footer={
          <div className="flex justify-end gap-2">
            <Button
              variant="secondary"
              disabled={deleting}
              onClick={() => setPendingDelete(null)}
            >
              Cancel
            </Button>
            <Button variant="danger" disabled={deleting} onClick={confirmDeleteCoach}>
              {deleting ? "Deleting…" : "Delete permanently"}
            </Button>
          </div>
        }
      >
        {pendingDelete ? (
          <div className="space-y-3 text-sm">
            <p>
              Are you sure you want to delete this coach? Permanently delete{" "}
              <strong>{coachDisplayName(pendingDelete)}</strong>?
            </p>
            <p className="rounded-[12px] border border-amber-200 bg-amber-50 p-3 text-amber-900">
              This removes the coach account and all related coach data from the
              database. This cannot be undone.
            </p>
          </div>
        ) : null}
      </Modal>
    </div>
  );
}

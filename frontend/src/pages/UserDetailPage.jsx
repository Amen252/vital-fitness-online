import { useEffect, useState } from "react";
import { Link, Navigate, useNavigate, useParams } from "react-router-dom";
import { deleteUser, getUserDetail } from "../api/adminApi";
import { getErrorMessage } from "../api/client";
import {
  Breadcrumbs,
  Button,
  Card,
  ErrorState,
  Modal,
  PageHeader,
  useToast } from "../components/ui";
import { formatDate } from "../utils/profileDisplay";
import { memberRegistrationFromUser } from "../utils/memberRegistration";

function Row({ label, value }) {
  return (
    <div className="flex justify-between gap-4 border-b border-[var(--vf-border)] py-2 text-sm last:border-b-0">
      <dt className="text-[var(--vf-muted)]">{label}</dt>
      <dd className="text-right text-[var(--vf-text)]">
        {value == null || value === "" ? "—" : value}
      </dd>
    </div>
  );
}

export default function UserDetailPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const toast = useToast();
  const [data, setData] = useState(null);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(true);
  const [redirectToCoach, setRedirectToCoach] = useState(false);
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [deleting, setDeleting] = useState(false);

  async function load() {
    setLoading(true);
    setError("");
    setRedirectToCoach(false);
    try {
      const detail = await getUserDetail(id);
      if (detail?.user?.role !== "user") {
        setError("Only member profiles can be viewed here.");
        setData(null);
        return;
      }
      setData(detail);
    } catch (err) {
      if (err?.response?.data?.code === "ROLE_COACH") {
        setRedirectToCoach(true);
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

  async function handleDelete() {
    if (!id || deleting) return;
    setDeleting(true);
    const name = memberRegistrationFromUser(data?.user).full_name || "User";
    try {
      await deleteUser(id);
      toast.success(`${name} has been permanently deleted`);
      setConfirmDelete(false);
      navigate("/users", { replace: true });
    } catch (err) {
      toast.error(getErrorMessage(err));
    } finally {
      setDeleting(false);
    }
  }

  
  if (redirectToCoach) return <Navigate to={`/coaches/${id}`} replace />;
  if (loading) return null;
  if (error) return <ErrorState message={error} onRetry={load} />;
  if (!data?.user)
    return <ErrorState message="Member not found" onRetry={load} />;

  const reg = memberRegistrationFromUser(data.user);

  return (
    <div>
      <PageHeader
        title={reg.full_name || reg.username || "Member"}
        subtitle={reg.username ? `@${reg.username}` : ""}
        breadcrumbs={
          <Breadcrumbs
            items={[
              { label: "Home", to: "/" },
              { label: "Users", to: "/users" },
              { label: reg.full_name || reg.username || "Member" },
            ]}
          />
        }
        action={
          <div className="flex flex-wrap gap-2">
            <Link to="/users">
              <Button variant="secondary">Back</Button>
            </Link>
            <Button
              variant="danger"
              disabled={deleting}
              onClick={() => setConfirmDelete(true)}
            >
              Delete user
            </Button>
          </div>
        }
      />

      <p className="mb-4 text-sm text-[var(--vf-muted)]">
        Registration information as submitted in the app. Admins can delete this
        account but cannot edit member profiles.
      </p>

      <Card className="max-w-xl p-5">
        <h3 className="font-bold">Registration details</h3>
        <dl className="mt-3">
          <Row label="Full name" value={reg.full_name} />
          <Row label="Username" value={reg.username} />
          <Row label="Phone" value={reg.phone} />
          <Row label="Gender" value={reg.gender} />
          <Row label="Age" value={reg.age} />
          <Row
            label="Height"
            value={reg.height != null ? `${reg.height} cm` : ""}
          />
          <Row
            label="Weight"
            value={reg.weight != null ? `${reg.weight} kg` : ""}
          />
          <Row label="Fitness goal" value={reg.fitness_goal_label} />
          <Row label="Registered" value={formatDate(reg.createdAt)} />
        </dl>
      </Card>

      <Modal
        open={confirmDelete}
        title="Delete user?"
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
            <Button variant="danger" disabled={deleting} onClick={handleDelete}>
              {"Delete permanently"}
            </Button>
          </div>
        }
      >
        <div className="space-y-3 text-sm">
          <p>
            Are you sure you want to delete this user? Permanently delete{" "}
            <strong>{reg.full_name || reg.username}</strong>?
          </p>
          <p className="rounded-[12px] border border-amber-200 bg-amber-50 p-3 text-amber-900">
            This removes the member account and related data from the database.
            This cannot be undone.
          </p>
        </div>
      </Modal>
    </div>
  );
}

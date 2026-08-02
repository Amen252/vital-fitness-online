import { ShieldCheck, UserRound } from "lucide-react";
import { useCallback, useEffect } from "react";
import { Link, useOutletContext } from "react-router-dom";
import { getMe } from "../../api/adminApi";
import { Button, Card } from "../../components/ui";
import ProfileDetails from "../../components/ProfileDetails";
import { coachProfileFromUser } from "../../utils/coachDisplay";
import { assignedCoachFromUser } from "./roleHelpers";

export default function RoleAccountPage({ role }) {
  const { profile, setProfile } = useOutletContext();
  const passwordPath = role === "coach" ? "/coach/password" : "/member/password";

  const load = useCallback(async () => {
    const meData = await getMe().catch(() => null);
    if (meData?.user) setProfile?.(meData.user);
  }, [setProfile]);

  useEffect(() => {
    load();
  }, [load]);

  const displayUser = profile || {};
  const assignedCoach = assignedCoachFromUser(displayUser);
  const isMember = role === "user";
  const hasCoachProfile =
    Boolean(displayUser.coachData)
    || Boolean(displayUser.profile && typeof displayUser.profile === "object")
    || ["pending", "approved", "rejected"].includes(displayUser.coachApplicationStatus);
  const coachProfile = (!isMember || hasCoachProfile)
    ? coachProfileFromUser(displayUser)
    : null;
  const isPendingCoach = isMember && displayUser.coachApplicationStatus === "pending";
  const isRejectedCoach = isMember && displayUser.coachApplicationStatus === "rejected";
  const message = isPendingCoach
    ? "Your coach application is under review. The details below are what admins will see."
    : isRejectedCoach
      ? "Your coach application was not approved. You can update your details and submit a new application from the mobile app, or continue using Vital Fitness as a member."
    : isMember
      ? "Your workouts, nutrition, progress, and appointments are managed through Vital Fitness."
      : "Manage clients, training plans, and appointments from your Vital Fitness account.";

  return (
    <div className="grid gap-5 md:grid-cols-2">
      <Card className="p-6">
        <UserRound className="h-6 w-6 text-[var(--vf-primary)]" />
        <h1 className="mt-4 text-2xl font-bold">{displayUser.full_name || displayUser.username}</h1>
        <dl className="mt-3 space-y-2 text-sm">
          <div className="flex justify-between gap-3">
            <dt className="text-[var(--vf-muted)]">Username</dt>
            <dd>{displayUser.username}</dd>
          </div>
          <div className="flex justify-between gap-3">
            <dt className="text-[var(--vf-muted)]">Role</dt>
            <dd className="capitalize">
              {isPendingCoach ? "coach applicant" : displayUser.role}
            </dd>
          </div>
          {isPendingCoach ? (
            <div className="flex justify-between gap-3">
              <dt className="text-[var(--vf-muted)]">Application</dt>
              <dd className="capitalize text-amber-700">pending</dd>
            </div>
          ) : null}
          {isRejectedCoach ? (
            <div className="flex justify-between gap-3">
              <dt className="text-[var(--vf-muted)]">Application</dt>
              <dd className="capitalize text-red-600">not approved</dd>
            </div>
          ) : null}
          <div className="flex justify-between gap-3">
            <dt className="text-[var(--vf-muted)]">Phone</dt>
            <dd>{displayUser.phone || "—"}</dd>
          </div>
          {isMember && !isPendingCoach ? (
            <div className="flex justify-between gap-3">
              <dt className="text-[var(--vf-muted)]">Coach</dt>
              <dd className="text-right font-semibold">
                {assignedCoach
                  ? assignedCoach.full_name || assignedCoach.username || "Linked"
                  : "None yet — choose from Coaches"}
              </dd>
            </div>
          ) : null}
        </dl>
        {coachProfile && Object.keys(coachProfile).length > 0 ? (
          <div className="mt-5 border-t border-[var(--vf-border)] pt-4">
            <h2 className="mb-2 text-sm font-semibold uppercase tracking-wide text-[var(--vf-muted)]">
              {isPendingCoach ? "Submitted coach profile" : "Coach profile"}
            </h2>
            <ProfileDetails profile={coachProfile} />
          </div>
        ) : null}
      </Card>

      <Card className="p-6">
        <ShieldCheck className="h-6 w-6 text-emerald-500" />
        <h2 className="mt-4 text-xl font-bold">Your account is active</h2>
        <p className="mt-2 text-sm leading-6 text-[var(--vf-muted)]">{message}</p>
        {isMember && assignedCoach ? (
          <p className="mt-3 rounded-[12px] bg-[var(--vf-surface-muted)] px-3 py-2 text-sm">
            Your coach is{" "}
            <strong>{assignedCoach.full_name || assignedCoach.username}</strong>
            {assignedCoach.username ? ` (@${assignedCoach.username})` : ""}.
          </p>
        ) : null}
        {isMember && !assignedCoach ? (
          <p className="mt-3 text-sm text-[var(--vf-muted)]">
            No coach linked yet.{" "}
            <Link className="font-semibold text-[var(--vf-primary)]" to="/member/coaches">
              Browse coaches
            </Link>{" "}
            and send a request to your preferred coach.
          </p>
        ) : null}
        <div className="mt-5 flex flex-wrap gap-2">
          <Button variant="secondary" onClick={load}>
            Refresh profile
          </Button>
          <Link to={passwordPath}>
            <Button variant="secondary">Change password</Button>
          </Link>
        </div>
      </Card>
    </div>
  );
}

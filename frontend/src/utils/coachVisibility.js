/** Member/admin pickers should only offer approved, active coaches. */
export function isSelectableCoach(coach) {
  if (!coach) return false;
  const status = coach.status || "active";
  if (status === "suspended" || status === "pending" || status === "deleted") {
    return false;
  }
  const approval =
    coach.approval_status ||
    coach.coachData?.approval_status ||
    "approved";
  if (approval === "pending" || approval === "rejected") {
    return false;
  }
  return coach.role == null || coach.role === "coach";
}

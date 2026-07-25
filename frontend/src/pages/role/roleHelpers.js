export const fieldClass =
  "mt-1 w-full rounded-[12px] border border-[var(--vf-border)] bg-[var(--vf-surface-muted)] px-3 py-2 text-sm outline-none ring-[var(--vf-accent)] focus:ring-2";

export function formatWhen(value) {
  if (!value) return "";
  try {
    return new Date(value).toLocaleString();
  } catch {
    return "";
  }
}

export async function shareOrCopy(url) {
  if (typeof navigator !== "undefined" && navigator.share) {
    try {
      await navigator.share({
        title: "Vital Fitness",
        url,
        text: "Check out my Vital Fitness progress",
      });
      return "shared";
    } catch {
      /* fall through to copy */
    }
  }
  await navigator.clipboard.writeText(url);
  return "copied";
}

export function assignedCoachFromUser(user) {
  if (!user?.clientData) return null;
  if (user.clientData.assigned_coach) return user.clientData.assigned_coach;
  const raw = user.clientData.assigned_coach_id;
  if (raw && typeof raw === "object") return raw;
  return null;
}

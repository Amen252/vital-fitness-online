import { Check, Copy, Share2, UserPlus } from "lucide-react";
import { useCallback, useEffect, useState } from "react";
import { getErrorMessage } from "../../api/client";
import {
  createShareCard,
  getMemberDietProgress,
  getMemberProgress,
  getMemberWorkoutProgress,
  getMyInvite,
} from "../../api/memberApi";
import { Button, Card } from "../../components/ui";
import { shareOrCopy } from "./roleHelpers";

export default function MemberSharePage() {
  const [invite, setInvite] = useState(null);
  const [shareBusy, setShareBusy] = useState("");
  const [shareMessage, setShareMessage] = useState("");
  const [inviteCopied, setInviteCopied] = useState(false);
  const [hasShareableProgress, setHasShareableProgress] = useState(false);

  const load = useCallback(async () => {
    const [inviteData, progressData, workoutData, dietData] = await Promise.all([
      getMyInvite().catch(() => null),
      getMemberProgress().catch(() => null),
      getMemberWorkoutProgress(7).catch(() => null),
      getMemberDietProgress(7).catch(() => null),
    ]);
    setInvite(inviteData);
    const workoutsDone = workoutData?.summary?.completed ?? 0;
    const dietAdherence = dietData?.weeklyAveragePercent ?? dietData?.avgAdherence ?? 0;
    const waterMl = progressData?.summary?.hydration ?? 0;
    setHasShareableProgress(workoutsDone > 0 || dietAdherence > 0 || waterMl > 0);
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  async function handleShare(type) {
    setShareBusy(type);
    setShareMessage("");
    try {
      const card = await createShareCard(type);
      const result = await shareOrCopy(card.url);
      setShareMessage(result === "shared" ? `Shared: ${card.url}` : `Copied: ${card.url}`);
    } catch (error) {
      setShareMessage(getErrorMessage(error));
    } finally {
      setShareBusy("");
    }
  }

  async function copyInvite() {
    if (!invite?.url && !invite?.code) return;
    const text = invite.url || invite.code;
    try {
      await navigator.clipboard.writeText(text);
      setInviteCopied(true);
      setTimeout(() => setInviteCopied(false), 1800);
    } catch {
      setShareMessage("Could not copy invite link");
    }
  }

  async function shareInvite() {
    if (!invite?.url) return;
    try {
      await shareOrCopy(invite.url);
      setShareMessage("Invite link ready to share.");
    } catch (error) {
      setShareMessage(getErrorMessage(error));
    }
  }

  return (
    <div className="grid gap-5 md:grid-cols-2">
      <Card className="p-6">
        <Share2 className="h-6 w-6 text-[var(--vf-primary)]" />
        <h1 className="mt-4 text-2xl font-bold">Share your progress</h1>
        <p className="mt-2 text-sm text-[var(--vf-muted)]">
          Create a branded public card friends can open — no phone or medical details included.
        </p>
        {!hasShareableProgress ? (
          <p className="mt-3 rounded-[12px] border border-amber-200 bg-amber-50 px-3 py-2 text-sm text-amber-900">
            Complete a workout, log water, or stick to your diet plan to unlock your first share card.
          </p>
        ) : null}
        <div className="mt-4 flex flex-wrap gap-2">
          <Button
            size="sm"
            disabled={Boolean(shareBusy) || !hasShareableProgress}
            onClick={() => handleShare("progress")}
          >
            {shareBusy === "progress" ? "Creating…" : "Share progress"}
          </Button>
          <Button
            size="sm"
            variant="secondary"
            disabled={Boolean(shareBusy)}
            onClick={() => handleShare("weekly")}
          >
            {shareBusy === "weekly" ? "Creating…" : "Share weekly win"}
          </Button>
        </div>
        {shareMessage ? (
          <p className="mt-3 break-all rounded-[12px] bg-[var(--vf-surface-muted)] px-3 py-2 text-xs">
            {shareMessage}
          </p>
        ) : null}
      </Card>

      <Card className="p-6">
        <UserPlus className="h-6 w-6 text-[var(--vf-primary)]" />
        <h2 className="mt-4 text-xl font-bold">Invite friends</h2>
        <p className="mt-2 text-sm text-[var(--vf-muted)]">
          Share your personal invite link. Friends register with your code and you get a notification.
        </p>
        {invite ? (
          <>
            <div className="mt-4 rounded-[12px] border border-[var(--vf-border)] bg-[var(--vf-surface-muted)] px-3 py-3">
              <p className="text-xs font-semibold uppercase tracking-wide text-[var(--vf-muted)]">Your code</p>
              <p className="mt-1 font-mono text-xl font-bold tracking-widest text-[var(--vf-primary)]">
                {invite.code}
              </p>
              <p className="mt-2 break-all text-xs text-[var(--vf-muted)]">{invite.url}</p>
              <p className="mt-2 text-sm">
                <strong>{invite.uses ?? 0}</strong> friend{(invite.uses ?? 0) === 1 ? "" : "s"} joined
              </p>
            </div>
            <div className="mt-4 flex flex-wrap gap-2">
              <Button size="sm" variant="secondary" onClick={copyInvite}>
                {inviteCopied ? <Check className="h-4 w-4" /> : <Copy className="h-4 w-4" />}
                {inviteCopied ? "Copied" : "Copy link"}
              </Button>
              <Button size="sm" onClick={shareInvite}>
                <Share2 className="h-4 w-4" />
                Share invite
              </Button>
            </div>
          </>
        ) : (
          <p className="mt-3 text-sm text-[var(--vf-muted)]">Loading invite link…</p>
        )}
      </Card>
    </div>
  );
}

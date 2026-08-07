import { CalendarDays, Link2, Video } from "lucide-react";
import { useCallback, useEffect, useMemo, useState } from "react";
import { getCoachClients } from "../../api/coachApi";
import {
  cancelSession,
  completeSession,
  confirmSession,
  createFollowUpSession,
  createSession,
  deleteSession,
  getSessions,
  rescheduleSession,
  startSession,
  updateSession,
  updateSessionMeetingLink,
  updateSessionNotes,
  addSessionAttachment,
} from "../../api/sessionApi";
import { getErrorMessage } from "../../api/client";
import { Badge, Button, Card, Spinner, useToast } from "../../components/ui";
import { fieldClass, formatWhen } from "./roleHelpers";

const toneForStatus = {
  pending: "amber",
  confirmed: "green",
  in_progress: "blue",
  completed: "blue",
  cancelled: "red",
  rescheduled: "amber",
  no_show: "red",
};

function toLocalInputValue(date = new Date()) {
  const d = new Date(date);
  d.setMinutes(d.getMinutes() - d.getTimezoneOffset());
  return d.toISOString().slice(0, 16);
}

function statusLabel(status = "") {
  return String(status).replaceAll("_", " ");
}

export default function CoachSessionsPage() {
  const toast = useToast();
  const [sessions, setSessions] = useState([]);
  const [clients, setClients] = useState([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [busyId, setBusyId] = useState("");
  const [selectedId, setSelectedId] = useState("");
  const [detail, setDetail] = useState({
    sessionMode: "in_person",
    meetingLink: "",
    coachNotes: "",
    notes: "",
    durationMinutes: "60",
    rescheduleAt: "",
    followUpAt: "",
    attachmentUrl: "",
    attachmentName: "Session attachment",
  });
  const [form, setForm] = useState({
    clientId: "",
    date: toLocalInputValue(new Date(Date.now() + 60 * 60 * 1000)),
    durationMinutes: "60",
    notes: "",
    sessionMode: "in_person",
    meetingLink: "",
  });

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const [rows, clientRows] = await Promise.all([
        getSessions().catch(() => []),
        getCoachClients().catch(() => []),
      ]);
      setSessions(Array.isArray(rows) ? rows : []);
      setClients(Array.isArray(clientRows) ? clientRows : []);
    } catch (error) {
      toast.error(getErrorMessage(error));
    } finally {
      setLoading(false);
    }
  }, [toast]);

  useEffect(() => {
    load();
  }, [load]);

  const selected = useMemo(
    () => sessions.find((s) => s._id === selectedId) || null,
    [sessions, selectedId],
  );

  useEffect(() => {
    if (!selected) return;
    setDetail({
      sessionMode: selected.sessionMode === "online" ? "online" : "in_person",
      meetingLink: selected.meetingLink || "",
      coachNotes: selected.coachNotes || "",
      notes: selected.notes || "",
      durationMinutes: String(selected.durationMinutes || 60),
      rescheduleAt: selected.date ? toLocalInputValue(new Date(selected.date)) : "",
      followUpAt: toLocalInputValue(new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)),
      attachmentUrl: "",
      attachmentName: "Session attachment",
    });
  }, [selected]);

  const clientOptions = useMemo(
    () =>
      clients
        .map((row) => row.user || row)
        .filter((u) => u?._id)
        .map((u) => ({
          id: u._id,
          label: `${u.full_name || u.username || "Client"} (@${u.username || "—"})`,
        })),
    [clients],
  );

  async function submit(event) {
    event.preventDefault();
    if (!form.clientId || !form.date) {
      toast.error("Select a client and date/time");
      return;
    }
    setSaving(true);
    try {
      await createSession({
        clientId: form.clientId,
        date: new Date(form.date).toISOString(),
        durationMinutes: Number(form.durationMinutes) || 60,
        notes: form.notes.trim(),
        sessionMode: form.sessionMode,
        meetingLink: form.sessionMode === "online" ? form.meetingLink.trim() : "",
      });
      toast.success("1-on-1 session scheduled");
      setForm((c) => ({
        ...c,
        notes: "",
        meetingLink: "",
        date: toLocalInputValue(new Date(Date.now() + 60 * 60 * 1000)),
      }));
      await load();
    } catch (error) {
      toast.error(getErrorMessage(error));
    } finally {
      setSaving(false);
    }
  }

  async function runAction(id, action, payload) {
    setBusyId(id);
    try {
      if (action === "confirm") await confirmSession(id, payload);
      if (action === "start") await startSession(id, payload);
      if (action === "complete") await completeSession(id, payload);
      if (action === "cancel") await cancelSession(id, payload);
      if (action === "reschedule") await rescheduleSession(id, payload);
      if (action === "meeting") await updateSessionMeetingLink(id, payload);
      if (action === "notes") await updateSessionNotes(id, payload);
      if (action === "update") await updateSession(id, payload);
      if (action === "delete") await deleteSession(id);
      if (action === "attachment") await addSessionAttachment(id, payload);
      if (action === "followup") await createFollowUpSession(id, payload);
      toast.success("Session updated");
      await load();
      if (action === "delete" || action === "cancel") setSelectedId("");
    } catch (error) {
      toast.error(getErrorMessage(error));
    } finally {
      setBusyId("");
    }
  }

  return (
    <>
      <Card className="p-6">
        <CalendarDays className="h-6 w-6 text-[var(--vf-primary)]" />
        <h1 className="mt-4 text-2xl font-bold">Schedule 1-on-1 session</h1>
        <p className="mt-2 text-sm text-[var(--vf-muted)]">
          Coach-created sessions sync to the member&apos;s 1-on-1 Sessions page. Separate from appointment requests.
        </p>
        <form onSubmit={submit} className="mt-5 grid gap-4 md:grid-cols-2">
          <label className="block text-sm md:col-span-2">
            Client
            <select
              value={form.clientId}
              onChange={(e) => setForm((c) => ({ ...c, clientId: e.target.value }))}
              className={fieldClass}
              required
            >
              <option value="">Select client</option>
              {clientOptions.map((c) => (
                <option key={c.id} value={c.id}>{c.label}</option>
              ))}
            </select>
          </label>
          <label className="block text-sm">
            Date & time
            <input
              type="datetime-local"
              value={form.date}
              onChange={(e) => setForm((c) => ({ ...c, date: e.target.value }))}
              className={fieldClass}
              required
            />
          </label>
          <label className="block text-sm">
            Duration (minutes)
            <input
              type="number"
              min="15"
              step="15"
              value={form.durationMinutes}
              onChange={(e) => setForm((c) => ({ ...c, durationMinutes: e.target.value }))}
              className={fieldClass}
            />
          </label>
          <label className="block text-sm">
            Session type
            <select
              value={form.sessionMode}
              onChange={(e) => setForm((c) => ({ ...c, sessionMode: e.target.value }))}
              className={fieldClass}
            >
              <option value="in_person">In Person</option>
              <option value="online">Online</option>
            </select>
          </label>
          {form.sessionMode === "online" ? (
            <label className="block text-sm">
              Meeting link
              <input
                type="url"
                value={form.meetingLink}
                onChange={(e) => setForm((c) => ({ ...c, meetingLink: e.target.value }))}
                className={fieldClass}
                placeholder="https://meet.google.com/..."
              />
            </label>
          ) : null}
          <label className="block text-sm md:col-span-2">
            Session goal / notes
            <textarea
              rows={3}
              value={form.notes}
              onChange={(e) => setForm((c) => ({ ...c, notes: e.target.value }))}
              className={fieldClass}
            />
          </label>
          <div className="md:col-span-2">
            <Button type="submit" disabled={saving || clientOptions.length === 0}>
              {saving ? "Scheduling…" : "Create session"}
            </Button>
          </div>
        </form>
      </Card>

      <Card className="mt-5 p-6">
        <div className="flex items-center justify-between gap-3">
          <h2 className="text-xl font-bold">Your 1-on-1 sessions</h2>
          <Button size="sm" variant="secondary" onClick={load} disabled={loading}>
            {loading ? "Loading…" : "Refresh"}
          </Button>
        </div>
        {loading ? (
          <div className="mt-5"><Spinner label="Loading sessions…" /></div>
        ) : (
          <ul className="mt-4 space-y-2">
            {sessions.length === 0 ? (
              <li className="rounded-[12px] border border-[var(--vf-border)] px-3 py-6 text-center text-sm text-[var(--vf-muted)]">
                No sessions yet. Schedule one above.
              </li>
            ) : (
              sessions.map((s) => {
                const client = s.client || {};
                const open = selectedId === s._id;
                return (
                  <li key={s._id} className="rounded-[12px] border border-[var(--vf-border)] px-4 py-3">
                    <div className="flex flex-wrap items-start justify-between gap-3">
                      <div>
                        <p className="font-semibold">
                          {client.full_name || client.username || client.name || "Client"}
                        </p>
                        <p className="text-xs text-[var(--vf-muted)]">
                          {formatWhen(s.date)} · {s.durationMinutes || 60} min ·{" "}
                          {s.sessionMode === "online" ? "Online" : "In Person"}
                        </p>
                        {s.notes ? <p className="mt-1 text-sm text-[var(--vf-muted)]">{s.notes}</p> : null}
                      </div>
                      <div className="flex flex-wrap items-center gap-2">
                        <Badge tone={toneForStatus[s.status] || "amber"}>{statusLabel(s.status)}</Badge>
                        <Button size="sm" variant="secondary" onClick={() => setSelectedId(open ? "" : s._id)}>
                          {open ? "Hide" : "Manage"}
                        </Button>
                      </div>
                    </div>
                    {open && selected ? (
                      <div className="mt-4 grid gap-3 border-t border-[var(--vf-border)] pt-4 md:grid-cols-2">
                        <label className="block text-sm">
                          Session type
                          <select
                            value={detail.sessionMode}
                            onChange={(e) => setDetail((d) => ({ ...d, sessionMode: e.target.value }))}
                            className={fieldClass}
                          >
                            <option value="in_person">In Person</option>
                            <option value="online">Online</option>
                          </select>
                        </label>
                        <label className="block text-sm">
                          Meeting link
                          <input
                            type="url"
                            value={detail.meetingLink}
                            onChange={(e) => setDetail((d) => ({ ...d, meetingLink: e.target.value }))}
                            className={fieldClass}
                          />
                        </label>
                        <label className="block text-sm">
                          Duration (minutes)
                          <input
                            type="number"
                            min="15"
                            step="15"
                            value={detail.durationMinutes}
                            onChange={(e) => setDetail((d) => ({ ...d, durationMinutes: e.target.value }))}
                            className={fieldClass}
                          />
                        </label>
                        <label className="block text-sm md:col-span-2">
                          Session goal
                          <textarea
                            rows={2}
                            value={detail.notes}
                            onChange={(e) => setDetail((d) => ({ ...d, notes: e.target.value }))}
                            className={fieldClass}
                          />
                        </label>
                        <label className="block text-sm md:col-span-2">
                          Coaching notes
                          <textarea
                            rows={3}
                            value={detail.coachNotes}
                            onChange={(e) => setDetail((d) => ({ ...d, coachNotes: e.target.value }))}
                            className={fieldClass}
                          />
                        </label>
                        <label className="block text-sm">
                          Attachment URL
                          <input
                            value={detail.attachmentUrl}
                            onChange={(e) => setDetail((d) => ({ ...d, attachmentUrl: e.target.value }))}
                            className={fieldClass}
                            placeholder="https://... or data:image/..."
                          />
                        </label>
                        <label className="block text-sm">
                          Attachment name
                          <input
                            value={detail.attachmentName}
                            onChange={(e) => setDetail((d) => ({ ...d, attachmentName: e.target.value }))}
                            className={fieldClass}
                          />
                        </label>
                        <label className="block text-sm">
                          Reschedule to
                          <input
                            type="datetime-local"
                            value={detail.rescheduleAt}
                            onChange={(e) => setDetail((d) => ({ ...d, rescheduleAt: e.target.value }))}
                            className={fieldClass}
                          />
                        </label>
                        <label className="block text-sm">
                          Follow-up at
                          <input
                            type="datetime-local"
                            value={detail.followUpAt}
                            onChange={(e) => setDetail((d) => ({ ...d, followUpAt: e.target.value }))}
                            className={fieldClass}
                          />
                        </label>
                        <div className="md:col-span-2 flex flex-wrap gap-2">
                          {s.status === "pending" ? (
                            <Button size="sm" disabled={busyId === s._id} onClick={() => runAction(s._id, "confirm", {
                              coachNotes: detail.coachNotes,
                              sessionMode: detail.sessionMode,
                              meetingLink: detail.meetingLink,
                            })}>
                              Confirm
                            </Button>
                          ) : null}
                          {["confirmed", "rescheduled"].includes(s.status) ? (
                            <Button size="sm" disabled={busyId === s._id} onClick={() => runAction(s._id, "start", {
                              sessionMode: detail.sessionMode,
                              meetingLink: detail.meetingLink,
                            })}>
                              <Video className="mr-1 h-3.5 w-3.5" /> Start
                            </Button>
                          ) : null}
                          {["confirmed", "rescheduled", "in_progress"].includes(s.status) ? (
                            <Button size="sm" disabled={busyId === s._id} onClick={() => runAction(s._id, "complete", {
                              coachNotes: detail.coachNotes,
                            })}>
                              Complete
                            </Button>
                          ) : null}
                          {!["completed", "cancelled", "no_show"].includes(s.status) ? (
                            <>
                              <Button size="sm" variant="secondary" disabled={busyId === s._id || !detail.rescheduleAt} onClick={() => runAction(s._id, "reschedule", {
                                date: new Date(detail.rescheduleAt).toISOString(),
                                coachNotes: detail.coachNotes,
                              })}>
                                Reschedule
                              </Button>
                              <Button size="sm" variant="danger" disabled={busyId === s._id} onClick={() => runAction(s._id, "cancel", {
                                coachNotes: detail.coachNotes,
                              })}>
                                Cancel
                              </Button>
                              <Button size="sm" variant="secondary" disabled={busyId === s._id} onClick={() => runAction(s._id, "update", {
                                durationMinutes: Number(detail.durationMinutes) || 60,
                                notes: detail.notes,
                                coachNotes: detail.coachNotes,
                                sessionMode: detail.sessionMode,
                                meetingLink: detail.meetingLink,
                              })}>
                                Save details
                              </Button>
                              <Button size="sm" variant="secondary" disabled={busyId === s._id} onClick={() => runAction(s._id, "meeting", {
                                sessionMode: detail.sessionMode,
                                meetingLink: detail.meetingLink,
                              })}>
                                Save link / type
                              </Button>
                              <Button size="sm" variant="secondary" disabled={busyId === s._id} onClick={() => runAction(s._id, "notes", {
                                coachNotes: detail.coachNotes,
                                notes: detail.notes,
                              })}>
                                Save notes
                              </Button>
                              <Button size="sm" variant="secondary" disabled={busyId === s._id || !detail.attachmentUrl} onClick={() => runAction(s._id, "attachment", {
                                file: detail.attachmentUrl,
                                name: detail.attachmentName,
                              })}>
                                Add attachment
                              </Button>
                            </>
                          ) : null}
                          {["completed", "in_progress", "confirmed", "rescheduled"].includes(s.status) ? (
                            <Button size="sm" variant="secondary" disabled={busyId === s._id || !detail.followUpAt} onClick={() => runAction(s._id, "followup", {
                              date: new Date(detail.followUpAt).toISOString(),
                              durationMinutes: Number(detail.durationMinutes) || s.durationMinutes || 60,
                              sessionMode: detail.sessionMode,
                              meetingLink: detail.meetingLink,
                              notes: "Follow-up session",
                              coachNotes: detail.coachNotes,
                            })}>
                              Schedule follow-up
                            </Button>
                          ) : null}
                          {["cancelled", "completed", "no_show"].includes(s.status) ? (
                            <Button size="sm" variant="danger" disabled={busyId === s._id} onClick={() => runAction(s._id, "delete")}>
                              Delete
                            </Button>
                          ) : null}
                        </div>
                        {Array.isArray(s.attachments) && s.attachments.length > 0 ? (
                          <div className="md:col-span-2 text-sm text-[var(--vf-muted)]">
                            Attachments:{" "}
                            {s.attachments.map((file, idx) => (
                              <a
                                key={`${file.url}-${idx}`}
                                href={file.url}
                                target="_blank"
                                rel="noreferrer"
                                className="mr-2 text-[var(--vf-primary)]"
                              >
                                {file.name || `File ${idx + 1}`}
                              </a>
                            ))}
                          </div>
                        ) : null}
                        {s.meetingLink ? (
                          <a href={s.meetingLink} target="_blank" rel="noreferrer" className="md:col-span-2 inline-flex items-center gap-1 text-sm text-[var(--vf-primary)]">
                            <Link2 className="h-3.5 w-3.5" /> {s.meetingLink}
                          </a>
                        ) : null}
                      </div>
                    ) : null}
                  </li>
                );
              })
            )}
          </ul>
        )}
      </Card>
    </>
  );
}

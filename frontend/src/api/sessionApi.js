import api from "./client";

export const getSessions = () => api.get("/session").then((r) => r.data);

export const createSession = (payload) =>
  api.post("/session", payload).then((r) => r.data);

export const confirmSession = (id, payload = {}) =>
  api.patch(`/session/${id}/confirm`, payload).then((r) => r.data);

export const rescheduleSession = (id, payload) =>
  api.patch(`/session/${id}/reschedule`, payload).then((r) => r.data);

export const startSession = (id, payload = {}) =>
  api.patch(`/session/${id}/start`, payload).then((r) => r.data);

export const updateSessionMeetingLink = (id, payload) =>
  api.patch(`/session/${id}/meeting-link`, payload).then((r) => r.data);

export const completeSession = (id, payload = {}) =>
  api.patch(`/session/${id}/complete`, payload).then((r) => r.data);

export const cancelSession = (id, payload = {}) =>
  api.patch(`/session/${id}/cancel`, payload).then((r) => r.data);

export const updateSessionNotes = (id, payload) =>
  api.patch(`/session/${id}/notes`, payload).then((r) => r.data);

export const updateSession = (id, payload) =>
  api.patch(`/session/${id}`, payload).then((r) => r.data);

export const deleteSession = (id) =>
  api.delete(`/session/${id}`).then((r) => r.data);

export const addSessionAttachment = (id, payload) =>
  api.post(`/session/${id}/attachments`, payload).then((r) => r.data);

export const createFollowUpSession = (id, payload) =>
  api.post(`/session/${id}/follow-up`, payload).then((r) => r.data);

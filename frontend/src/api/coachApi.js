import api from "./client";

export const getCoachClients = () =>
  api.get("/coach/clients").then((r) => r.data);

export const getCoachClientDetail = (clientId) =>
  api.get(`/coach/clients/${clientId}`).then((r) => r.data);

export const getCoachAppointments = () =>
  api.get("/coach/appointments").then((r) => r.data);

export const createCoachAppointment = ({
  clientId,
  dateTime,
  durationMinutes = 60,
  notes = "",
  coachNotes = "",
}) =>
  api
    .post("/coach/appointments", {
      clientId,
      dateTime,
      durationMinutes,
      notes,
      coachNotes,
    })
    .then((r) => r.data);

export const completeCoachAppointment = (id) =>
  api.patch(`/coach/appointments/${id}/complete`).then((r) => r.data);

export const cancelCoachAppointment = (id) =>
  api.patch(`/coach/appointments/${id}/cancel`).then((r) => r.data);

export const approveCoachAppointment = (id) =>
  api.patch(`/coach/appointments/${id}/approve`).then((r) => r.data);

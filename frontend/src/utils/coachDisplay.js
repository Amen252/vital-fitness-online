export function coachDisplayName(coach) {
  if (!coach) return "Coach";
  return coach.full_name || coach.name || coach.username || "Coach";
}

export function coachDisplayEmail(coach) {
  if (!coach) return "";
  return coach.username || coach.email || "";
}

function asList(value) {
  if (Array.isArray(value)) return value.filter(Boolean);
  if (typeof value === "string" && value.trim()) {
    return value.split(",").map((item) => item.trim()).filter(Boolean);
  }
  return [];
}

export function coachProfileFromUser(coach) {
  if (!coach) return {};
  if (coach.profile && typeof coach.profile === "object" && !coach.profile.buffer) {
    const profile = { ...coach.profile };
    profile.phone = profile.phone || coach.phone || "";
    profile.specialization = asList(profile.specialization || profile.specialties);
    profile.photoUrl = profile.photoUrl || coach.avatar || "";
    if (!Array.isArray(profile.certificateFiles) || !profile.certificateFiles.length) {
      profile.certificateFiles = Array.isArray(coach.coachData?.certificateFiles)
        ? coach.coachData.certificateFiles
        : [];
    }
    return profile;
  }

  const data = coach.coachData || {};
  const availability = data.availability || {};

  return {
    age: data.age ?? null,
    phone: coach.phone || "",
    location: data.location || "",
    bio: data.bio || "",
    experience: data.experience || "",
    specialization: asList(data.specialties || data.specialization),
    yearsExperience: data.years_experience ?? data.yearsExperience ?? null,
    certifications: Array.isArray(data.certifications)
      ? data.certifications.join(", ")
      : data.certifications || "",
    workingDays: availability.workingDays || data.workingDays || [],
    appointmentDays: availability.appointmentDays || data.appointmentDays || [],
    workingHoursStart: availability.workingHoursStart || "",
    workingHoursEnd: availability.workingHoursEnd || "",
    appointmentDurationMinutes: data.appointmentDurationMinutes ?? 60,
    dayAvailability: data.dayAvailability || [],
    photoUrl: data.photoUrl || coach.avatar || "",
    certificateFiles: Array.isArray(data.certificateFiles) ? data.certificateFiles : [],
  };
}

export function memberDisplayName(member) {
  if (!member) return "Member";
  return member.full_name || member.name || member.username || "Member";
}

export function memberDisplayEmail(member) {
  if (!member) return "";
  return member.username || member.email || "";
}

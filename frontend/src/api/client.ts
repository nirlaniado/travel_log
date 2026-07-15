import type {
  Note,
  NoteInput,
  Place,
  PlaceDetail,
  PlaceInput,
  PlaceStatus,
  User,
} from "../types";

const API_URL = import.meta.env.VITE_API_URL ?? "http://localhost:8000";

export class ApiError extends Error {
  status: number;

  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

async function request<T>(path: string, options: RequestInit = {}): Promise<T> {
  const res = await fetch(`${API_URL}${path}`, {
    ...options,
    credentials: "include",
    headers: options.body ? { "Content-Type": "application/json" } : undefined,
  });

  if (!res.ok) {
    let message = `Request failed (${res.status})`;
    try {
      const data = await res.json();
      if (typeof data.detail === "string") {
        message = data.detail;
      } else if (Array.isArray(data.detail) && data.detail.length > 0) {
        const first = data.detail[0];
        const field = Array.isArray(first.loc) ? first.loc.slice(1).join(".") : "";
        message = field ? `${field}: ${first.msg}` : first.msg;
      }
    } catch {
      // non-JSON error body; keep the generic message
    }
    throw new ApiError(res.status, message);
  }

  if (res.status === 204) {
    return undefined as T;
  }
  return res.json();
}

export const api = {
  register: (username: string, password: string) =>
    request<User>("/auth/register", {
      method: "POST",
      body: JSON.stringify({ username, password }),
    }),

  login: (username: string, password: string) =>
    request<User>("/auth/login", {
      method: "POST",
      body: JSON.stringify({ username, password }),
    }),

  logout: () => request<{ message: string }>("/auth/logout", { method: "POST" }),

  me: () => request<User>("/auth/me"),

  listPlaces: (status?: PlaceStatus) =>
    request<Place[]>(status ? `/places?status=${status}` : "/places"),

  getPlace: (id: number) => request<PlaceDetail>(`/places/${id}`),

  createPlace: (input: PlaceInput) =>
    request<Place>("/places", { method: "POST", body: JSON.stringify(input) }),

  updatePlace: (id: number, input: PlaceInput) =>
    request<Place>(`/places/${id}`, { method: "PUT", body: JSON.stringify(input) }),

  deletePlace: (id: number) => request<void>(`/places/${id}`, { method: "DELETE" }),

  createNote: (placeId: number, input: NoteInput) =>
    request<Note>(`/places/${placeId}/notes`, {
      method: "POST",
      body: JSON.stringify(input),
    }),

  updateNote: (noteId: number, input: NoteInput) =>
    request<Note>(`/notes/${noteId}`, { method: "PUT", body: JSON.stringify(input) }),

  deleteNote: (noteId: number) => request<void>(`/notes/${noteId}`, { method: "DELETE" }),
};

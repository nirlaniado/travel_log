import { useState, type FormEvent } from "react";
import type { PlaceInput, PlaceStatus } from "../types";

interface Props {
  initial?: PlaceInput;
  submitLabel: string;
  onSubmit: (input: PlaceInput) => Promise<void>;
}

const EMPTY: PlaceInput = {
  name: "",
  country: "",
  city: null,
  latitude: null,
  longitude: null,
  status: "wishlist",
  rating: null,
  visited_at: null,
};

export default function PlaceForm({ initial, submitLabel, onSubmit }: Props) {
  const [form, setForm] = useState<PlaceInput>(initial ?? EMPTY);
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const set = <K extends keyof PlaceInput>(key: K, value: PlaceInput[K]) =>
    setForm((f) => ({ ...f, [key]: value }));

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setError(null);
    setSaving(true);
    try {
      await onSubmit(form);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Something went wrong");
    } finally {
      setSaving(false);
    }
  };

  return (
    <form onSubmit={handleSubmit} className="form card">
      {error && <div className="alert">{error}</div>}

      <label>
        Name *
        <input
          value={form.name}
          onChange={(e) => set("name", e.target.value)}
          required
          maxLength={120}
          placeholder="Eiffel Tower"
        />
      </label>

      <div className="form-row">
        <label>
          Country *
          <input
            value={form.country}
            onChange={(e) => set("country", e.target.value)}
            required
            maxLength={80}
            placeholder="France"
          />
        </label>
        <label>
          City
          <input
            value={form.city ?? ""}
            onChange={(e) => set("city", e.target.value || null)}
            maxLength={80}
            placeholder="Paris"
          />
        </label>
      </div>

      <div className="form-row">
        <label>
          Latitude
          <input
            type="number"
            step="any"
            min={-90}
            max={90}
            value={form.latitude ?? ""}
            onChange={(e) => set("latitude", e.target.value || null)}
            placeholder="48.8584"
          />
        </label>
        <label>
          Longitude
          <input
            type="number"
            step="any"
            min={-180}
            max={180}
            value={form.longitude ?? ""}
            onChange={(e) => set("longitude", e.target.value || null)}
            placeholder="2.2945"
          />
        </label>
      </div>

      <div className="form-row">
        <label>
          Status *
          <select
            value={form.status}
            onChange={(e) => set("status", e.target.value as PlaceStatus)}
          >
            <option value="wishlist">Wishlist</option>
            <option value="visited">Visited</option>
            <option value="liked">Liked</option>
          </select>
        </label>
        <label>
          Rating
          <select
            value={form.rating ?? ""}
            onChange={(e) => set("rating", e.target.value ? Number(e.target.value) : null)}
          >
            <option value="">No rating</option>
            {[1, 2, 3, 4, 5].map((n) => (
              <option key={n} value={n}>
                {"★".repeat(n)}
              </option>
            ))}
          </select>
        </label>
      </div>

      <label>
        Visited date
        <input
          type="date"
          value={form.visited_at ?? ""}
          onChange={(e) => set("visited_at", e.target.value || null)}
        />
      </label>

      <button type="submit" className="btn btn-primary" disabled={saving}>
        {saving ? "Saving…" : submitLabel}
      </button>
    </form>
  );
}

import { useCallback, useEffect, useState } from "react";
import { api } from "../api/client";
import PlaceCard from "../components/PlaceCard";
import type { Place, PlaceStatus } from "../types";

const SECTIONS: { status: PlaceStatus; title: string }[] = [
  { status: "visited", title: "✅ Visited places" },
  { status: "wishlist", title: "🧭 Wishlist" },
  { status: "liked", title: "❤️ Liked destinations" },
];

type Filter = PlaceStatus | "all";

export default function DashboardPage() {
  const [places, setPlaces] = useState<Place[]>([]);
  const [filter, setFilter] = useState<Filter>("all");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setError(null);
    try {
      setPlaces(await api.listPlaces(filter === "all" ? undefined : filter));
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to load places");
    } finally {
      setLoading(false);
    }
  }, [filter]);

  useEffect(() => {
    load();
  }, [load]);

  const handleDelete = async (id: number) => {
    if (!window.confirm("Delete this place and all its notes?")) return;
    try {
      await api.deletePlace(id);
      setPlaces((prev) => prev.filter((p) => p.id !== id));
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to delete place");
    }
  };

  if (loading) {
    return <div className="page-message">Loading…</div>;
  }

  const visibleSections = SECTIONS.filter(
    (s) => filter === "all" || s.status === filter
  );

  return (
    <div className="page">
      <div className="page-header">
        <h1>My travel log</h1>
        <div className="filter-bar" role="group" aria-label="Filter by status">
          {(["all", "visited", "wishlist", "liked"] as Filter[]).map((f) => (
            <button
              key={f}
              className={`btn btn-sm ${filter === f ? "btn-primary" : "btn-outline"}`}
              onClick={() => setFilter(f)}
            >
              {f === "all" ? "All" : f[0].toUpperCase() + f.slice(1)}
            </button>
          ))}
        </div>
      </div>

      {error && <div className="alert">{error}</div>}

      {places.length === 0 && !error && (
        <p className="page-message">
          Nothing here yet — add your first place from the navigation bar.
        </p>
      )}

      {visibleSections.map(({ status, title }) => {
        const sectionPlaces = places.filter((p) => p.status === status);
        if (sectionPlaces.length === 0) return null;
        return (
          <section key={status} className="dashboard-section">
            <h2>{title}</h2>
            <div className="card-grid">
              {sectionPlaces.map((place) => (
                <PlaceCard key={place.id} place={place} onDelete={handleDelete} />
              ))}
            </div>
          </section>
        );
      })}
    </div>
  );
}

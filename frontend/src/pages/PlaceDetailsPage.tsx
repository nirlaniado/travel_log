import { useCallback, useEffect, useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { api } from "../api/client";
import NotesSection from "../components/NotesSection";
import { formatDate, Stars } from "../components/PlaceCard";
import type { PlaceDetail } from "../types";

const STATUS_LABELS = {
  visited: "Visited",
  wishlist: "Wishlist",
  liked: "Liked",
} as const;

export default function PlaceDetailsPage() {
  const { placeId } = useParams();
  const navigate = useNavigate();
  const [place, setPlace] = useState<PlaceDetail | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    try {
      setPlace(await api.getPlace(Number(placeId)));
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to load place");
    }
  }, [placeId]);

  useEffect(() => {
    load();
  }, [load]);

  const handleDelete = async () => {
    if (!place) return;
    if (!window.confirm("Delete this place and all its notes?")) return;
    await api.deletePlace(place.id);
    navigate("/");
  };

  if (error) {
    return <div className="page-message alert">{error}</div>;
  }
  if (!place) {
    return <div className="page-message">Loading…</div>;
  }

  return (
    <div className="page page-narrow">
      <div className="details-header">
        <div>
          <h1>{place.name}</h1>
          <p className="place-location">
            {place.city ? `${place.city}, ` : ""}
            {place.country}
          </p>
        </div>
        <span className={`badge badge-${place.status}`}>{STATUS_LABELS[place.status]}</span>
      </div>

      <div className="card details-card">
        <dl className="details-list">
          {place.rating != null && (
            <>
              <dt>Rating</dt>
              <dd>
                <Stars rating={place.rating} />
              </dd>
            </>
          )}
          {place.visited_at && (
            <>
              <dt>Visited</dt>
              <dd>{formatDate(place.visited_at)}</dd>
            </>
          )}
          {place.latitude != null && place.longitude != null && (
            <>
              <dt>Coordinates</dt>
              <dd>
                {place.latitude}, {place.longitude}
              </dd>
            </>
          )}
        </dl>
        <div className="card-actions">
          <Link to={`/places/${place.id}/edit`} className="btn btn-outline btn-sm">
            Edit
          </Link>
          <button onClick={handleDelete} className="btn btn-danger btn-sm">
            Delete
          </button>
        </div>
      </div>

      <NotesSection placeId={place.id} notes={place.notes} onChanged={load} />
    </div>
  );
}

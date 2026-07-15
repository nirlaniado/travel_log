import { Link } from "react-router-dom";
import type { Place } from "../types";

const STATUS_LABELS: Record<Place["status"], string> = {
  visited: "Visited",
  wishlist: "Wishlist",
  liked: "Liked",
};

export function formatDate(iso: string): string {
  return new Date(iso + "T00:00:00").toLocaleDateString();
}

export function Stars({ rating }: { rating: number }) {
  return (
    <span className="stars" aria-label={`${rating} out of 5`}>
      {"★".repeat(rating)}
      {"☆".repeat(5 - rating)}
    </span>
  );
}

interface Props {
  place: Place;
  onDelete: (id: number) => void;
}

export default function PlaceCard({ place, onDelete }: Props) {
  return (
    <div className="card place-card">
      <div className="place-card-header">
        <Link to={`/places/${place.id}`} className="place-name">
          {place.name}
        </Link>
        <span className={`badge badge-${place.status}`}>{STATUS_LABELS[place.status]}</span>
      </div>
      <p className="place-location">
        {place.city ? `${place.city}, ` : ""}
        {place.country}
      </p>
      <div className="place-meta">
        {place.rating != null && <Stars rating={place.rating} />}
        {place.visited_at && <span className="place-date">Visited {formatDate(place.visited_at)}</span>}
      </div>
      <div className="card-actions">
        <Link to={`/places/${place.id}/edit`} className="btn btn-outline btn-sm">
          Edit
        </Link>
        <button onClick={() => onDelete(place.id)} className="btn btn-danger btn-sm">
          Delete
        </button>
      </div>
    </div>
  );
}

import { useEffect, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { api } from "../api/client";
import PlaceForm from "../components/PlaceForm";
import type { PlaceDetail, PlaceInput } from "../types";

export default function EditPlacePage() {
  const { placeId } = useParams();
  const navigate = useNavigate();
  const [place, setPlace] = useState<PlaceDetail | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    api
      .getPlace(Number(placeId))
      .then(setPlace)
      .catch((err) => setError(err instanceof Error ? err.message : "Failed to load place"));
  }, [placeId]);

  if (error) {
    return <div className="page-message alert">{error}</div>;
  }
  if (!place) {
    return <div className="page-message">Loading…</div>;
  }

  const initial: PlaceInput = {
    name: place.name,
    country: place.country,
    city: place.city,
    latitude: place.latitude,
    longitude: place.longitude,
    status: place.status,
    rating: place.rating,
    visited_at: place.visited_at,
  };

  const handleSubmit = async (input: PlaceInput) => {
    await api.updatePlace(place.id, input);
    navigate(`/places/${place.id}`);
  };

  return (
    <div className="page page-narrow">
      <h1>Edit {place.name}</h1>
      <PlaceForm initial={initial} submitLabel="Save changes" onSubmit={handleSubmit} />
    </div>
  );
}

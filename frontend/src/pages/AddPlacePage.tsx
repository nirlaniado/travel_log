import { useNavigate } from "react-router-dom";
import { api } from "../api/client";
import PlaceForm from "../components/PlaceForm";
import type { PlaceInput } from "../types";

export default function AddPlacePage() {
  const navigate = useNavigate();

  const handleSubmit = async (input: PlaceInput) => {
    const place = await api.createPlace(input);
    navigate(`/places/${place.id}`);
  };

  return (
    <div className="page page-narrow">
      <h1>Add a place</h1>
      <PlaceForm submitLabel="Add place" onSubmit={handleSubmit} />
    </div>
  );
}

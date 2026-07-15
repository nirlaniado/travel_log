export type PlaceStatus = "visited" | "wishlist" | "liked";

export interface User {
  id: number;
  username: string;
  created_at: string;
}

export interface Place {
  id: number;
  name: string;
  country: string;
  city: string | null;
  latitude: string | null;
  longitude: string | null;
  status: PlaceStatus;
  rating: number | null;
  visited_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface Note {
  id: number;
  place_id: number;
  title: string;
  content: string;
  created_at: string;
  updated_at: string;
}

export interface PlaceDetail extends Place {
  notes: Note[];
}

export interface PlaceInput {
  name: string;
  country: string;
  city: string | null;
  latitude: string | null;
  longitude: string | null;
  status: PlaceStatus;
  rating: number | null;
  visited_at: string | null;
}

export interface NoteInput {
  title: string;
  content: string;
}

import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter } from "react-router-dom";
import { describe, expect, it, vi } from "vitest";
import PlaceCard, { Stars, formatDate } from "./PlaceCard";
import type { Place } from "../types";

const BASE_PLACE: Place = {
  id: 1,
  name: "Eiffel Tower",
  country: "France",
  city: "Paris",
  latitude: "48.8584",
  longitude: "2.2945",
  status: "visited",
  rating: 4,
  visited_at: "2025-06-01",
  created_at: "2025-06-01T00:00:00",
  updated_at: "2025-06-01T00:00:00",
};

function renderCard(place: Partial<Place> = {}, onDelete = vi.fn()) {
  render(
    <MemoryRouter>
      <PlaceCard place={{ ...BASE_PLACE, ...place }} onDelete={onDelete} />
    </MemoryRouter>
  );
  return onDelete;
}

describe("Stars", () => {
  it("renders filled and empty stars matching the rating", () => {
    render(<Stars rating={3} />);
    const el = screen.getByLabelText("3 out of 5");
    expect(el.textContent).toBe("★★★☆☆");
  });
});

describe("formatDate", () => {
  it("formats an ISO date string without a timezone shift", () => {
    // Guards against the classic "new Date('2025-06-01')" UTC-parses-then-
    // local-renders bug that shows the wrong day near midnight.
    expect(formatDate("2025-06-01")).toBe(new Date(2025, 5, 1).toLocaleDateString());
  });
});

describe("PlaceCard", () => {
  it("shows the place name, location, and status badge", () => {
    renderCard();
    expect(screen.getByRole("link", { name: "Eiffel Tower" })).toBeInTheDocument();
    expect(screen.getByText("Paris, France")).toBeInTheDocument();
    expect(screen.getByText("Visited")).toBeInTheDocument();
  });

  it("omits the city when the place has none", () => {
    renderCard({ city: null });
    expect(screen.getByText("France")).toBeInTheDocument();
  });

  it("hides rating and visited date when absent", () => {
    renderCard({ rating: null, visited_at: null });
    expect(screen.queryByLabelText(/out of 5/)).not.toBeInTheDocument();
    expect(screen.queryByText(/Visited \d/)).not.toBeInTheDocument();
  });

  it("calls onDelete with the place id when Delete is clicked", async () => {
    const user = userEvent.setup();
    const onDelete = renderCard();
    await user.click(screen.getByRole("button", { name: "Delete" }));
    expect(onDelete).toHaveBeenCalledWith(1);
  });

  it("links Edit to the place's edit route", () => {
    renderCard();
    expect(screen.getByRole("link", { name: "Edit" })).toHaveAttribute("href", "/places/1/edit");
  });
});

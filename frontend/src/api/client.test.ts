import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { api, ApiError } from "./client";

function mockFetchOnce(response: Partial<Response> & { jsonBody?: unknown }) {
  const { jsonBody, ...rest } = response;
  globalThis.fetch = vi.fn().mockResolvedValue({
    ok: true,
    status: 200,
    json: async () => jsonBody,
    ...rest,
  } as Response);
}

describe("api client", () => {
  beforeEach(() => {
    vi.restoreAllMocks();
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it("sends credentials: include on every request", async () => {
    mockFetchOnce({ jsonBody: { id: 1, username: "alice", created_at: "2026-01-01" } });
    await api.me();
    expect(globalThis.fetch).toHaveBeenCalledWith(
      expect.stringContaining("/auth/me"),
      expect.objectContaining({ credentials: "include" })
    );
  });

  it("sends a JSON content-type header when a body is present", async () => {
    mockFetchOnce({ jsonBody: { id: 1, username: "alice", created_at: "2026-01-01" } });
    await api.login("alice", "supersecret1");
    const [, options] = (globalThis.fetch as ReturnType<typeof vi.fn>).mock.calls[0];
    expect(options.headers).toEqual({ "Content-Type": "application/json" });
    expect(JSON.parse(options.body)).toEqual({ username: "alice", password: "supersecret1" });
  });

  it("throws ApiError with the detail string from a JSON error body", async () => {
    mockFetchOnce({ ok: false, status: 401, jsonBody: { detail: "Invalid username or password" } });
    await expect(api.login("alice", "wrong")).rejects.toMatchObject({
      status: 401,
      message: "Invalid username or password",
    });
  });

  it("formats pydantic-style validation error arrays into a readable message", async () => {
    mockFetchOnce({
      ok: false,
      status: 422,
      jsonBody: {
        detail: [{ loc: ["body", "password"], msg: "String should have at least 8 characters" }],
      },
    });
    try {
      await api.register("alice", "short");
      expect.unreachable();
    } catch (err) {
      expect(err).toBeInstanceOf(ApiError);
      expect((err as ApiError).message).toBe("password: String should have at least 8 characters");
    }
  });

  it("falls back to a generic message when the error body isn't JSON", async () => {
    mockFetchOnce({
      ok: false,
      status: 500,
      json: async () => {
        throw new Error("not json");
      },
    });
    await expect(api.me()).rejects.toMatchObject({ status: 500, message: "Request failed (500)" });
  });

  it("returns undefined for a 204 No Content response", async () => {
    globalThis.fetch = vi.fn().mockResolvedValue({ ok: true, status: 204 } as Response);
    await expect(api.deletePlace(1)).resolves.toBeUndefined();
  });
});

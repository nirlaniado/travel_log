import { useState, type FormEvent } from "react";
import { api } from "../api/client";
import type { Note, NoteInput } from "../types";

interface NoteFormProps {
  initial?: NoteInput;
  submitLabel: string;
  onSubmit: (input: NoteInput) => Promise<void>;
  onCancel?: () => void;
}

function NoteForm({ initial, submitLabel, onSubmit, onCancel }: NoteFormProps) {
  const [title, setTitle] = useState(initial?.title ?? "");
  const [content, setContent] = useState(initial?.content ?? "");
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setError(null);
    setSaving(true);
    try {
      await onSubmit({ title, content });
      setTitle("");
      setContent("");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Something went wrong");
    } finally {
      setSaving(false);
    }
  };

  return (
    <form onSubmit={handleSubmit} className="form note-form">
      {error && <div className="alert">{error}</div>}
      <label>
        Title
        <input
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          required
          maxLength={120}
          placeholder="Best croissant in town"
        />
      </label>
      <label>
        Note
        <textarea
          value={content}
          onChange={(e) => setContent(e.target.value)}
          required
          maxLength={10000}
          rows={3}
          placeholder="What do you want to remember about this place?"
        />
      </label>
      <div className="card-actions">
        <button type="submit" className="btn btn-primary btn-sm" disabled={saving}>
          {saving ? "Saving…" : submitLabel}
        </button>
        {onCancel && (
          <button type="button" className="btn btn-outline btn-sm" onClick={onCancel}>
            Cancel
          </button>
        )}
      </div>
    </form>
  );
}

interface Props {
  placeId: number;
  notes: Note[];
  onChanged: () => void;
}

export default function NotesSection({ placeId, notes, onChanged }: Props) {
  const [editingId, setEditingId] = useState<number | null>(null);

  const addNote = async (input: NoteInput) => {
    await api.createNote(placeId, input);
    onChanged();
  };

  const saveNote = async (noteId: number, input: NoteInput) => {
    await api.updateNote(noteId, input);
    setEditingId(null);
    onChanged();
  };

  const removeNote = async (noteId: number) => {
    if (!window.confirm("Delete this note?")) return;
    await api.deleteNote(noteId);
    onChanged();
  };

  return (
    <section className="notes-section">
      <h2>Notes</h2>
      {notes.length === 0 && <p className="muted">No notes yet.</p>}
      <ul className="notes-list">
        {notes.map((note) => (
          <li key={note.id} className="card note-card">
            {editingId === note.id ? (
              <NoteForm
                initial={{ title: note.title, content: note.content }}
                submitLabel="Save"
                onSubmit={(input) => saveNote(note.id, input)}
                onCancel={() => setEditingId(null)}
              />
            ) : (
              <>
                <div className="note-header">
                  <h3>{note.title}</h3>
                  <span className="muted note-date">
                    {new Date(note.created_at).toLocaleDateString()}
                  </span>
                </div>
                <p className="note-content">{note.content}</p>
                <div className="card-actions">
                  <button
                    className="btn btn-outline btn-sm"
                    onClick={() => setEditingId(note.id)}
                  >
                    Edit
                  </button>
                  <button
                    className="btn btn-danger btn-sm"
                    onClick={() => removeNote(note.id)}
                  >
                    Delete
                  </button>
                </div>
              </>
            )}
          </li>
        ))}
      </ul>
      <h3>Add a note</h3>
      <NoteForm submitLabel="Add note" onSubmit={addNote} />
    </section>
  );
}

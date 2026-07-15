from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..database import get_db
from ..deps import get_current_user
from ..models import PlaceNote, User
from ..schemas import NoteOut, NoteUpdate

router = APIRouter(prefix="/notes", tags=["notes"])


def get_owned_note(
    note_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> PlaceNote:
    note = db.execute(
        select(PlaceNote).where(PlaceNote.id == note_id, PlaceNote.user_id == user.id)
    ).scalar_one_or_none()
    if note is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Note not found")
    return note


@router.put("/{note_id}", response_model=NoteOut)
def update_note(
    payload: NoteUpdate,
    note: PlaceNote = Depends(get_owned_note),
    db: Session = Depends(get_db),
):
    note.title = payload.title
    note.content = payload.content
    db.commit()
    db.refresh(note)
    return note


@router.delete("/{note_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_note(
    note: PlaceNote = Depends(get_owned_note),
    db: Session = Depends(get_db),
):
    db.delete(note)
    db.commit()

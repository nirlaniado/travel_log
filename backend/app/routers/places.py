from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from ..database import get_db
from ..deps import get_current_user
from ..models import Place, PlaceNote, PlaceStatus, User
from ..schemas import NoteCreate, NoteOut, PlaceCreate, PlaceDetailOut, PlaceOut, PlaceUpdate

router = APIRouter(prefix="/places", tags=["places"])


def get_owned_place(
    place_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> Place:
    place = db.execute(
        select(Place)
        .options(selectinload(Place.notes))
        .where(Place.id == place_id, Place.user_id == user.id)
    ).scalar_one_or_none()
    # 404 (not 403) for other users' places: don't reveal that the id exists.
    if place is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Place not found")
    return place


@router.get("", response_model=list[PlaceOut])
def list_places(
    status_filter: PlaceStatus | None = Query(default=None, alias="status"),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    query = select(Place).where(Place.user_id == user.id).order_by(Place.created_at.desc())
    if status_filter is not None:
        query = query.where(Place.status == status_filter)
    return db.execute(query).scalars().all()


@router.post("", response_model=PlaceOut, status_code=status.HTTP_201_CREATED)
def create_place(
    payload: PlaceCreate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    place = Place(user_id=user.id, **payload.model_dump())
    db.add(place)
    db.commit()
    db.refresh(place)
    return place


@router.get("/{place_id}", response_model=PlaceDetailOut)
def get_place(place: Place = Depends(get_owned_place)):
    return place


@router.put("/{place_id}", response_model=PlaceOut)
def update_place(
    payload: PlaceUpdate,
    place: Place = Depends(get_owned_place),
    db: Session = Depends(get_db),
):
    for field, value in payload.model_dump().items():
        setattr(place, field, value)
    db.commit()
    db.refresh(place)
    return place


@router.delete("/{place_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_place(
    place: Place = Depends(get_owned_place),
    db: Session = Depends(get_db),
):
    db.delete(place)
    db.commit()


@router.post("/{place_id}/notes", response_model=NoteOut, status_code=status.HTTP_201_CREATED)
def create_note(
    payload: NoteCreate,
    place: Place = Depends(get_owned_place),
    db: Session = Depends(get_db),
):
    note = PlaceNote(place_id=place.id, user_id=place.user_id, **payload.model_dump())
    db.add(note)
    db.commit()
    db.refresh(note)
    return note

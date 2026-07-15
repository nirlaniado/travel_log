from datetime import date, datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field, field_validator

from .models import PlaceStatus

# ---------- Auth ----------


class RegisterRequest(BaseModel):
    username: str = Field(min_length=3, max_length=50, pattern=r"^[a-zA-Z0-9_.-]+$")
    password: str = Field(min_length=8, max_length=128)


class LoginRequest(BaseModel):
    username: str = Field(min_length=1, max_length=50)
    password: str = Field(min_length=1, max_length=128)


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    username: str
    created_at: datetime


# ---------- Places ----------


class PlaceBase(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    country: str = Field(min_length=1, max_length=80)
    city: str | None = Field(default=None, max_length=80)
    latitude: Decimal | None = Field(default=None, ge=-90, le=90)
    longitude: Decimal | None = Field(default=None, ge=-180, le=180)
    status: PlaceStatus
    rating: int | None = Field(default=None, ge=1, le=5)
    visited_at: date | None = None

    @field_validator("name", "country", "city")
    @classmethod
    def strip_text(cls, v: str | None) -> str | None:
        if v is None:
            return v
        v = v.strip()
        if not v:
            raise ValueError("must not be blank")
        return v


class PlaceCreate(PlaceBase):
    pass


class PlaceUpdate(PlaceBase):
    pass


class NoteOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    place_id: int
    title: str
    content: str
    created_at: datetime
    updated_at: datetime


class PlaceOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    country: str
    city: str | None
    latitude: Decimal | None
    longitude: Decimal | None
    status: PlaceStatus
    rating: int | None
    visited_at: date | None
    created_at: datetime
    updated_at: datetime


class PlaceDetailOut(PlaceOut):
    notes: list[NoteOut]


# ---------- Notes ----------


class NoteCreate(BaseModel):
    title: str = Field(min_length=1, max_length=120)
    content: str = Field(min_length=1, max_length=10_000)

    @field_validator("title", "content")
    @classmethod
    def strip_text(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("must not be blank")
        return v


class NoteUpdate(NoteCreate):
    pass


class MessageOut(BaseModel):
    message: str

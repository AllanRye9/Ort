from pydantic import BaseModel, Field, validator
from typing import Optional
import re
from datetime import datetime


class BookBase(BaseModel):
    Original_title: str
    Author: str
    Language: str
    Subject: Optional[str] = None
    Genre: Optional[str] = None
    Publisher: str
    Publication_date: str
    Publication_place: str
    Pages: Optional[int] = None
    Description: Optional[str] = None


class BookCreate(BookBase):
    Original_title: str = Field(..., min_length=2, max_length=255)
    Author: str = Field(..., min_length=2, max_length=255)
    Language: str = Field(..., min_length=2, max_length=100)
    Subject: Optional[str] = Field(None, max_length=255)
    Genre: Optional[str] = Field(None, max_length=100)
    Publisher: str = Field(..., max_length=255)
    Publication_date: str = Field(..., description="Must be DD-MM-YYYY")
    Publication_place: str = Field(..., max_length=255)
    Pages: Optional[int] = Field(None, ge=1)  # must be positive if provided
    Description: Optional[str] = Field(None, max_length=5000)

    # ---------------- Validators ---------------- #

    @validator(
        "Original_title",
        "Author",
        "Language",
        "Publisher",
        "Publication_place",
        pre=True
    )
    def no_blank_text(cls, value):
        if not value or not value.strip():
            raise ValueError("Field cannot be blank or spaces only")
        return value.strip()

    @validator("Publication_date")
    def validate_date(cls, value):
        try:
            datetime.strptime(value, "%d-%m-%Y")
        except ValueError:
            raise ValueError("Publication_date must be in DD-MM-YYYY format")
        return value

    @validator("Language")
    def validate_language(cls, value):
        if not re.match(r"^[A-Za-z\s\-]+$", value):
            raise ValueError("Language must contain only letters")
        return value

    @validator("Pages")
    def pages_must_be_positive(cls, value):
        if value is not None and value <= 0:
            raise ValueError("Pages must be greater than 0")
        return value


class ResponseBook(BookBase):
    id: int

    class Config:
        orm_mode = True

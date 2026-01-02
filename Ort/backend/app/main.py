from fastapi import FastAPI, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List

from .database.database import local_session, engine, Base
from .models.models import Books
from .schemas.schemas import BookCreate, ResponseBook

app = FastAPI()

# Create tables
Base.metadata.drop_all(bind=engine)
Base.metadata.create_all(bind=engine)


# DB Dependency
def db_connect():
    db = local_session()
    try:
        yield db
    finally:
        db.close()


@app.get("/")
def home():
    return {"message": "Welcome to the Book API"}


@app.get("/books/", response_model=List[ResponseBook])
def get_books(db: Session = Depends(db_connect)):
    return db.query(Books).all()


@app.get("/books/{book_id}", response_model=ResponseBook)
def get_book(book_id: int, db: Session = Depends(db_connect)):
    book = db.query(Books).filter(Books.id == book_id).first()
    if not book:
        raise HTTPException(status_code=404, detail="Book not found")
    return book


@app.post("/books/", response_model=ResponseBook, status_code=201)
def create_book(book: BookCreate, db: Session = Depends(db_connect)):
    new_book = Books(
        Original_title=book.Original_title,
        Author=book.Author,
        Description=book.Description,
        Language=book.Language,
        Subject=book.Subject,
        Genre=book.Genre,
        Publisher=book.Publisher,
        Publication_date=book.Publication_date,
        Publication_place=book.Publication_place,
        Pages=book.Pages
    )
    db.add(new_book)
    db.commit()
    db.refresh(new_book)
    return new_book


@app.put("/books/{book_id}", response_model=ResponseBook)
def update_book(book_id: int, updated_book: BookCreate, db: Session = Depends(db_connect)):
    book = db.query(Books).filter(Books.id == book_id).first()
    if not book:
        raise HTTPException(status_code=404, detail="Book not found")

    book.Original_title = updated_book.Original_title
    book.Author = updated_book.Author
    book.Description = updated_book.Description
    book.Language = updated_book.Language
    book.Subject = updated_book.Subject
    book.Genre = updated_book.Genre
    book.Publisher = updated_book.Publisher
    book.Publication_date = updated_book.Publication_date
    book.Publication_place = updated_book.Publication_place
    book.Pages = updated_book.Pages


    db.commit()
    db.refresh(book)
    return book


@app.delete("/books/{book_id}", status_code=200)
def delete_book(book_id: int, db: Session = Depends(db_connect)):
    book = db.query(Books).filter(Books.id == book_id).first()
    if not book:
        raise HTTPException(status_code=404, detail="Book not found")

    db.delete(book)
    db.commit()
    return {"message": "Book deleted successfully"}

from sqlalchemy import Column, Integer, String
from ..database.database import Base

class Books(Base):
    __tablename__ = "books"
    id = Column(Integer, primary_key=True, index=True)
    Original_title = Column(String(255), nullable=False)
    Author = Column(String(255), nullable=False)
    Language = Column(String(100), nullable=False)
    Subject = Column(String(255))
    Genre = Column(String(100))
    Publisher = Column(String(255), nullable=False)
    Publication_date = Column(String(100), nullable=False)
    Publication_place = Column(String(255), nullable=False)
    Pages = Column(Integer, nullable=True)
    Description = Column(String)


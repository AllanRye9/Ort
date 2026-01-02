from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

DB_URL = 'sqlite:///./books.db'

engine = create_engine(DB_URL, connect_args={"check_same_thread": False})

local_session = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

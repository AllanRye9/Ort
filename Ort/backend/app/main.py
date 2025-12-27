from .core.config import config
from .core.security import security
from .models.models import create_tables
from .api.v1.api import app, home

def main():
    config()
    security()
    create_tables()
    home()

if __name__ == "__main__":
 main()
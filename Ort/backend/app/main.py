from .core.config import config
from .core.security import security
from .models.models import create_tables
# from .models.seed import seed_data

def main():
    config()
    security()
    create_tables()

if __name__ == "__main__":
 main()
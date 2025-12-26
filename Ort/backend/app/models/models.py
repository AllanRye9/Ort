from sqlalchemy import create_engine, and_
from sqlalchemy import Table, Column, Integer, String, Boolean, DateTime, Enum, JSON, Float, Text, MetaData
import sqlalchemy
from sqlalchemy.sql import text, select, func
from sqlalchemy import ForeignKey

DATABASE_URL = 'sqlite:///database.db'
engine = create_engine(DATABASE_URL, echo=True)

""" sqlalchemy can be can be connected to any database like sqlite, mysql, postgresql etc. through its database api 
    dialect[+driver]://user:password@host/dbname like mysql://user:pwd@localhost/college
"""

meta = MetaData()

users = Table(
    "users", meta,

    Column('id', Integer, primary_key=True),
    Column('name', String),
    Column('age', Integer),
    Column('salary', Float),
    Column('company', String)

)

addresses = Table(
    "addresses", meta,
    Column('add_id', Integer, primary_key=True),
    Column('user_id', Integer),
    Column('location', String),
    Column('zone', String),
)


def create_tables():

    meta.create_all(engine)

    conn = engine.connect()

    # single value insertion using the value method
    # exec_values = users.insert().values(name="Reagan", age=29, salary=140000)

    # many insertion method using dictionary
    conn.execute(addresses.insert(),
        [
            {'user_id': 1, 'location':'Kampala', 'zone':'Central'},
            {'user_id': 2, 'location':'Gulu', 'zone':'Northern'},
            {'user_id': 3, 'location':'Lira', 'zone':'Northern'},
            {'user_id': 4, 'location':'Arua', 'zone':'Northern'},
            {'user_id': 5, 'location':'Jinja', 'zone':'Eastern'},
            {'user_id': 6, 'location':'Mbale', 'zone':'Eastern'}
        ]
    )
    # exec_sql = users.insert().values(name='Opio', age=29, salary=119000.343, company='ADCB')
    conn.execute(users.insert(),
        [
            {'name':'okello', 'age':23, 'salary':43000, 'company':'Labwolo limited'},
            {'name':'odule', 'age':19, 'salary':8388000, 'company':'oliyoilong'},
            {'name':'ojok', 'age':42, 'salary':2323424, 'company':'pece vanguard'},
            {'name':'ojara', 'age':16, 'salary':10900, 'company':'tic tekkom'},
            {'name':'komakech', 'age':18, 'salary':50000, 'company':'boloka limited'},
            {'name':'opit', 'age':37, 'salary':23434555, 'company':'labang kwon vidi limited'}
        ]
    )

    # conn.execute(users.update().where(users.c.age < 18).values(company='Young boys association'))
    # # conn.execute(users.delete().where(and_(users.c.age < 18, users.c.salary < 15000)))
    # select_query = users.select().where(users.c.age < 88)
    # res = conn.execute(select_query).all()
    # fd = conn.execute(addresses.select().where(addresses.c.add_id > 1)).all()
    # print(fd)

    fkd = ( select(users, addresses).select_from(users.join(addresses, users.c.id == addresses.c.user_id)))
    conn.execute(users.update().values({'company':'Updated company ltd'}).where(users.c.id == 2))
    res  = conn.execute(fkd).fetchall()
    for i in res:
     print(i)
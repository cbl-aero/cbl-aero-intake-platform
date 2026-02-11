import asyncpg
from app.settings import settings


class Db:
    def __init__(self) -> None:
        self.pool: asyncpg.Pool | None = None

    async def start(self) -> None:
        self.pool = await asyncpg.create_pool(
            dsn=settings.DATABASE_URL,
            min_size=1,
            max_size=10,
        )

    async def stop(self) -> None:
        if self.pool:
            await self.pool.close()
            self.pool = None

    async def fetchval(self, sql: str, *args):
        if not self.pool:
            raise RuntimeError("DB not started")
        async with self.pool.acquire() as conn:
            return await conn.fetchval(sql, *args)

    async def execute(self, sql: str, *args):
        if not self.pool:
            raise RuntimeError("DB not started")
        async with self.pool.acquire() as conn:
            return await conn.execute(sql, *args)

    async def fetch(self, sql: str, *args):
        if not self.pool:
            raise RuntimeError("DB not started")
        async with self.pool.acquire() as conn:
            return await conn.fetch(sql, *args)


db = Db()

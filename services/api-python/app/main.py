import tomllib
from pathlib import Path

from fastapi import FastAPI

VERSION = tomllib.loads(
    (Path(__file__).resolve().parent.parent / "pyproject.toml").read_text()
)["project"]["version"]

app = FastAPI()


@app.get("/version")
def get_version() -> dict[str, str]:
    return {"version": VERSION}

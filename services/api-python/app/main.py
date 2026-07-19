from fastapi import FastAPI

VERSION = "0.1.0"

app = FastAPI()


@app.get("/version")
def get_version() -> dict[str, str]:
    return {"version": VERSION}

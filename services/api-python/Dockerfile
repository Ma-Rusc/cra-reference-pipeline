FROM ghcr.io/astral-sh/uv:0.11.29@sha256:eb2843a1e56fd9e30c7276ce1a52cba86e64c7b385f5e3279a0e08e02dd058fc AS uv

FROM python:3.12-slim@sha256:7a8b475003c4fe15a2cd4e55e5cfc2f3560bdc9333d624f24cdd6d4340fd7a17
COPY --from=uv /uv /uvx /usr/local/bin/

# uv verwaltet die Anwendungsabhängigkeiten, das system-weite pip aus dem
# Basisimage wird zur Laufzeit nie aufgerufen. Trotzdem gepinnt aktualisiert
# (nicht --upgrade) statt per VEX weggewertet, da ein Fix existiert
# (GHSA-wf93-45jw-7689 u. a., siehe vex/README.md).
RUN pip install --no-cache-dir --break-system-packages "pip==26.1.2"

RUN useradd --create-home --uid 1000 appuser
WORKDIR /app

COPY pyproject.toml uv.lock ./
RUN uv sync --locked --no-dev

COPY app ./app

USER appuser
EXPOSE 8000
CMD ["uv", "run", "--no-dev", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]

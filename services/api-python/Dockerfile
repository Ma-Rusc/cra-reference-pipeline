FROM cgr.dev/chainguard/python:latest-dev AS builder
WORKDIR /app
COPY pyproject.toml uv.lock ./
RUN pip install uv && uv sync --locked --no-dev
COPY app ./app
RUN SITE=$(python3 -c "import glob; print(glob.glob('/app/.venv/lib/python3.*/site-packages')[0])") && \
    cp -r "$SITE" /app/site-packages

FROM cgr.dev/chainguard/python:latest
WORKDIR /app
COPY --from=builder /app/app ./app
COPY --from=builder /app/site-packages /app/site-packages
ENV PYTHONPATH=/app/site-packages
EXPOSE 8000
ENTRYPOINT ["python", "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]

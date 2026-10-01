FROM python:3.12-slim
WORKDIR /app
COPY pyproject.toml ./
COPY src ./src
RUN pip install --no-cache-dir . && useradd --uid 10001 --create-home sam
COPY alembic.ini ./
COPY migrations ./migrations
USER sam
EXPOSE 8000
CMD ["uvicorn", "sam.api:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1", "--no-access-log"]

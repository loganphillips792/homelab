# The only built image in this repo — every other service uses a prebuilt tag.
# That means `git pull && docker compose up -d` will NOT pick up changes to
# consumer.py; you need --build. See ../../README.md under "## Kafka Testing Stack".
FROM python:3.12-slim

# Unbuffered so `docker logs -f kafka-consumer` and Dozzle show output as it
# happens instead of holding it in a 4 KB pipe buffer.
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

WORKDIR /app

# Copied before the source so image rebuilds after a code edit reuse the pip layer.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY consumer.py .

# Nothing here needs root.
RUN useradd --create-home --uid 10001 consumer
USER consumer

CMD ["python", "consumer.py"]

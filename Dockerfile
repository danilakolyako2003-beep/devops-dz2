# syntax=docker/dockerfile:1
FROM python:3.12-alpine AS builder
RUN apk add --no-cache build-base postgresql-dev mariadb-connector-c-dev pkgconf
WORKDIR /build
COPY requirements.txt .
RUN pip wheel --no-cache-dir --wheel-dir /wheels -r requirements.txt

FROM python:3.12-alpine
RUN apk add --no-cache libpq mariadb-connector-c
WORKDIR /app
COPY requirements.txt .
RUN --mount=type=bind,from=builder,source=/wheels,target=/wheels \
    pip install --no-cache-dir --no-index --find-links=/wheels -r requirements.txt
COPY app.py .
ARG VERSION=5.0
RUN printf '%s\n' "$VERSION" > /app/VERSION
ENV PYTHONDONTWRITEBYTECODE=1
STOPSIGNAL SIGINT
CMD ["python", "app.py"]

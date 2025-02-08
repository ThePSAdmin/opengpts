FROM node:20 AS builder

WORKDIR /frontend

COPY ./frontend/package.json ./frontend/yarn.lock ./

RUN yarn --network-timeout 600000 --frozen-lockfile

COPY ./frontend ./

RUN rm -rf .env

RUN yarn build

# Backend Dockerfile
FROM python:3.11

ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT

# Install system dependencies
RUN apt-get update && rm -rf /var/lib/apt/lists/*
RUN wget -O golang-migrate.deb https://github.com/golang-migrate/migrate/releases/download/v4.17.0/migrate.${TARGETOS}-${TARGETARCH}${TARGETVARIANT}.deb \
    && dpkg -i golang-migrate.deb \
    && rm golang-migrate.deb

# Install Poetry
# RUN pip install poetry
ADD https://astral.sh/uv/0.5.29/install.sh /uv-installer.sh
RUN sh /uv-installer.sh && rm /uv-installer.sh
ENV PATH="/root/.local/bin/:$PATH"
ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy

# Set the working directory
WORKDIR /backend

# Copy only dependencies
COPY ./backend/pyproject.toml ./backend/uv.lock ./

# Install dependencies
# --only main: Skip installing packages listed in the [tool.poetry.dev-dependencies] section
# RUN poetry config virtualenvs.create false \
#     && poetry install --no-interaction --no-ansi --only main
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-install-project --no-dev

# Copy the rest of backend
COPY ./backend .
RUN --mount=type=cache,target=/root/.cache/uv \
  uv sync --frozen --no-dev

# Copy the frontend build
COPY --from=builder /frontend/dist ./ui

ENV PATH="/backend/.venv/bin:$PATH"

ENTRYPOINT [ "uvicorn", "app.server:app", "--host", "0.0.0.0", "--log-config", "log_config.json" ]

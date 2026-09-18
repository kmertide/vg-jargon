FROM python:3.12-slim

RUN apt-get update && apt-get install -y --no-install-recommends git \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir aider-chat

RUN useradd -m aider
USER aider
RUN git config --global user.email "aider-sandbox@local" \
    && git config --global user.name "Aider Sandbox" \
    && git config --global --add safe.directory /workspace
WORKDIR /workspace

ENTRYPOINT ["aider"]

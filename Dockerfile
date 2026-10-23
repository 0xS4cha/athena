FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    SDL_VIDEODRIVER=dummy \
    SDL_AUDIODRIVER=dummy

RUN apt-get update \
    && apt-get install -y --no-install-recommends love \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --create-home --shell /usr/sbin/nologin athena

WORKDIR /app

COPY server/ ./
COPY src/core/ ./src/core/
COPY libs/ ./libs/

USER athena

ENV PORT=6789 \
    MAX_PEERS=64

EXPOSE 6789/udp

CMD ["sh", "-c", "exec love /app --port \"$PORT\" --peers \"$MAX_PEERS\""]

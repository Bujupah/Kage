# Kage dedicated region server: headless Godot running the authoritative simulation over ENet (UDP).
# The server loads no art (AssetKit/WorldKit build colliders only when headless), so the image
# carries code, data and the model-bounds manifest: see .dockerignore.
#
#   docker build -t kage-server .
#   docker run --rm -p 7777:7777/udp kage-server
#   docker run --rm -p 7777:7777/udp kage-server --server --port=7777 --max-players=32

ARG GODOT_VERSION=4.7.2

FROM debian:bookworm-slim AS godot
ARG GODOT_VERSION
RUN apt-get update \
	&& apt-get install -y --no-install-recommends ca-certificates curl unzip \
	&& rm -rf /var/lib/apt/lists/*
RUN curl -fsSL -o /tmp/godot.zip \
		"https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" \
	&& unzip -q /tmp/godot.zip -d /tmp/godot \
	&& install -m 0755 "/tmp/godot/Godot_v${GODOT_VERSION}-stable_linux.x86_64" /usr/local/bin/godot \
	&& rm -rf /tmp/godot /tmp/godot.zip

# Import once at build time so the container starts instantly (.godot/ cache baked in).
FROM godot AS project
WORKDIR /srv/kage
COPY . .
RUN godot --headless --path . --import >/tmp/import.log 2>&1; \
	if grep -q "SCRIPT ERROR" /tmp/import.log; then cat /tmp/import.log; exit 1; fi

FROM debian:bookworm-slim
# tini as PID 1 forwards SIGTERM, so `docker stop` and redeploys shut the server down promptly.
RUN apt-get update \
	&& apt-get install -y --no-install-recommends tini \
	&& rm -rf /var/lib/apt/lists/* \
	&& useradd --system --create-home --home-dir /home/kage kage
COPY --from=godot /usr/local/bin/godot /usr/local/bin/godot
COPY --from=project --chown=kage:kage /srv/kage /srv/kage
USER kage
ENV HOME=/home/kage
EXPOSE 7777/udp
STOPSIGNAL SIGTERM
ENTRYPOINT ["/usr/bin/tini", "--", "godot", "--headless", "--path", "/srv/kage", "--"]
CMD ["--server", "--port=7777", "--max-players=16"]

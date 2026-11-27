# Single platform build (local testing)
build:
	docker build --build-arg PHP_VERSION=8.4 -t ghcr.io/drlogout/statadock:8.4 .
	docker tag ghcr.io/drlogout/statadock:8.4 ghcr.io/drlogout/statadock:latest

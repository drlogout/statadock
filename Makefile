# Single platform build (local testing)
build:
	docker build --build-arg PHP_VERSION=8.3 -t ghcr.io/drlogout/statadock:8.3 .
	docker tag ghcr.io/drlogout/statadock:8.3 ghcr.io/drlogout/statadock:latest

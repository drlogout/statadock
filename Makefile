# Single platform build (local testing)
build:
	docker build --build-arg PHP_VERSION=8.3 -t drlogout/statadock:8.3 .
	docker tag drlogout/statadock:8.3 drlogout/statadock:latest

.PHONY: build

build:
	docker build --build-arg PHP_VERSION=8.2 -t drlogout/statadock:8.2 .
	docker build --build-arg PHP_VERSION=8.3 -t drlogout/statadock:8.3 .
	docker tag drlogout/statadock:8.3 drlogout/statadock:latest

push:
	docker push drlogout/statadock:8.2
	docker push drlogout/statadock:8.3
	docker push drlogout/statadock:latest

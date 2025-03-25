
build:
	#docker build --platform linux/x86_64 --build-arg PHP_VERSION=8.1 --tag drlogout/statadock:8.1 .
	docker build --build-arg PHP_VERSION=8.2 --tag drlogout/statadock:8.2 .

push:
	#docker push drlogout/statadock:8.1
	docker push drlogout/statadock:8.2

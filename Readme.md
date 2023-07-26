# statadock

This image should contain everything needed to run a Statamic site (WIP).

## Building the images

```bash
make
```

## Runing the container

```bash
docker run -v $(pwd)/site:/var/www/html -p '8888:80' --name statadock -d drlogout/statadock:8.1
```
Go to http://localhost:8888

## Running the statamic cli

```bash
docker exec -it statadock statamic
``` 

## Installing statamic into the mounted volume

```bash
docker exec -it statadock install-statamic coke
``` 


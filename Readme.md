# statadock

statadock is a docker image that contains everything needed to run a Statamic site.

## Usage

### Reverse Proxy Support

The container can be configured to run behind a reverse proxy (like Traefik, Nginx, or Cloudflare) by setting `REVERSE_PROXY=true`. This:
- Properly handles forwarded HTTPS requests
- Respects X-Forwarded-* headers
- Ensures correct SSL/HTTPS detection in your application

```yml
services:
  statadock:
    image: drlogout/statadock:8.2
    ports:
      - "8888:80"
    volumes:
      - ./site:/var/www/html
      - ./.ssh:/var/www/.ssh  # Mount SSH keys for private repository access
    environment:
      - REVERSE_PROXY=false # Set to true if behind a reverse proxy
      - NODE_VERSION=22.12  # (default: 22.14) Node.js version

      # Deploy
      - SITE_BRANCH=main # Git pull is only run if a key is found in /var/www/.ssh

      # Optional
      - RESTART_REVERB=false    # Set to true to restart Laravel Reverb
      - UPDATE_STATIC_CACHE=true # Set to true to rebuild static cache
      - UPDATE_SEARCH=true      # Set to true to update search indices
    restart: unless-stopped
```

### Permissions

Both the `./site` directory and the `./.ssh` directory are mounted as volumes and must be owned by the `www-data` user (uid 33, gid 33).

## Running with Docker **Compose**

```bash
docker compose up -d
```
Go to http://localhost:8888



## Deploy

The deploy script performs the following operations:

1. **Repository Update**
   - If SSH keys are found in `/var/www/.ssh`, pulls latest changes from the specified `SITE_BRANCH`

2. **Dependencies & Build**
   - Installs PHP dependencies with `composer install`
   - Installs and builds frontend with npm using specified `NODE_VERSION`

3. **System Updates**
   - Restarts PHP-FPM
   - Ensures valid APP_KEY exists
   - Clears and rebuilds Laravel caches (config, route)
   - Manages Horizon workers

4. **Optional Statamic Operations** (controlled by environment variables)
   - Restarts Reverb (`RESTART_REVERB=true`)
   - Rebuilds static cache (`UPDATE_STATIC_CACHE=true`)
   - Updates search indices (`UPDATE_SEARCH=true`)

To run deploy:
```bash
docker compose exec statadock deploy
```

## Running the statamic cli

```bash
docker compose exec statadock statamic
```

## Installing statamic into an empty mounted volume

The installation script creates a new Statamic site in the mounted volume.

Basic installation:
```bash
docker compose exec statadock install-statamic <APP_NAME>
```

Install with a starter kit:
```bash
docker compose exec statadock install-statamic <APP_NAME> <STARTER_KIT>
```

**Note:** The installation will fail if the mounted directory is not empty. Make sure your `./site` directory is empty before running the install command.

## Installing Peak starter kit

[Peak](https://github.com/studio1902/statamic-peak) is a popular opinionated starter kit for Statamic that comes with a lot of best practices built-in. To install Statamic with Peak:

```bash
docker compose exec statadock install-peak <APP_NAME>
```

This is equivalent to running `install-statamic <APP_NAME> studio1902/statamic-peak` but provides a convenient shortcut.

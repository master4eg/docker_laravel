# Laravel Docker Starter

Local Docker environment for fast Laravel onboarding with PHP-FPM 8.3, Nginx, MySQL 8, and MailHog managed through a Makefile workflow.

## Stack
- php: php:8.3-fpm-alpine with Composer, GD, Intl, Mbstring, Zip, Opcache, and other common extensions.
- nginx: serves the public directory and forwards PHP requests to php-fpm.
- mysql: MySQL 8 with utf8mb4 defaults and an init script that creates the laravel database.
- mailhog: lightweight SMTP catcher with a browser UI.

## Prerequisites
- Docker with the Compose v2 plugin available as "docker compose".
- GNU Make (on macOS install via "brew install make" and run targets with "gmake").
- Linux, macOS, or Windows (WSL2 recommended on Windows).

## Quick Start
1. Bring the containers up (images are built automatically): make up.
2. Initialize Laravel (downloads scaffolding on the first run, skips on subsequent runs): make init.
3. Open http://localhost:8080 to verify the app is reachable.
4. Database is exposed on localhost:33060 (user root, empty password, database laravel).
5. MailHog UI is available on http://localhost:8025 after make mail-up.

## Common Make Targets
- make up: build and start the stack in detached mode.
- make down: stop containers and remove volumes.
- make restart: rebuild and restart everything.
- make logs / make ps: tail logs or show container status.
- make sh: interactive bash shell inside the php container as www-data.
- make artisan CMD="migrate": run Laravel Artisan commands within the container.
- make composer CMD="require vendor/package": run Composer inside the container.
- make fresh: run php artisan migrate:fresh --seed.
- make mail-up / make mail-down / make mail-logs: manage the MailHog service.
- make archive: create a trimmed project archive without vendor or node_modules.
- make archive-full: create a full archive with all dependencies.

## Repository Layout
- src/: Laravel application sources. The .gitkeep placeholder keeps the directory committed before the first init run.
- .env.docker: environment variables for Docker Compose (ports, host names, UID, GID).
- docker/: service configuration for nginx, php, and mysql.
- Makefile: entry point for managing the environment and developer workflow.

## Helpful Scenarios
- Install a Composer package: make composer CMD="require spatie/laravel-permission".
- Run database migrations: make artisan CMD="migrate".
- Clear caches: make artisan CMD="optimize:clear".
- Fix permissions after manual file edits: make perms.

## Notes
- Adjust service ports in docker-compose.yml or override values in .env.docker as needed.
- Named volumes (db_data, composer_cache) persist database records and the Composer cache across restarts.
- Consider adding an opt-in Xdebug profile to docker-compose.yml if you need step debugging.

Happy coding!

# Определяем UID/GID текущего пользователя (важно для прав в WSL2)
UID := $(shell id -u)
GID := $(shell id -g)
export PUID := $(UID)
export PGID := $(GID)

DC := PUID=$(PUID) PGID=$(PGID) docker compose --env-file .env.docker

.PHONY: up down build restart logs ps sh init artisan composer key perms fresh archive archive-full

up:
	$(DC) up -d --build

down:
	$(DC) down -v

build:
	$(DC) build --no-cache

restart:
	$(DC) down && $(DC) up -d --build

logs:
	$(DC) logs -f --tail=200

ps:
	$(DC) ps

sh:
	@$(DC) exec -it -u www-data php bash || $(DC) run --rm -it -u www-data php bash || true

# Инициализация проекта: создаст Laravel если нет, настроит .env, ключ и права
init: up
	@# Если уже есть artisan — просто ключ/права и выходим
	@if [ -f artisan ]; then \
		$(MAKE) key; \
		$(MAKE) perms; \
		echo "✅ Laravel уже установлен. Обновил ключ и права. Открой: http://localhost:8080"; \
		exit 0; \
	fi

	@echo "➡️  Скачиваю Laravel во временную папку (без пост-скриптов) и копирую в проект…"
	@$(DC) run --rm -u www-data php bash -lc '\
		set -euo pipefail; \
		TMP=$$(mktemp -d); \
		composer create-project --no-interaction --no-scripts laravel/laravel $$TMP; \
		shopt -s dotglob; \
		cp -a $$TMP/* /var/www/html/; \
		rm -rf $$TMP; \
		cd /var/www/html; \
		composer install --no-interaction; \
	'

	@cp -n .env.example .env || true
	$(MAKE) key
	$(MAKE) perms
	@echo "✅ Laravel готов: http://localhost:8080"



key:
	@if [ -f artisan ]; then $(DC) exec -u www-data php php artisan key:generate --force; fi

perms:
	@mkdir -p storage
	@mkdir -p bootstrap/cache
	@$(DC) exec -u root php bash -lc "chown -R www-data:www-data /var/www/html && find storage -type d -exec chmod 775 {} \; && find storage -type f -exec chmod 664 {} \; && chmod -R 775 bootstrap/cache"

artisan:
	@if [ -f artisan ]; then $(DC) exec -u www-data php php artisan $(CMD); else echo "❌ Нет Laravel (artisan). Запусти: make init"; fi

composer:
	$(DC) run --rm -u www-data php bash -lc "composer $(CMD)"

fresh:
	$(MAKE) artisan CMD="migrate:fresh --seed"

# ==== Packaging ====

# Имя проекта = имя текущей папки
PROJECT_NAME := $(notdir $(CURDIR))
DATE := $(shell date +%Y%m%d-%H%M%S)
GIT_SHA := $(shell git rev-parse --short HEAD 2>/dev/null || echo nogit)
DIST_DIR := .dist

# Базовое имя архива
ARCHIVE_BASENAME := $(PROJECT_NAME)-$(DATE)-$(GIT_SHA)
ARCHIVE := $(DIST_DIR)/$(ARCHIVE_BASENAME).tar.gz

# Что исключаем из "легкого" архива
TAR_EXCLUDES := \
	--exclude-vcs \
	--exclude=".git" \
	--exclude=".idea" \
	--exclude=".DS_Store" \
	--exclude="node_modules" \
	--exclude="vendor" \
	--exclude="storage/logs/*" \
	--exclude="storage/framework/cache/*" \
	--exclude="storage/framework/sessions/*" \
	--exclude="storage/framework/views/*" \
	--exclude=".env.docker"

# Лёгкий архив для заливки на хостинг (потом сделаете composer install на сервере)
archive:
	@mkdir -p $(DIST_DIR)
	@tar -czf $(ARCHIVE) $(TAR_EXCLUDES) \
		--transform 's,^,$(PROJECT_NAME)/,' \
		.
	@echo "✅ Сформирован архив: $(ARCHIVE)"
	@ls -lh $(ARCHIVE)

# Полный архив со всеми зависимостями (может быть большим)
archive-full:
	@mkdir -p $(DIST_DIR)
	@tar -czf $(ARCHIVE) \
		--exclude-vcs \
		--exclude=".git" \
		--exclude=".idea" \
		--exclude=".DS_Store" \
		--transform 's,^,$(PROJECT_NAME)/,' \
		.
	@echo "✅ Сформирован ПОЛНЫЙ архив: $(ARCHIVE)"
	@ls -lh $(ARCHIVE)


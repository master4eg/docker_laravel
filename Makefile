.DEFAULT_GOAL := help
MAKEFLAGS += --no-print-directory

# Определяем UID/GID текущего пользователя (важно для прав в WSL2)
UID := $(shell id -u)
GID := $(shell id -g)
export PUID := $(UID)
export PGID := $(GID)

DC := PUID=$(PUID) PGID=$(PGID) docker compose --env-file .env.docker

.PHONY: up down build restart logs ps sh init artisan composer key perms fresh \
        archive archive-full mail-up mail-down mail-logs help quickstart

# ==== Help (самодокументация) ====
help: ## Показать список команд и краткое описание
	@awk 'BEGIN {FS = ":.*##"; \
		printf "\n\033[1mUsage:\033[0m  make \033[36m<TARGET>\033[0m\n"; \
		printf "\n\033[1mTargets:\033[0m\n"} \
	/^[a-zA-Z0-9_.-]+:.*##/ { printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2 } \
	/^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0,5) } ' $(MAKEFILE_LIST)

##@ Core

up: ## Собрать и поднять все контейнеры (detached)
	$(DC) up -d --build

down: ## Остановить и удалить контейнеры + тома
	$(DC) down -v

build: ## Пересобрать образ(ы) без кеша
	$(DC) build --no-cache

restart: ## Перезапустить все контейнеры (с пересборкой)
	$(DC) down && $(DC) up -d --build

logs: ## Хвост логов всех сервисов (follow)
	$(DC) logs -f --tail=200

ps: ## Показать статус контейнеров
	$(DC) ps

sh: ## Войти в контейнер php (www-data) с интерактивным bash
	@$(DC) exec -it -u www-data php bash || $(DC) run --rm -it -u www-data php bash || true

##@ Laravel

init: up ## Инициализация проекта: создать Laravel (если нет), .env, key, права
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
	@[ -f .env ] || cp .env.example .env
	$(MAKE) key
	$(MAKE) perms
	@echo "✅ Laravel готов: http://localhost:8080"

key: ## Сгенерировать APP_KEY (если есть artisan)
	@if [ -f artisan ]; then $(DC) exec -u www-data php php artisan key:generate --force; fi

perms: ## Починить права storage и bootstrap/cache
	@mkdir -p storage
	@mkdir -p bootstrap/cache
	@$(DC) exec -u root php bash -lc "chown -R www-data:www-data /var/www/html && find storage -type d -exec chmod 775 {} \; && find storage -type f -exec chmod 664 {} \; && chmod -R 775 bootstrap/cache"

artisan: ## Выполнить php artisan <CMD> внутри контейнера (пример: make artisan CMD="migrate")
	@if [ -f artisan ]; then $(DC) exec -u www-data php php artisan $(CMD); else echo "❌ Нет Laravel (artisan). Запусти: make init"; fi

composer: ## Выполнить composer <CMD> в контейнере (пример: make composer CMD="require spatie/laravel-medialibrary:^11")
	$(DC) run --rm -u www-data php bash -lc "composer $(CMD)"

fresh: ## Полная пересборка БД: migrate:fresh --seed
	$(MAKE) artisan CMD="migrate:fresh --seed"

##@ Mail

mail-up: ## Поднять MailHog
	@$(DC) up -d mailhog

mail-down: ## Остановить MailHog
	@$(DC) stop mailhog

mail-logs: ## Логи MailHog
	@$(DC) logs -f --tail=200 mailhog

##@ Packaging

PROJECT_NAME := $(notdir $(CURDIR))
DATE := $(shell date +%Y%m%d-%H%M%S)
GIT_SHA := $(shell git rev-parse --short HEAD 2>/dev/null || echo nogit)
DIST_DIR := .dist

ARCHIVE_BASENAME := $(PROJECT_NAME)-$(DATE)-$(GIT_SHA)
ARCHIVE := $(DIST_DIR)/$(ARCHIVE_BASENAME).tar.gz

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

archive: ## Лёгкий архив без vendor (ставить зависимости на хостинге)
	@mkdir -p $(DIST_DIR)
	@tar -czf $(ARCHIVE) $(TAR_EXCLUDES) \
		--transform 's,^,$(PROJECT_NAME)/,' \
		.
	@echo "✅ Сформирован архив: $(ARCHIVE)"
	@ls -lh $(ARCHIVE)

archive-full: ## Полный архив со всеми зависимостями (включая vendor)
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

##@ Other

quickstart: ## Напоминание: порядок для старта нового проекта
	@echo "1) make up"
	@echo "2) make init"

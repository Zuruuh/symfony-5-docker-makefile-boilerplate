## ----------------------------
##
## BileMo

##
## -------
## Project
##
##

DOCKER_COMPOSE  = docker-compose

EXEC_PHP        = $(DOCKER_COMPOSE) exec -T php /entrypoint

SYMFONY         = $(EXEC_PHP) bin/console
COMPOSER        = $(EXEC_PHP) composer

build:
	$(DOCKER_COMPOSE) pull --parallel --quiet --ignore-pull-failures 2> /dev/null
	$(DOCKER_COMPOSE) build --pull

kill:
	$(DOCKER_COMPOSE) kill
	$(DOCKER_COMPOSE) down --volumes --remove-orphans

install: ## Install and start the project
install: .env.local build start keys db
#install: env .env.local build start db

reset: ## Stop and start a fresh install of the project
reset: kill install

start: ## Start the containers
	$(DOCKER_COMPOSE) up -d --remove-orphans --no-recreate

stop: ## Stop the containers
	$(DOCKER_COMPOSE) stop

clean: ## Stop the project and remove generated files
clean: kill
	rm -rf vendor

no-docker:
	$(eval DOCKER_COMPOSE := \#)
	$(eval EXEC_PHP := )

.PHONY: build kill install reset start stop clean no-docker

##
## -----
## Utils
## 
##

db: ## Setup local database and load fake data
db: .env.local vendor
	-$(SYMFONY) doctrine:database:drop --if-exists --force
	-$(SYMFONY) doctrine:database:create --if-not-exists
	$(SYMFONY) d:m:m --no-interaction --allow-no-migration
	$(SYMFONY) d:f:l --no-interaction --purge-with-truncate

migration: ## Create a new doctrine migration
migration: vendor
	$(SYMFONY) doctrine:migrations:diff

migrate: ## Migrates db to latest saved migration
migrate: vendor
	$(SYMFONY) doctrine:migration:migrate --no-interaction

db-update-schema: ## Creates a new migrations and runs it
db-update-schema: migration migrate

db-validate-schema: ## Validate the database schema
db-validate-schema: .env.local vendor
	$(SYMFONY) doctrine:schema:validate

composer.lock: composer.json
	$(COMPOSER) update

vendor: composer.lock
	$(COMPOSER) install

.env.local: .env
	@if [ -f .env.local ]; \
	then\
		echo '\033[1;41m/!\The .env file has changed. Please check your .env.local file (this message will not be displayed again)';\
		touch .env.local;\
		exit 1;\
	else\
		echo cp .env .env.local;\
		cp .env .env.local;\
	fi

env:
	@if [ -f .env.local ]; \
	then\
		echo '.env.local already exists.';\
	else\
		touch .env.local;\
		echo 'APP_ENV=dev' >> .env.local;\
		echo 'APP_SECRET=bed224227aa1bd358ebc5c3d12cceb56' >> .env.local;\
		echo 'DATABASE_URL="postgresql://symfony:symfony@database/app"' >> .env.local;\
	fi

keys: vendor start
	$(EXEC_PHP) bin/console lexik:jwt:generate-keypair --skip-if-exists

.PHONY: db migration migrate db-update-schema db-validate-schema env keys

## 
## -----
## Tests
## 
## 

test: ## Run all tests in the tests/ folder
test:
	$(EXEC_PHP) bin/phpunit

.PHONY: test


.DEFAULT_GOAL := help
help:
	@grep -E '(^[a-zA-Z_-]+:.*?##.*$$)|(^##)' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[32m%-30s\033[0m %s\n", $$1, $$2}' | sed -e 's/\[32m##/[33m/'

## ----------------------------

.PHONY: help
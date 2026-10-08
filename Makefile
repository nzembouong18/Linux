.DEFAULT_GOAL := help
SHELL := /bin/bash

help: ## Affiche cette aide
	@awk 'BEGIN{FS=":.*## "} /^[a-zA-Z_-]+:.*## /{printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

list: ## Liste les modules de la formation
	@bash ./lab list

validate: ## Teste TOUS les labos et démos (setup → check KO → solve → check OK → démo → reset)
	@bash scripts/validate.sh

validate-%: ## Teste un module : make validate-05
	@bash scripts/validate.sh $*

lint: ## shellcheck sur tous les scripts (locale UTF-8)
	@LC_ALL=C.UTF-8 shellcheck -x -S warning lab scripts/*.sh modules/*/*.sh modules/25-projet-final/solution/livrable/scripts/*.sh

links: ## Vérifie les liens relatifs des fichiers Markdown
	@bash scripts/check-links.sh

ci: lint links validate ## Enchaîne lint, liens et validation (comme la CI)

build: ## Construit l'image Docker du laboratoire
	docker compose build

up: ## Démarre le laboratoire (conteneur avec systemd)
	docker compose up -d --build

shell: ## Ouvre un shell dans le laboratoire (utilisateur student)
	docker compose exec -u student lab bash

down: ## Arrête et supprime le laboratoire (et ses données)
	docker compose down -v

clean: ## Supprime les labos locaux (~/labs)
	@rm -rf "$${LAB_ROOT:-$$HOME/labs}"; echo "~/labs supprimé"

.PHONY: help list validate lint links ci build up shell down clean

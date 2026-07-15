# Travel Logs — dev + verification targets
.PHONY: up down logs test lint build

# Run a level's verification: make verify-07 -> scripts/verify/level-07.sh
verify-%:
	bash scripts/verify/level-$*.sh

up:
	docker compose up -d --build

down:
	docker compose down

logs:
	docker compose logs -f

test:
	cd backend && .venv/bin/pytest -q

lint:
	pre-commit run --all-files

build:
	cd frontend && npm run build

run:
	uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

seed:
	python -m scripts.seed_db

docker-up:
	docker compose up -d --build

docker-down:
	docker compose down -v
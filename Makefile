# Training material. Invented bank.
# Shortcuts for macOS and Linux. make is not installed on Windows: run the commands of README.md directly.

VENV ?= .venv
PY := $(VENV)/bin/python

.PHONY: install run test bdd lint format playwright-install

install:
	python3 -m venv $(VENV)
	$(PY) -m pip install -r requirements-dev.txt

run:
	$(PY) -m uvicorn company_transfers.main:app --reload --port 8000

test:
	$(PY) -m pytest

bdd:
	$(PY) -m behave

lint:
	$(PY) -m ruff check .
	$(PY) -m ruff format --check .

format:
	$(PY) -m ruff format .
	$(PY) -m ruff check --fix .

playwright-install:
	$(PY) -m playwright install chromium

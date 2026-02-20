.PHONY: test test-fast test-integration

test:
	uv run pytest -v

test-fast:
	uv run pytest -v -m "not slow"

test-integration:
	uv run pytest -v -m "integration" --timeout=1800

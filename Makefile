.PHONY: test test-fast test-integration test-qemu

test:
	uv run pytest -v

test-fast:
	uv run pytest -v -m "not slow"

test-integration:
	uv run pytest -v -m "integration" --timeout=1800

test-qemu:
	uv run pytest -v -m "slow" --timeout=1800

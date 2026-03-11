.PHONY: build test lint fmt audit bench docker release clean check install

build:
	cargo build --all-targets

test:
	cargo test

lint:
	cargo fmt --check
	cargo clippy --all-targets -- -D warnings

fmt:
	cargo fmt

audit:
	cargo audit

bench:
	cargo bench --bench analysis_bench

docker:
	docker build -t shadowhare .

release:
	cargo build --release

clean:
	cargo clean

check: build test lint

install:
	cargo install --path .

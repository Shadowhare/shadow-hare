.PHONY: build test lint fmt audit release clean check install

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

release:
	cargo build --release

clean:
	cargo clean

check: build test lint

install:
	cargo install --path .

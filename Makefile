nix-build:
	nix-shell --pure --run "make build"

build: lib
	tl build

check:
	tl check teal/**/*.tl

ensure: build
	git diff --exit-code -- lua

test:
	./run_tests.sh

lib:
	make -C lua/fzy/

nix-ensure:
	nix-shell --pure --run "make ensure"

nix-test: nix-build
	nix-shell --pure --run "./run_tests.sh"

clean:
	rm -rf lua/azy/
	make -C lua/fzy/ clean

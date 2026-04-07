.PHONY: build emit test test-diff test-halmos docs serve-docs clean

build:
	lake build

emit: build
	lake exe michelinepack emit > sol-test/src/MichelsonSpec.sol

test: emit
	cd sol-test && forge test

test-diff: build
	cd sol-test && bash test/differential.sh

test-halmos:
	cd sol-test && source .venv/bin/activate && FOUNDRY_PROFILE=halmos halmos --function check_ --loop 40 --solver-timeout-assertion 60000 --forge-build-out out-halmos

docs:
	cd docbuild && lake build MichelinePack:docs

serve-docs: docs
	cd docbuild/.lake/build/doc && python3 -m http.server

clean:
	lake clean
	cd docbuild && lake clean

.PHONY: test

test:
	nvim --headless --noplugin -l tests/run_tests.lua

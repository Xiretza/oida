SHELLCHECK = shellcheck
SCFLAGS = -fgcc --exclude=SC2039 --exclude=SC1090 -s bash

SHELLTEST = shelltest

SCRIPTS = $(shell find . -type f -name '*.sh')

all: check unit

check: $(SCRIPTS)
	$(SHELLCHECK) $(SCFLAGS) $^

test: unit

unit:
	$(SHELLTEST) --execdir test/unit


.PHONY: check unit test

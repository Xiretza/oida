SHELLCHECK = shellcheck
SCFLAGS = -fgcc --exclude=SC2039 -s sh

SHELLTEST = shelltest

SCRIPTS = $(shell find . -type f -name '*.sh')

all: check unit

check: $(SCRIPTS)
	$(SHELLCHECK) $(SCFLAGS) $^

test: unit system

unit:
	$(SHELLTEST) --execdir test/unit


.PHONY: check unit test

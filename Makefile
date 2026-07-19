PREFIX  ?= $(HOME)/.local
BIN_DIR := $(PREFIX)/bin

ROOT          := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
PROVIDERS_DIR := $(ROOT)/providers

# Every target acts on all directories under providers/.
PROVIDER_LIST := $(notdir $(wildcard $(PROVIDERS_DIR)/*))

.PHONY: setup uninstall list

# Interactive wizard: checkbox provider picker, per-provider API token
# prompts (Enter keeps the current token), launcher install, PATH checks.
setup:
	@BIN_DIR="$(BIN_DIR)" "$(ROOT)/bin/setup.sh"

uninstall:
	@for p in $(PROVIDER_LIST); do \
		dir="$(PROVIDERS_DIR)/$$p"; \
		[ -f "$$dir/.env.example" ] || continue; \
		cmd=$$(. "$$dir/.env.example"; printf '%s' "$$COMMAND"); \
		rm -f "$(BIN_DIR)/$$cmd" && echo "  Removed $(BIN_DIR)/$$cmd"; \
	done
	@echo "  Note: provider .env files are left in place. Delete them manually if no longer needed."

list:
	@for p in $(PROVIDER_LIST); do \
		dir="$(PROVIDERS_DIR)/$$p"; \
		[ -f "$$dir/.env.example" ] || continue; \
		cmd=$$(. "$$dir/.env.example"; printf '%s' "$$COMMAND"); \
		url=$$(. "$$dir/.env.example"; printf '%s' "$$ANTHROPIC_BASE_URL"); \
		printf '  %-10s -> %-9s %s\n' "$$p" "$$cmd" "$$url"; \
	done

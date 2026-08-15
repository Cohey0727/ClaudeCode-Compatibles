SHELL   := /bin/bash
PREFIX  ?= $(HOME)/.local
BIN_DIR := $(PREFIX)/bin

ROOT          := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
PROVIDERS_DIR := $(ROOT)/providers
COMMON        := $(ROOT)/bin/common.sh

# Every target acts on all directories under providers/.
PROVIDER_LIST := $(notdir $(wildcard $(PROVIDERS_DIR)/*))

.PHONY: setup uninstall list pi-global

# Interactive wizard: checkbox provider picker, per-provider API token
# prompts (Enter keeps the current token), launcher install, PATH checks.
setup:
	@BIN_DIR="$(BIN_DIR)" "$(ROOT)/bin/setup.sh"

uninstall:
	@for p in $(PROVIDER_LIST); do \
		dir="$(PROVIDERS_DIR)/$$p"; \
		[ -f "$$dir/.env.example" ] || continue; \
		for cmd in $$(. "$(COMMON)"; . "$$dir/.env.example"; launcher_names "$$p"); do \
			rm -f "$(BIN_DIR)/$$cmd" && echo "  Removed $(BIN_DIR)/$$cmd"; \
		done; \
	done
	@. "$(COMMON)"; out=$$(pi_global_models_path); \
		if [ -f "$$out" ] && [ "$$(head -1 "$$out")" = "$$PI_GLOBAL_MARKER" ]; then \
			rm -f "$$out" && echo "  Removed $$out"; \
		fi
	@echo "  Note: provider .env files are left in place. Delete them manually if no longer needed."

list:
	@for p in $(PROVIDER_LIST); do \
		dir="$(PROVIDERS_DIR)/$$p"; \
		[ -f "$$dir/.env.example" ] || continue; \
		cmds=$$(. "$(COMMON)"; . "$$dir/.env.example"; launcher_names "$$p" | sed 's| | / |g'); \
		url=$$(. "$(COMMON)"; . "$$dir/.env.example"; pick ANTHROPIC_BASE_URL BASE_URL); \
		printf '  %-10s -> %-44s %s\n' "$$p" "$$cmds" "$$url"; \
	done

# Register every provider in pi's global models.json, so a bare `pi` sees them
# too. The pi<name> launchers do not need this.
pi-global:
	@"$(ROOT)/bin/pi-global-models.sh"

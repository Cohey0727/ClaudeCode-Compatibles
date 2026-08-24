SHELL   := /bin/bash
PREFIX  ?= $(HOME)/.local
BIN_DIR := $(PREFIX)/bin

ROOT          := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
PROVIDERS_DIR := $(ROOT)/providers
COMMON        := $(ROOT)/bin/common.sh

# Every target acts on all directories under providers/.
PROVIDER_LIST := $(notdir $(wildcard $(PROVIDERS_DIR)/*))

.PHONY: setup uninstall list pi-global opencode-global

# Interactive wizard: checkbox provider picker, per-provider API token
# prompts (Enter keeps the current token), launcher install, pi package
# install, PATH checks.
setup:
	@BIN_DIR="$(BIN_DIR)" "$(ROOT)/bin/setup.sh"

uninstall:
	@for p in $(PROVIDER_LIST); do \
		dir="$(PROVIDERS_DIR)/$$p"; \
		[ -f "$$dir/.env.example" ] || continue; \
		suffix=$$(. "$(COMMON)"; load_settings "$$dir/.env.example"; printf '%s' "$${NAME:-$$p}"); \
		for cmd in $$(. "$(COMMON)"; load_settings "$$dir/.env.example"; launcher_names "$$p") "open$$suffix"; do \
			rm -f "$(BIN_DIR)/$$cmd" && echo "  Removed $(BIN_DIR)/$$cmd"; \
		done; \
		rm -f "$$dir/.opencode.json"; \
	done
	@. "$(COMMON)"; out=$$(pi_global_models_path); \
		if [ -f "$$out" ] && [ "$$(head -1 "$$out")" = "$$PI_GLOBAL_MARKER" ]; then \
			rm -f "$$out" && echo "  Removed $$out"; \
		fi
	@. "$(COMMON)"; out=$$(opencode_global_config_path); \
		if [ -f "$$out" ] && [ "$$(head -1 "$$out")" = "$$OPENCODE_GLOBAL_MARKER" ]; then \
			rm -f "$$out" && echo "  Removed $$out"; \
		fi; \
		rm -rf "$$(opencode_tokens_dir)" && echo "  Removed $$(opencode_tokens_dir)"
	@if command -v pi >/dev/null 2>&1; then \
		. "$(COMMON)"; \
		for spec in $$PI_PACKAGES; do \
			src=$$(pi_package_source "$$spec"); \
			if pi_package_installed "$$src"; then \
				pi remove "$$src" >/dev/null 2>&1 \
					&& echo "  Removed pi package $$src"; \
			fi; \
		done; \
	fi
	@echo "  Note: provider .env files are left in place. Delete them manually if no longer needed."

list:
	@for p in $(PROVIDER_LIST); do \
		dir="$(PROVIDERS_DIR)/$$p"; \
		[ -f "$$dir/.env.example" ] || continue; \
		cmds=$$(. "$(COMMON)"; load_settings "$$dir/.env.example"; launcher_names "$$p" | sed 's| | / |g'); \
		url=$$(. "$(COMMON)"; load_settings "$$dir/.env.example"; printf '%s' "$$CFG_BASE_URL"); \
		printf '  %-10s -> %-44s %s\n' "$$p" "$$cmds" "$$url"; \
	done

# Register every provider in pi's global models.json, so a bare `pi` sees them
# too. The pi<name> launchers do not need this.
pi-global:
	@"$(ROOT)/bin/pi-global-models.sh"

# Register every provider in OpenCode's global config, so a bare `opencode`
# (there are no open<name> launchers) lists them all under /models.
opencode-global:
	@"$(ROOT)/bin/opencode-global-config.sh"

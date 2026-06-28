PREFIX  ?= $(HOME)/.local
BIN_DIR := $(PREFIX)/bin

ROOT          := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
TEMPLATE      := $(ROOT)/bin/launcher.template
PROVIDERS_DIR := $(ROOT)/providers

# Act on one provider with `make install PROVIDER=deepseek`.
# Default (empty) acts on every directory under providers/.
PROVIDER ?=
ifeq ($(strip $(PROVIDER)),)
  PROVIDER_LIST := $(notdir $(wildcard $(PROVIDERS_DIR)/*))
else
  PROVIDER_LIST := $(PROVIDER)
endif

.PHONY: install uninstall list

install:
	@mkdir -p "$(BIN_DIR)"
	@for p in $(PROVIDER_LIST); do \
		dir="$(PROVIDERS_DIR)/$$p"; \
		[ -f "$$dir/config" ] || { echo "  skip $$p: no providers/$$p/config"; continue; }; \
		cmd=$$(. "$$dir/config"; printf '%s' "$$COMMAND"); \
		keyvar=$$(. "$$dir/config"; printf '%s' "$$KEY_VAR"); \
		env="$$dir/.env"; \
		if [ ! -f "$$env" ]; then cp "$$dir/.env.example" "$$env"; chmod 600 "$$env"; echo "  Created $$env from .env.example"; fi; \
		sed 's|@@PROVIDER_DIR@@|'"$$dir"'|g' "$(TEMPLATE)" > "$(BIN_DIR)/$$cmd"; \
		chmod +x "$(BIN_DIR)/$$cmd"; \
		echo "  Installed: $(BIN_DIR)/$$cmd  ($$p)"; \
		if grep -Eq "^$$keyvar=.+" "$$env"; then echo "    $$keyvar: set"; else echo "    $$keyvar: NOT SET — edit $$env"; fi; \
	done
	@echo
	@command -v claude >/dev/null 2>&1 || echo "  WARNING: 'claude' is not on your PATH — install Claude Code first."
	@case ":$$PATH:" in *":$(BIN_DIR):"*) ;; *) \
		echo "  WARNING: $(BIN_DIR) is not on your PATH. Add to your shell rc:"; \
		echo "    export PATH=\"$(BIN_DIR):\$$PATH\"";; \
	esac

uninstall:
	@for p in $(PROVIDER_LIST); do \
		dir="$(PROVIDERS_DIR)/$$p"; \
		[ -f "$$dir/config" ] || continue; \
		cmd=$$(. "$$dir/config"; printf '%s' "$$COMMAND"); \
		rm -f "$(BIN_DIR)/$$cmd" && echo "  Removed $(BIN_DIR)/$$cmd"; \
	done
	@echo "  Note: provider .env files are left in place. Delete them manually if no longer needed."

list:
	@for p in $(PROVIDER_LIST); do \
		dir="$(PROVIDERS_DIR)/$$p"; \
		[ -f "$$dir/config" ] || continue; \
		cmd=$$(. "$$dir/config"; printf '%s' "$$COMMAND"); \
		url=$$(. "$$dir/config"; printf '%s' "$$BASE_URL"); \
		printf '  %-10s -> %-9s %s\n' "$$p" "$$cmd" "$$url"; \
	done

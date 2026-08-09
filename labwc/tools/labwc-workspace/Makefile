# labwc-workspace — active-workspace reporter daemon (labwc-only).
# Builds the daemon from the vendored ext-workspace-v1.xml.
#
#   make            # build ./labwc-workspace
#   make install    # install to $(PREFIX)/bin (default ~/.local/bin)
#   make clean      # remove generated bindings + binary
#
# Requires: cc, pkg-config, wayland-scanner, wayland-client.
# Runtime: a labwc session offering ext_workspace_manager_v1.

PREFIX ?= $(HOME)/.local

WAYLAND_SCANNER ?= wayland-scanner
PKG_CONFIG ?= pkg-config

CFLAGS ?= -O2 -Wall -Wextra
CFLAGS += $(shell $(PKG_CONFIG) --cflags wayland-client)
LDLIBS += $(shell $(PKG_CONFIG) --libs wayland-client)

XML_WS := ext-workspace-v1.xml

GEN := ext-ws-client.h ext-ws-code.c

BIN := labwc-workspace

all: $(BIN)

$(BIN): labwc-workspace.c $(GEN)
	$(CC) $(CFLAGS) -o $@ labwc-workspace.c ext-ws-code.c $(LDLIBS)

ext-ws-client.h: $(XML_WS)
	$(WAYLAND_SCANNER) client-header $(XML_WS) $@

ext-ws-code.c: $(XML_WS)
	$(WAYLAND_SCANNER) private-code $(XML_WS) $@

install: $(BIN)
	install -Dm755 $(BIN) $(DESTDIR)$(PREFIX)/bin/$(BIN)

clean:
	rm -f $(BIN) $(GEN)

.PHONY: all install clean

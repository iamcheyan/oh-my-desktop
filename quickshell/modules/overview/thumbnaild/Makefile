# Sumika overview thumbnail daemon — labwc-only Wayland client.
# Builds the daemon from protocol XMLs checked into this directory.
#
#   make            # build ./sumika-overview-thumbnaild
#   make install    # install to $(PREFIX)/bin (default ~/.local/bin)
#   make clean      # remove generated bindings + binary
#
# Requires: cc, pkg-config, wayland-scanner, wayland-client (>= 1.22),
#           wayland-protocols headers are NOT needed (xmls vendored here).
# Runtime: grim must be installed (captures window thumbnails).

PREFIX ?= $(HOME)/.local

WAYLAND_SCANNER ?= wayland-scanner
PKG_CONFIG ?= pkg-config

CFLAGS ?= -O2 -Wall -Wextra
CFLAGS += $(shell $(PKG_CONFIG) --cflags wayland-client)
LDLIBS += $(shell $(PKG_CONFIG) --libs wayland-client)

XML_FTL := ext-foreign-toplevel-list-v1.xml
XML_WS  := ext-workspace-v1.xml
XML_WLR := wlr-foreign-toplevel-management-unstable-v1.xml

GEN := ext-ftl-client.h ext-ftl-code.c \
       ext-ws-client.h ext-ws-code.c \
       wlr-ftl-client.h wlr-ftl-code.c

BIN := sumika-overview-thumbnaild

all: $(BIN)

$(BIN): thumbnaild.c $(GEN)
	$(CC) $(CFLAGS) -o $@ thumbnaild.c ext-ftl-code.c ext-ws-code.c wlr-ftl-code.c $(LDLIBS)

ext-ftl-client.h: $(XML_FTL)
	$(WAYLAND_SCANNER) client-header $(XML_FTL) $@

ext-ftl-code.c: $(XML_FTL)
	$(WAYLAND_SCANNER) private-code $(XML_FTL) $@

ext-ws-client.h: $(XML_WS)
	$(WAYLAND_SCANNER) client-header $(XML_WS) $@

ext-ws-code.c: $(XML_WS)
	$(WAYLAND_SCANNER) private-code $(XML_WS) $@

wlr-ftl-client.h: $(XML_WLR)
	$(WAYLAND_SCANNER) client-header $(XML_WLR) $@

wlr-ftl-code.c: $(XML_WLR)
	$(WAYLAND_SCANNER) private-code $(XML_WLR) $@

install: $(BIN)
	install -Dm755 $(BIN) $(DESTDIR)$(PREFIX)/bin/$(BIN)

clean:
	rm -f $(BIN) $(GEN)

.PHONY: all install clean

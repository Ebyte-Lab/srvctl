PREFIX ?= /usr
BINDIR = $(PREFIX)/bin
SHAREDIR = $(PREFIX)/share/srvctl

install:
	# Create directories
	install -d $(DESTDIR)$(BINDIR)
	install -d $(DESTDIR)$(SHAREDIR)/core
	install -d $(DESTDIR)$(SHAREDIR)/modules
	install -d $(DESTDIR)$(SHAREDIR)/adapters
	install -d $(DESTDIR)$(SHAREDIR)/lib

	# Install the main executable
	install -m 755 bin/srvctl $(DESTDIR)$(BINDIR)/srvctl

	# Install the framework files
	cp -r core/* $(DESTDIR)$(SHAREDIR)/core/
	cp -r modules/* $(DESTDIR)$(SHAREDIR)/modules/
	cp -r adapters/* $(DESTDIR)$(SHAREDIR)/adapters/
	cp -r lib/* $(DESTDIR)$(SHAREDIR)/lib/

	# Ensure proper permissions for framework scripts
	find $(DESTDIR)$(SHAREDIR) -type f -name "*.sh" -exec chmod 644 {} \;

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/srvctl
	rm -rf $(DESTDIR)$(SHAREDIR)
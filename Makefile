PREFIX ?= $(HOME)/.local
DESTDIR ?=
BINDIR = $(DESTDIR)$(PREFIX)/bin
DATADIR = $(DESTDIR)$(PREFIX)/share

.PHONY: run demo check test install uninstall
run:
	./otuple
demo:
	./otuple --demo
test:
	python -m unittest discover -s tests -v
check: test
	bash -n otuple
	bash -n packaging/arch/PKGBUILD
	python scripts/check-qml.py
	omarchy plugin validate .
	desktop-file-validate packaging/otuple.desktop
install:
	install -Dm755 otuple "$(BINDIR)/otuple"
	install -Dm644 assets/otuple.svg "$(DATADIR)/icons/hicolor/scalable/apps/otuple.svg"
	install -Dm644 assets/otuple-symbolic.svg "$(DATADIR)/icons/hicolor/scalable/apps/otuple-symbolic.svg"
	install -Dm644 packaging/otuple.desktop "$(DATADIR)/applications/otuple.desktop"
	@if [ -z "$(DESTDIR)" ] && command -v update-desktop-database >/dev/null; then update-desktop-database "$(DATADIR)/applications" || true; fi
uninstall:
	rm -f "$(BINDIR)/otuple" "$(DATADIR)/applications/otuple.desktop" "$(DATADIR)/icons/hicolor/scalable/apps/otuple.svg" "$(DATADIR)/icons/hicolor/scalable/apps/otuple-symbolic.svg"

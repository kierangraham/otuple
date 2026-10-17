PREFIX ?= $(HOME)/.local

.PHONY: run demo check test install-launcher uninstall-launcher
run:
	./otuple
demo:
	./otuple --demo
test:
	python -m unittest discover -s tests -v
check: test
	bash -n otuple
	python scripts/check-qml.py
	omarchy plugin validate .
	desktop-file-validate packaging/otuple.desktop
install-launcher:
	install -Dm755 otuple "$(PREFIX)/bin/otuple"
	install -Dm644 assets/otuple.svg "$(PREFIX)/share/icons/hicolor/scalable/apps/otuple.svg"
	install -Dm644 assets/otuple-symbolic.svg "$(PREFIX)/share/icons/hicolor/scalable/apps/otuple-symbolic.svg"
	install -Dm644 packaging/otuple.desktop "$(PREFIX)/share/applications/otuple.desktop"
	@command -v update-desktop-database >/dev/null && update-desktop-database "$(PREFIX)/share/applications" || true
uninstall-launcher:
	rm -f "$(PREFIX)/bin/otuple" "$(PREFIX)/share/applications/otuple.desktop" "$(PREFIX)/share/icons/hicolor/scalable/apps/otuple.svg" "$(PREFIX)/share/icons/hicolor/scalable/apps/otuple-symbolic.svg"

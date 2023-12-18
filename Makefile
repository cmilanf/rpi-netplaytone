PREFIX=/usr/local
BINDIR=$(PREFIX)/bin
SHAREDIR=$(PREFIX)/share

FOLDER_SRC=./sbbstone
FOLDER_DEST=$(SHAREDIR)
SCRIPTS_SRC=./
SCRIPTS_DEST=$(BINDIR)
SERVICE_SRC=./rpi-netplaytone.service
SERVICE_DEST=/etc/systemd/system

install:
	# Create the destination folder if it doesn't exist
	mkdir -p $(FOLDER_DEST)
	# Copy the folder
	cp -r $(FOLDER_SRC) $(FOLDER_DEST)
	# Copy the scripts
	cp $(SCRIPTS_SRC)/playtone.bash $(SCRIPTS_DEST)
	cp $(SCRIPTS_SRC)/rpi-netplaytone.py $(SCRIPTS_DEST)
	# Copy and enable the systemd service
	cp $(SERVICE_SRC) $(SERVICE_DEST)
	systemctl enable rpi-netplaytone.service

uninstall:
	# Remove the folder
	rm -rf $(FOLDER_DEST)
	# Remove the scripts
	rm -f $(SCRIPTS_DEST)/playtone.bash
	rm -f $(SCRIPTS_DEST)/rpi-netplaytone.py
	# Disable and remove the systemd service
	systemctl disable rpi-netplaytone.service
	rm -f $(SERVICE_DEST)/rpi-netplaytone.service

.PHONY: install uninstall

echo -e '\n# MeshCore bridge UART\nenable_uart=1\ndtoverlay=disable-bt' | sudo tee -a /boot/firmware/config.txt
sudo systemctl disable --now hciuart bluetooth
sudo cp /boot/firmware/cmdline.txt /boot/firmware/cmdline.txt.orig
sudo sed -i 's/console=serial0,[0-9]* //' /boot/firmware/cmdline.txt
cat /boot/firmware/cmdline.txt        # must no longer contain console=serial0
sudo reboot

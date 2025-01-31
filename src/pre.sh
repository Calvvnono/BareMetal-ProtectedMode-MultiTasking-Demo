#!/bin/bash
nasm ./mt.asm -o mt.com
sudo umount /mnt/floppyB
sudo mount -o loop pmtest.img /mnt/floppyB
sudo rm /mnt/floppyB/mt.com
sudo cp ./mt.com /mnt/floppyB
bochs -f bochsrc.txt

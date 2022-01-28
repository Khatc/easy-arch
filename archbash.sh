#!/usr/bin/env -S bash -e

#########################
## Arch Install script ##
#########################

userpass_selector () {
while true; do
  read -r -s -p "Set a user password for $username: " userpass
	while [ -z "$userpass" ]; do
	echo
	print "You need to enter a password for $username."
	read -r -s -p "Set a user password for $username: " userpass
	[ -n "$userpass" ] && break
	done
  echo
  read -r -s -p "Insert password again: " userpass2
  echo
  [ "$userpass" = "$userpass2" ] && break
  echo "Passwords don't match, try again."
done
}

# Setting up a password for the root account (function).
rootpass_selector () {
while true; do
  read -r -s -p "Set a root password: " rootpass
	while [ -z "$rootpass" ]; do
	echo
	print "You need to enter a root password."
	read -r -s -p "Set a root password: " rootpass
	[ -n "$rootpass" ] && break
	done
  echo
  read -r -s -p "Password (again): " rootpass2
  echo
  [ "$rootpass" = "$rootpass2" ] && break
  echo "Passwords don't match, try again."
done
}

# Setting up the hostname (function).
hostname_selector () {
    read -r -p "Please enter the hostname: " hostname
    if [ -z "$hostname" ]; then
        print "You need to enter a hostname in order to continue."
        hostname_selector
    fi
    echo "$hostname" > /mnt/etc/hostname
}


#update system clock
timedatectl set-ntp

#Format partitions
mkfs.ext4 /dev/sda3 &>/dev/null
mkswap /dev/sda2 &>/dev/null
mkfs.fat -F 32 /dev/sda1 &>/dev/null

#Mount the partitions
mount /dev/sda3 /mnt
swapon /dev/sda2

mkdir /mnt/boot/EFI
mount /dev/sda1 /mnt/boot/EFI

#pacstrap
pacstrap /mnt --needed base linux linux-firmware base-devel

# Setting up the hostname.
hostname_selector

#Fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Setting username.
read -r -p "Please enter name for a user account (enter empty to not create one): " username
userpass_selector
rootpass_selector

#locale
echo "en_US.UTF-8 UTF-8" > /mnt/etc/locale.gen
echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf

#hosts file
cat > /mnt/etc/hosts <<EOF
127.0.0.1	localhost
::1			localhost
127.0.1.1	$hostname.localdomain	$hostname
EOF

#chroot
arch-chroot /mnt /bin/bash -e <<EOF
    # Setting up timezone.
    echo "Setting up the timezone."
    ln -sf /usr/share/zoneinfo/America/Chicago /etc/localtime &>/dev/null
    
    # Setting up clock.
    echo "Setting up the system clock."
    hwclock --systohc
    
    # Generating locales.
    echo "Generating locales."
    locale-gen &>/dev/null
	
	#Basic packages
	pacman -S --noconfirm xorg picom nitrogen sudo nano bspwm sxhkd xdg-user-dirs xf86-video-amdgpu vim grub efibootmgr dosfstools os-prober mtools networkmanager alacritty sddm qutebrowser exa otf-font-awesome adobe-source-code-pro-fonts adobe-source sans-fonts ttf-ubuntu-font-family
    
    # Installing GRUB.
    echo "Installing GRUB on /boot."
    grub-install --target=x86_64-efi --efi-directory=/boot/EFI --bootloader-id=GRUB &>/dev/null
    # Creating grub config file.
    echo "Creating GRUB config file."
    grub-mkconfig -o /boot/grub/grub.cfg &>/dev/null
	
	# Pacman eye-candy features.
	print "Enabling colours, animations, and parallel in pacman."
	sed -i 's/#Color/Color\nILoveCandy/;s/^#ParallelDownloads.*$/ParallelDownloads = 10/' /etc/pacman.conf
EOF

# Setting root password.
print "Setting root password."
echo "root:$rootpass" | arch-chroot /mnt chpasswd

# Setting user password.
if [ -n "$username" ]; then
    print "Adding the user $username to the system with root privilege."
    arch-chroot /mnt useradd -m -G wheel,video,optical -s /bin/bash "$username"
    sed -i 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /mnt/etc/sudoers
    print "Setting user password for $username." 
    echo "$username:$userpass" | arch-chroot /mnt chpasswd
fi

# Finishing up.
print "Done, any further changes can be set by chroot into /mnt"
exit



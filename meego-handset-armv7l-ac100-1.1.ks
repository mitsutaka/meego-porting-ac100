lang en_US.UTF-8
keyboard us
timezone --utc America/Los_Angeles
auth --useshadow --enablemd5
#part / --size=1600  --ondisk mmcblk0p --fstype=btrfs
part / --size=1900  --ondisk mmcblk0p --fstype=ext3
#part swap --size=256 --ondisk mmcblk0p --fstype=swap

rootpw meego
xconfig --startxonboot
desktop --autologinuser=meego  --defaultdesktop=DUI --session=/usr/bin/mcompositor
user --name meego  --groups audio,video --password meego

repo --name=core     --baseurl=http://repo.meego.com/MeeGo/releases/1.1/core/repos/armv7l/packages/ --save --debuginfo --source --gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-meego01
repo --name=handset  --baseurl=http://repo.meego.com/MeeGo/releases/1.1/handset/repos/armv7l/packages/ --save --debuginfo --source --gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-meego01
repo --name=non-oss  --baseurl=http://repo.meego.com/MeeGo/releases/1.1/non-oss/repos/armv7l/packages/ --save --debuginfo --source --gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-meego01
repo --name=updates-core     --baseurl=http://repo.meego.com/MeeGo/updates/1.1/core/repos/armv7l/packages/ --save --debuginfo --source --gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-meego01
#repo --name=updates-handset  --baseurl=http://repo.meego.com/MeeGo/updates/1.1/handset/repos/armv7l/packages/ --save --debuginfo --source --gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-meego01
#repo --name=updates-non-oss  --baseurl=http://repo.meego.com/MeeGo/updates/1.1/non-oss/repos/armv7l/packages/ --save --debuginfo --source --gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-meego01


%packages
@MeeGo Core
@MeeGo Base
@Minimal MeeGo X Window System
@MeeGo Compliance
@MeeGo Handset Desktop
@MeeGo Handset Applications
@MeeGo Handset Applications Branding
@X for Handsets
@MeeGo Handset Base Support

# Some development tools
openssh-server
wget
strace
bootchart
gdb
gdb-gdbserver

# Some extra tools/libs
connman-test
xorg-x11-utils-xev

# http://bugs.meego.com/show_bug.cgi?id=5651
-meegotouch-inputmethodbridges
-meegotouch-inputmethodframework
-meegotouch-inputmethodkeyboard
-meegotouch-inputmethodengine

# For ac100
xorg-x11-drv-fbdev
mesa-dri-swrast-driver
yum
yum-utils
tar
%end

%post
set -x
# Prelink not included because of following bug
# http://bugs.meego.com/show_bug.cgi?id=5217

# make sure there aren't core files lying around
rm -f /core*

# open serial line console for embedded system
echo "s0:235:respawn:/sbin/agetty -L 115200 ttyS2 vt100" >> /etc/inittab

# work around for poor key import UI in PackageKit
rm -f /var/lib/rpm/__db*
rpm --rebuilddb

# Set up sane defaults for mthemedaemon settings
Config_Src=`gconftool-2 --get-default-source`
gconftool-2 --direct --config-source $Config_Src \
  -s -t string /meegotouch/theme/target AC100

# Temporary fix to the meego-handset-fixup rpm package
sed -i 's!N900!AC100!g' /etc/gconf/gconf.xml.defaults/%gconf-tree.xml

#sed -i 's!\/usr\/sbin\/meego-dm!\/usr\/bin\/xinit \/usr\/bin\/startdui!' /etc/inittab
echo "#x:5:respawn:/usr/bin/xinit /usr/bin/startdui" >>/etc/inittab

cat >>/etc/meegotouch/devices.conf <<EOF
[AC100]
resolutionX=1024
resolutionY=600
ppiX=256
ppiY=256
showStatusBar=false
EOF

cat >/usr/bin/startdui <<EOF
#!/bin/sh
/usr/bin/mthemedaemon &
/usr/bin/sysuid -software -remote-theme &
/usr/bin/meego-im-uiserver -software -remote-theme &
/usr/bin/mdecorator -software -remote-theme &
/usr/bin/startphonesim
exec /usr/bin/duihome --desktop -software -remote-theme
EOF
chmod +x /usr/bin/startdui


cat >>/etc/rc.d/rc.sysinit <<EOF
mkdir -p /mnt/sdcard /mnt/system /mnt/cache /mnt/userdata
(sleep 5; /sbin/adbd) &
EOF
mkdir -p /system/bin
ln -s /bin/bash /system/bin/sh

swprogs="
/usr/share/applications/dialer.desktop
/usr/share/applications/duicontrolpanel.desktop
/usr/share/applications/meego-handset-calendar.desktop
/usr/share/applications/meego-handset-chat.desktop
/usr/share/applications/meego-handset-people.desktop
/usr/share/applications/meego-handset-video.desktop
/usr/share/applications/meegomusic.desktop
/usr/share/applications/meegophotos.desktop
/usr/share/applications/settings.desktop
/usr/share/applications/sms.desktop
/etc/xdg/autostart/applauncherd.desktop
/etc/xdg/autostart/mdecorator.desktop
/etc/xdg/autostart/meego-im-uiserver.desktop
/etc/xdg/autostart/meegotouch-systemui.desktop
"
for prog in $swprogs; do
    sed -e "s/Exec=.*$/\0 -software/" -i $prog
done

sed 's!session=\/usr\/bin\/mcompositor!session=\/usr\/bin\/duihome -software \&!' -i /etc/sysconfig/uxlaunch

# Normal bootchart is only 30 long so we use this to get longer bootchart during startup when needed.
cat > /sbin/bootchartd-long << EOF
#!/bin/sh
exec /sbin/bootchartd -n 4000
EOF
chmod +x /sbin/bootchartd-long

# Temporary fix for BMC#8664 to get fennec startup time more reasonable.
mkdir -p /home/meego/.mozilla/
chown -R meego:meego /home/meego/.mozilla/
cat >>/etc/fstab << EOF
tmpfs /home/meego/.mozilla tmpfs size=20m 0 0
/dev/mmcblk0p1 /mnt/sdcard vfat defaults 0 0
/dev/mtdblock3 /mnt/system yaffs2 defaults 0 0
/dev/mtdblock4 /mnt/cache yaffs2 defaults 0 0
/dev/mtdblock5 /mnt/userdata yaffs2 defaults 0 0
EOF
%end

%post --nochroot
set -x
if [ -n "$IMG_NAME" ]; then
    echo "BUILD: $IMG_NAME" >> $INSTALL_ROOT/etc/meego-release
fi

# Creating rootfs tar ball.
for dir in `mount | grep $INSTALL_ROOT\/ | awk '{ print $3 }' | sort -r`; do
    umount $dir
done
outdir=`pwd`
(cd $INSTALL_ROOT; tar czvf $outdir/${IMG_NAME}-rootfs.tar.gz .)
%end

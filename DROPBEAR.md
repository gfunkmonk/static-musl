Manual installation
1. copy dropbearmultin in /usr/sbin
2. create dropbearmulti aliases (call ./dropbearmulti)

_***DROPBEAR INSTALL***_
Dropbear multi-purpose version 0.51
  Make a symlink pointing at this binary with one of the following names:
  'dropbear' - the Dropbear server
  'dbclient' or 'ssh' - the Dropbear client
  'dropbearkey' - the key generator
  'dropbearconvert' - the key converter
  'scp' - secure copy

Note: scp mayby needed to be created in /usr/bin

  ln -s /usr/sbin/dropbearmulti /usr/bin/scp

3. create rsa keys in /etc/dropbear (e.g. /etc/dropbear/dropbear_rsa_host_key)

  mkdir -p /etc/dropbear
  dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key
  dropbearkey -t dss -f /etc/dropbear/dropbear_dss_host_key


if needed create /dev/random device
1. mknod -m 644 /dev/random c 1 8
2. mknod -m 644 /dev/urandom c 1 9
3. chown root:root /dev/random /dev/urandom

Running dropbear server in foreground (on default port)
./dropbear

Note: use -E option to log on sdterr

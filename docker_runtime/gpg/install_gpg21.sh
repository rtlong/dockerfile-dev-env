#!/bin/bash

set -e -x -u

pkg_deps=(
  build-essential
  bzip2
  file
  g++
  gettext
  gnutls-bin
  libgcrypt20-dev
  libgnutls-dev
  libgpg-error-dev
  libksba-dev
  libnpth0-dev
  make
  texinfo
)

apt-get install ${pkg_deps[*]}

pushd /tmp

keys_to_fetch=(
  0x33BD3F06
  0x4F25E3B6
  0x7EFD60D9
  0xE0856959
  0xF7E48EDB
)
gpg --recv-keys ${keys_to_fetch[*]}

libassuan_version="${libassuan_version:-2.4.2}"
gnupg_version="${gnupg_version:-2.1.10}"

curl -L -O "ftp://ftp.gnupg.org/gcrypt/libassuan/libassuan-${libassuan_version}.tar.bz2"
curl -L -O "ftp://ftp.gnupg.org/gcrypt/libassuan/libassuan-${libassuan_version}.tar.bz2.sig"
gpg --verify "libassuan-${libassuan_version}.tar.bz2.sig"
tar -xjf "libassuan-${libassuan_version}.tar.bz2"

pushd "libassuan-${libassuan_version}"
./configure
make
make install
popd

curl -L -o gnupg.tar.bz2 "https://gnupg.org/ftp/gcrypt/gnupg/gnupg-${gnupg_version}.tar.bz2"
curl -L -o gnupg.tar.bz2.sig "https://gnupg.org/ftp/gcrypt/gnupg/gnupg-${gnupg_version}.tar.bz2.sig"
gpg --verify gnupg.tar.bz2.sig gnupg.tar.bz2
tar -xjf gnupg.tar.bz2

pushd gnupg-${gnupg_version}
./configure
make
make install
popd

ln -s ${PREFIX}/bin/gpg2 ${PREFIX}/bin/gpg

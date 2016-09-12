#!/bin/bash

set -euo pipefail
set -x

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

apt-get update
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

install_component() {
	local archive_url="$1"; shift
	local signature_url="${archive_url}.sig"

	local archive_filename="$(basename "${archive_url}")"
	local signature_filename="$(basename "${signature_url}")"
	local extracted_dirname="${archive_filename/.tar.bz2//}"

	curl -L -o "${archive_filename}" "${archive_url}"
	curl -L -o "${signature_filename}" "${signature_url}"

	gpg --verify "${signature_filename}"
	tar -xjf "${archive_filename}"

	pushd "${extracted_dirname}"
	./configure
	make
	make install
	popd
}

install_component "https://gnupg.org/ftp/gcrypt/libassuan/libassuan-2.4.3.tar.bz2"
install_component "https://gnupg.org/ftp/gcrypt/libgpg-error/libgpg-error-1.24.tar.bz2"
install_component "https://gnupg.org/ftp/gcrypt/libgcrypt/libgcrypt-1.7.3.tar.bz2"
install_component "https://gnupg.org/ftp/gcrypt/libksba/libksba-1.3.5.tar.bz2"
install_component "https://gnupg.org/ftp/gcrypt/gnupg/gnupg-2.1.15.tar.bz2"

ln -s ${PREFIX}/bin/gpg2 ${PREFIX}/bin/gpg

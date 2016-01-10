#!/bin/bash
# vim: noexpandtab softtabstop=4 tabstop=4 shiftwidth=4:

set -e -u

trap 'kill_sshd' INT
trap 'kill_sshd' TERM

# we'll set this later to the PID of the sshd process
sshd=''

kill_sshd() {
	if [[ -n "$sshd" ]]; then
		echo "Killing SSHD..."
		kill -TERM "$sshd"
	fi
}

create_key() {
	local file="$1"
	shift

	printf '\n### %s\n' "$file"
	if [[ -f $file ]]; then
		echo 'Already exists'
	else
		echo 'Generate new'
		ssh-keygen -q -f "$file" -N '' "$@"
	fi
	if [[ ! -f ${file}.pub ]]; then
		ssh-keygen -y -f "${file}" > "${file}.pub"
	fi
	if which restorecon >/dev/null 2>&1; then
		restorecon "$file" "${file}.pub"
	fi

	# Print fingerprints out to log:
	ssh-keygen -E sha256 -l -f "${file}.pub"
	ssh-keygen -v -E md5 -l -f "${file}.pub"
}

create_keys() {
	echo 'Generating SSH Host Keys...'
	mkdir -p /etc/ssh/ssh_host_keys
	# create_key /etc/ssh/ssh_host_keys/rsa1_key -t rsa1
	create_key /etc/ssh/ssh_host_keys/rsa_key -t rsa
	create_key /etc/ssh/ssh_host_keys/dsa_key -t dsa
	create_key /etc/ssh/ssh_host_keys/ecdsa_key -t ecdsa
	create_key /etc/ssh/ssh_host_keys/ed25519_key -t ed25519
	echo
	echo
}

allow_github_user_via_ssh() {
	local ghuser="$1"

	echo "Adding user: ${ghuser}"

	mkdir -p '/root/.ssh/'

	echo 'Got the following keys:'
	curl -fsSL "https://github.com/${ghuser}.keys" | (
		cd /root/.ssh
		local i=0
		while read pubkey; do
			local fn="${ghuser}_key_${i}.pub"
			local fp=$(echo "$pubkey" > "$fn" && ssh-keygen -E md5 -l -f "$fn"; rm -f "$fn")
			((i++)) || true

			local keylength=$(echo $fp | awk '{ print $1 }')
			if [[ $keylength -ge 2048 ]]; then
				echo "$pubkey" >> authorized_keys
				printf '  %s\n' "$fp"
			else
				printf '  %s [less than 2048 - IGNORED]\n' "$fp"
			fi
		done
	)
}

main() {
	# allow command override; don't bother with any other SSH stuff in that case
	if [[ $# > 0 ]]; then
		exec "$@"
	fi

	# Regerate SSH Host Keys: n.b. Normally one could use `/usr/sbin/dpkg-reconfigure openssh-server`, but we're putting host keys in their own directory for docker volume mounting purposes
	create_keys

	if [[ ${GITHUB_USERS_TO_ALLOW_SSH:-unset} = unset && ! -f /root/.ssh/authorized_keys ]]; then
		echo 'WARN: GITHUB_USERS_TO_ALLOW_SSH env variable is not set. You need to mount a /root/.ssh/authorized_keys file in order to use SSH' >&2
	fi

	for ghuser in ${GITHUB_USERS_TO_ALLOW_SSH:-}; do
		allow_github_user_via_ssh "$ghuser"
	done

	echo
	echo '===== Starting SSHD ====='
	# n.b. Not using exec here as sshd doesn't die on SIGINT which is annoying when using docker run (see the trap at the top of the file)
	/usr/sbin/sshd -D -e &
	sshd=$!
	wait $sshd
}

main "$@"

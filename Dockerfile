# vim: set expandtab tabstop=2 shiftwidth=2 softtabstop=2:
FROM ubuntu:xenial

ENV PREFIX /usr/local

# Tell Apt never to prompt
ENV DEBIAN_FRONTEND noninteractive

RUN set -x \

 # Set up UTF support
 && locale-gen en_US en_US.UTF-8 \
 && dpkg-reconfigure locales \
 && update-locale LANG=en_US.UTF-8 \

 # Set apt mirror
 && sed 's:archive.ubuntu.com/ubuntu/:mirrors.rit.edu/ubuntu-archive/:' -i /etc/apt/sources.list \

 # never install recommends automatically
 && echo 'Apt::Install-Recommends "false";' > /etc/apt/apt.conf.d/docker-no-recommends \
 && echo 'APT::Get::Assume-Yes "true";' > /etc/apt/apt.conf.d/docker-assume-yes \
 && echo 'APT::Get::AutomaticRemove "true";' > /etc/apt/apt.conf.d/docker-auto-remove \

 # enable backports and others off by default
 && sed 's/^#\s*deb/deb/' -i /etc/apt/sources.list \

 # Enable automatic preference to use backport
 && echo 'Package: *'                      >> /etc/apt/preferences \
 && echo 'Pin: release a=xenial-backports' >> /etc/apt/preferences \
 && echo 'Pin-Priority: 500'               >> /etc/apt/preferences \

 && apt-get update \
 && apt-get upgrade \
 && apt-get install \
       apt-transport-https \
       ca-certificates \
       software-properties-common

# Set up PPAs
RUN add-apt-repository ppa:git-core/ppa \

 # Install base packages
 && apt-get update \
 && apt-get upgrade \
 && apt-get install \
      aptitude \
      bash \
      build-essential \
      bzr \
      coreutils \
      curl \
      git \
      gnupg \
      gzip \
      iputils-ping \
      less \
      mercurial \
      ssh-client \
      subversion \
      unzip \
      vim \
      wget

# Set up ssh server
EXPOSE 22
RUN apt-get install \
      openssh-server \

 # Delete the host keys it just generated. At runtime, we'll regenerate those
 && rm -f /etc/ssh/ssh_host_* \

 && mkdir -pv /var/run/sshd /root/.ssh \
 && chmod 0700 /root/.ssh

# init gpg keychain
RUN gpg --refresh-keys

# install newer version of GPG
COPY docker_runtime/gpg/install_gpg21.sh /tmp/install_gpg21.sh
RUN /tmp/install_gpg21.sh \
 && rm -rf /tmp/*

# Install Golang
ENV GOROOT=$PREFIX/go GOPATH=/opt/gopath
ENV PATH $GOROOT/bin:$PATH
RUN set -x \
 && version='1.7.1' sha256='43ad621c9b014cde8db17393dc108378d37bc853aa351a6c74bf6432c1bbd182' \
 && cd /tmp \
 && curl -L -o go.tgz "https://storage.googleapis.com/golang/go${version}.linux-amd64.tar.gz" \
 && shasum -a 256 go.tgz | grep -q "$sha256" \
 && mkdir -vp "$GOROOT" \
 && tar -xz -C "$GOROOT" --strip-components=1 -f go.tgz \
 && rm /tmp/go.tgz

RUN echo "export GOROOT=$GOROOT" >> /root/.profile \
 && echo "export GOPATH=$GOPATH" >> /root/.profile \
 && echo "export PATH=$GOPATH/bin:$GOROOT/bin:\$PATH" >> /root/.profile \
 && mkdir -p $GOPATH

# Install VIM
RUN set -x \
 && version='7.4.1087' \
 && apt-get update \
 && apt-get install \
      libacl1 \
      libc6 \
      libgpm2 \
      libncurses5-dev \
      libselinux1 \
      libssl-dev \
      libtcl8.6 \
      libtinfo5 \
      python-dev \

 && git clone -b "v${version}" https://github.com/vim/vim.git /opt/vim \
 && cd /opt/vim \
 && ./configure --with-features=huge --with-compiledby='docker@goodguide.com' \
 && make \
 && make install

# Install tmux
RUN set -x \
 && version='2.2' \
 && apt-get update \
 && apt-get install \
      automake \
      libevent-dev \
      pkg-config \
 && git clone -b "${version}" https://github.com/tmux/tmux.git /opt/tmux \
 && cd /opt/tmux \
 && ./autogen.sh \
 && ./configure \
 && make \
 && make install

# Install Docker-client
RUN set -x \
 && apt-key adv --keyserver 'hkp://p80.pool.sks-keyservers.net:80' --recv-keys '58118E89F3A912897C070ADBF76221572C52609D' \
 && echo 'deb https://apt.dockerproject.org/repo ubuntu-wily main' > /etc/apt/sources.list.d/docker.list \
 && apt-get update \
 && apt-get install docker-engine

# Install docker-compose
RUN set -x \
 && version='1.8.0' sha256='ebc6ab9ed9c971af7efec074cff7752593559496d0d5f7afb6bfd0e0310961ff' \
 && curl -L -o /tmp/docker-compose "https://github.com/docker/compose/releases/download/${version}/docker-compose-$(uname -s)-$(uname -m)" \
 && shasum -a 256 /tmp/docker-compose | grep -q "${sha256}" \
 && install -v /tmp/docker-compose "$PREFIX/bin/docker-compose-${version}" \
 && rm -vrf /tmp/* \
 && ln -s "$PREFIX/bin/docker-compose-${version}" "$PREFIX/bin/docker-compose"

# Install direnv
RUN set -x \
 && version='v2.9.0' \
 && git clone -b "${version}" 'http://github.com/direnv/direnv' "$GOPATH/src/github.com/direnv/direnv" \
 && cd "$GOPATH/src/github.com/direnv/direnv" \
 && make install

# install jq
COPY docker_runtime/gpg/jq_signing.key.pub.asc /tmp/
RUN set -x \
 && version='1.5' \
 && curl -m 10 -L -o /tmp/jq "https://github.com/stedolan/jq/releases/download/jq-${version}/jq-linux64" \
 && curl -L -o /tmp/jq.sig.asc "https://raw.githubusercontent.com/stedolan/jq/master/sig/v${version}/jq-linux64.asc" \
 && gpg --import /tmp/jq_signing.key.pub.asc \
 && gpg --verify /tmp/jq.sig.asc /tmp/jq \
 && install -v /tmp/jq "$PREFIX/bin/jq" \
 && rm -vfv /tmp/*

# install AWS CLI
RUN set -x \
 && apt-get update \
 && apt-get install python-pip \
 && rm -vrf /tmp/*

RUN pip install --upgrade pip
RUN set -x \
 && pip install \
      setuptools \
 && pip install \
      awscli \
      Pygments \
 && rm -vrf /tmp/*

# install latest release of thoughtbot's `pick` tool
RUN set -x \
 && version='1.4.0' \
 && curl -L -o /tmp/pick.tar.gz.sig.asc "https://github.com/thoughtbot/pick/releases/download/v${version}/pick-${version}.tar.gz.asc" \
 && curl -L -o /tmp/pick.tar.gz "https://github.com/thoughtbot/pick/releases/download/v${version}/pick-${version}.tar.gz" \
 && gpg --recv-keys 35689C84 \
 && gpg --verify /tmp/pick.tar.gz.sig.asc /tmp/pick.tar.gz \
 && tar -xvz -C /tmp -f /tmp/pick.tar.gz \
 && cd /tmp/pick-${version} \
 && ./configure \
 && make \
 && make install \
 && rm -vrf /tmp/*

# install goodguide-git-hooks
RUN set -x \
 && version='0.0.8' \
 && cd /tmp \
 && curl -L -o goodguide-git-hooks.tgz "https://github.com/GoodGuide/goodguide-git-hooks/releases/download/v${version}/goodguide-git-hooks_${version}_linux_amd64.tar.gz" \
 && curl -L -o goodguide-git-hooks.tgz.asc "https://github.com/GoodGuide/goodguide-git-hooks/releases/download/v${version}/goodguide-git-hooks_${version}_linux_amd64.tar.gz.asc" \
 && gpg --recv-keys E1B6700F \
 && gpg --verify goodguide-git-hooks.tgz.asc goodguide-git-hooks.tgz \
 && tar -xvzf goodguide-git-hooks.tgz \
 && install -v goodguide-git-hooks "$PREFIX/bin/" \
 && rm -vrf /tmp/*

# install forego
RUN go get -u -v github.com/ddollar/forego

# install hub
RUN set -x \
 && version='2.2.8' sha256='04f3d879ee0c41d6bdf0ada41b5defbda7b8af2c1fe496b188bd36088c4ff2cf' \
 && cd /tmp \
 && curl -L -o hub.tgz "https://github.com/github/hub/releases/download/v${version}/hub-linux-amd64-${version}.tgz" \
 && shasum -a 256 hub.tgz | grep -q "${sha256}" \
 && tar -xvzf hub.tgz \
 && cd hub-linux-amd64-${version}/ \
 && ./install \
 && rm -vrf /tmp/*

# install slackline to update Slack #status channel with /me messages
RUN go get -v github.com/davidhampgonsalves/slackline

# since these are some of the fastest installs, add a few more packges here at the end
RUN set -x \
 && apt-get update \
 && apt-get install \
      ack-grep \
      bind9-host \
      command-not-found \
      cowsay \
      dnsutils \
      exuberant-ctags \
      file \
      fortune-mod \
      fortunes-bofh-excuses \
      fortunes-debian-hints \
      fortunes-spam \
      htop \
      less \
      lolcat \
      man-db \
      manpages \
      mosh \
      net-tools \
      pass \
      psmisc \
      rsync \
      silversearcher-ag \
      tmux \
      tree \
      zsh

# mosh port
EXPOSE 60001/udp

# Set up some environment for SSH clients (ENV statements have no affect on ssh clients)
RUN echo "export DOCKER_HOST='unix:///var/run/docker.sock'" >> /root/.profile
RUN echo "export DEBIAN_FRONTEND=noninteractive" >> /root/.profile

# Set default shell to zsh
RUN usermod -s /usr/bin/zsh root

# add configuration for SSH and PAM (for SSH)
COPY etc/ssh/* /etc/ssh/
COPY etc/pam.d/* /etc/pam.d/

# use a volume for the SSH host keys, to allow a persistent host ID across container restarts
VOLUME ["/etc/ssh/ssh_host_keys"]

COPY docker_runtime/bin/* /usr/local/bin/
COPY docker_runtime/main.sh /usr/local/bin/run_sshd

CMD ["/usr/local/bin/run_sshd"]

# these volumes allow creating a new container with these directories persisted, using --volumes-from
VOLUME ["/code", "/root"]

ENV DOTFILES_PATH /root/.dotfiles

WORKDIR /root

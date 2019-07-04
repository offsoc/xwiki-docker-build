# ---------------------------------------------------------------------------
# See the NOTICE file distributed with this work for additional
# information regarding copyright ownership.
#
# This is free software; you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as
# published by the Free Software Foundation; either version 2.1 of
# the License, or (at your option) any later version.
#
# This software is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this software; if not, write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
# 02110-1301 USA, or see the FSF site: http://www.fsf.org.
# ---------------------------------------------------------------------------
FROM jenkins/ssh-slave

#    ____  ____  ____      ____  _   __        _
#   |_  _||_  _||_  _|    |_  _|(_) [  |  _   (_)
#     \ \  / /    \ \  /\  / /  __   | | / ]  __
#      > `' <      \ \/  \/ /  [  |  | '' <  [  |
#    _/ /'`\ \_     \  /\  /    | |  | |`\ \  | |
#   |____||____|     \/  \/    [___][__|  \_][___]

MAINTAINER XWiki Development Teeam <committers@xwiki.org>

# Install VNC + Docker CE
RUN apt-get update && \
  apt-get --no-install-recommends -y install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg2 \
    zip \
    software-properties-common

RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
RUN add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"
RUN apt-get update && \
  apt-get --no-install-recommends -y install \
    xfce4 xfce4-goodies xfonts-base tightvncserver docker-ce && \
  rm -rf /var/lib/apt/lists/* /var/cache/apt/*

# Install Firefox.
# Note: This won't be needed when we'll have all our functional tests use docker. However, as a transitional step,
# we should provide it, so that all agents can use this image to build XWiki fully.
ENV FIREFOX_VERSION 32.0.1
ENV FIREFOX_DOWNLOAD_URL="https://download-installer.cdn.mozilla.net/pub/firefox/releases/$FIREFOX_VERSION/linux-x86_64/en-US/firefox-$FIREFOX_VERSION.tar.bz2"
RUN apt-get update && \
  apt-get --no-install-recommends -y install libasound2 && \
  rm -rf /var/lib/apt/lists/* /var/cache/apt/* && \
  wget --no-verbose -O /tmp/firefox.tar.bz2 $FIREFOX_DOWNLOAD_URL && \
  rm -rf /opt/firefox && \
  tar -C /opt -xjf /tmp/firefox.tar.bz2 && \
  rm /tmp/firefox.tar.bz2 && \
  mv /opt/firefox /opt/firefox-$FIREFOX_VERSION && \
  ln -fs /opt/firefox-$FIREFOX_VERSION/firefox /usr/bin/firefox

WORKDIR /root


# Install the most recent version of Java8
RUN apt-get -y upgrade openjdk-8-jdk openjdk-8-jre-headless

# Add Zulu repository for Java7
# Instructions from https://docs.azul.com/zulu/zuludocs/#ZuluUserGuide/PrepareZuluPlatform/AttachAPTRepositoryUbuntuOrDebianSys.htm
# We're doing it at the beginning to avoid calling apt-get update several times.
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 0xB1998361219BD9C9
RUN echo 'deb http://repos.azulsystems.com/debian stable main' > /etc/apt/sources.list.d/zulu.list
RUN apt-get update && apt-get -y install zulu-7

# Copy VNC config files
COPY vnc/.Xauthority .Xauthority
COPY vnc/.vnc .vnc

# Generate a password for XVNC
RUN echo "jenkins" | vncpasswd -f > .vnc/passwd

# This is important as otherwise vncserver requires a password when started
RUN chmod 0600 .vnc/passwd

# Install Maven
RUN wget https://www-us.apache.org/dist/maven/maven-3/3.6.0/binaries/apache-maven-3.6.0-bin.tar.gz && \
  tar -xvzf apache-maven-3.6.0-bin.tar.gz && \
  rm apache-maven-3.6.0-bin.tar.gz

# ci.xwiki.org expects:
# - Java to be available at /home/hudsonagent/java8
# - Java7 to be available at /home/hudsonagent/java7
# - Maven to be available at /home/hudsonagent/maven
RUN mkdir -p /home/hudsonagent && \
 ln -fs /usr/lib/jvm/java-8-openjdk-amd64 /home/hudsonagent/java8 && \
 ln -fs /usr/lib/jvm/zulu-7-amd64 /home/hudsonagent/java7 && \
 ln -fs /home/hudsonagent/java8 /home/hudsonagent/java && \
 ln -fs /home/hudsonagent/java/bin/java /usr/bin/java && \
 ln -fs /root/apache-maven-3.6.0 /home/hudsonagent/maven && \
 echo '' >> ~/.bashrc && \
 echo 'export M2_HOME=/home/hudsonagent/maven' >> ~/.bashrc && \
 echo 'export PATH=${M2_HOME}/bin:${PATH}' >> ~/.bashrc

# Set up the Maven repository configuration (settings.xml)
RUN mkdir -p /root/.m2
COPY maven/settings.xml /root/.m2/settings.xml

ENV USER root
ENV JAVA_HOME /home/hudsonagent/java

COPY ssh/setup-xwiki-ssh /usr/local/bin/setup-xwiki-ssh
RUN chmod a+x /usr/local/bin/setup-xwiki-ssh

ENTRYPOINT ["setup-xwiki-ssh"]

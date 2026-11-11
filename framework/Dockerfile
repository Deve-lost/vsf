FROM ubuntu:20.04
ENV TZ=Europe/Berlin
ENV DEBIAN_FRONTEND noninteractive
ARG EXPERIMENT

# Set container timezone
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN apt-get update -y
RUN apt-get upgrade -y
RUN apt-get install -y build-essential software-properties-common libzmq3-dev
# libcurl4-openssl-dev provides curl-config, required to build the node-libcurl
# native binding (no prebuilt binary is published for some platforms, e.g. arm64)
RUN apt-get install -y libcurl4-openssl-dev
RUN apt-get install cmake -y
RUN apt-get install xvfb -y

# Create directory for crawler source & crawler data path
RUN mkdir -p /crawler
RUN mkdir -p /crawler-data
# RUN mkdir -p /foxhound

# Install VNC and fluxbox to interact with headfull runs
RUN apt-get install -y x11vnc fluxbox gnome-terminal dbus-x11 xclip dialog

# Install database client
RUN apt-get install -y postgresql-client

# Install python3 and 
RUN apt-get install -y python3.10 python3-pip
# Install dependencies for pmsecurity experiment (pmforce)
# RUN pip3 install z3-solver==4.8.7.0 ply

# RUN apt add --no-cache build-base libffi-dev openssl-dev python-dev curl krb5-dev linux-headers zeromq-dev

# === INSTALL Node.js ===

RUN apt-get update && \
    # Install Node.js
    apt-get install -y curl wget gpg ca-certificates && \
    mkdir -p /etc/apt/keyrings && \
    curl -sL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" >> /etc/apt/sources.list.d/nodesource.list && \
    apt-get update && \
    apt-get install -y nodejs && \
    # Feature-parity with node.js base images.
    apt-get install -y --no-install-recommends git openssh-client && \
    npm install -g yarn && \
    # clean apt cache
    rm -rf /var/lib/apt/lists/* && \
    # Create the pwuser
    adduser pwuser

# Playwright dependencies
RUN apt-get update
RUN  apt-get -y install libevent-2.1-7\            
         libflite1\                                          
         gstreamer1.0-libav 

# Install Node global packages
RUN npm install -g typescript@5.5.4
RUN npm install -g ts-node@10.9.2

# ========= Playwright dependencies and install ==========
COPY ./playwright/ /playwright
WORKDIR /playwright
RUN npm ci
RUN npm run build

# link the manually added libraries
WORKDIR /playwright/playwright-mirror
RUN npm link /playwright/packages/playwright-core
RUN npm link /playwright/packages/playwright
RUN npm i


# ========= Create user and install project before copying source code
RUN mkdir /crawler -p
COPY ./crawler/package.json /crawler/package.json
COPY ./crawler/package-lock.json /crawler/package-lock.json
WORKDIR /crawler

# Add unprivileged user
RUN useradd -ms /bin/bash crawler

# Change ownership of relevant files for crawler to new user
RUN chown -R crawler /crawler 
RUN chown -R crawler /crawler-data 
USER crawler

# Install browsers
RUN npx playwright install

# Switch back to root user to copy source code
USER root

# Install project dependencies
RUN npm i

WORKDIR /

# ========== Add tools for the analysis ==========
# Pick the .deb matching the build architecture (e.g. arm64 on Apple Silicon hosts).
# Only the glibc-linked build is published for arm64, so use that variant for all archs.
RUN ARCH=$(dpkg --print-architecture) && \
    wget https://github.com/dandavison/delta/releases/download/0.17.0/git-delta_0.17.0_${ARCH}.deb && \
    dpkg -i git-delta_0.17.0_${ARCH}.deb && \
    rm git-delta_0.17.0_${ARCH}.deb

# install ansifilter for delta-->html
RUN wget http://andre-simon.de/zip/ansifilter-2.20.tar.bz2
RUN tar -xvf ansifilter-2.20.tar.bz2
WORKDIR /ansifilter-2.20
RUN make help
RUN make
RUN make install
RUN make clean
WORKDIR /
RUN rm -rf /ansifilter-2.20
RUN rm ansifilter-2.20.tar.bz2

RUN mkdir /analysis

# Python requirements
COPY ./analysis/requirements.txt /analysis/requirements.txt
# braveblock publishes no linux/aarch64 wheel (e.g. Apple Silicon hosts), so
# install everything else first and let braveblock fail non-fatally there;
# prefilter.py falls back to a no-op adblocker when it's missing.
RUN grep -v '^braveblock' /analysis/requirements.txt > /tmp/requirements-no-braveblock.txt && \
    pip3 install -r /tmp/requirements-no-braveblock.txt && \
    (pip3 install braveblock==0.5.1 || echo "braveblock unavailable for this platform, skipping (ad-block prefiltering will be a no-op)")
RUN apt-get install -y vim

# Analysis source
COPY ./analysis /analysis
RUN chown -R crawler /analysis
RUN chmod +x /analysis/analysis.sh

# ========= Copy project source ==========
COPY ./crawler /crawler
COPY ./misc /misc

# Go back to crawler directory
WORKDIR /crawler 

# Make entrypoint script executable
RUN chmod +x entrypoint.sh
RUN chmod +x entrypoint-unprivileged.sh

# Make required experiment scripts executable
RUN chmod +x experiment-stop.sh
RUN chmod +x experiment-join.sh
RUN chmod +x experiment-list.sh
RUN chmod +x experiment.sh

RUN chmod +x src/setup/prepare.sh 
RUN chmod +x src/setup/spawn.sh

# Update workdir
WORKDIR /crawler 

# Start entrypoint script, which starts Xvfb and opens VNC session
ENTRYPOINT ["/bin/bash", "/crawler/entrypoint.sh"]
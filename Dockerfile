FROM buildpack-deps:bionic

# avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# Set up locales properly
RUN apt-get -qq update && \
    apt-get -qq install --yes --no-install-recommends locales > /dev/null && \
    apt-get -qq purge && \
    apt-get -qq clean && \
    rm -rf /var/lib/apt/lists/*

RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen

ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8

# Use bash as default shell, rather than sh
ENV SHELL /bin/bash

# Set up user
ARG NB_USER
ARG NB_UID
ENV USER ${NB_USER}
ENV HOME /home/${NB_USER}

RUN adduser --disabled-password \
    --gecos "Default user" \
    --uid ${NB_UID} \
    ${NB_USER}

RUN wget --quiet -O - https://deb.nodesource.com/gpgkey/nodesource.gpg.key |  apt-key add - && \
    DISTRO="bionic" && \
    echo "deb https://deb.nodesource.com/node_10.x $DISTRO main" >> /etc/apt/sources.list.d/nodesource.list && \
    echo "deb-src https://deb.nodesource.com/node_10.x $DISTRO main" >> /etc/apt/sources.list.d/nodesource.list

# Base package installs are not super interesting to users, so hide their outputs
# If install fails for some reason, errors will still be printed
RUN apt-get -qq update && \
    apt-get -qq install --yes --no-install-recommends \
       less \
       nodejs \
       unzip \
       > /dev/null && \
    apt-get -qq purge && \
    apt-get -qq clean && \
    rm -rf /var/lib/apt/lists/*

EXPOSE 8888

# Environment variables required for build
ENV APP_BASE /srv
ENV NPM_DIR ${APP_BASE}/npm
ENV NPM_CONFIG_GLOBALCONFIG ${NPM_DIR}/npmrc
ENV CONDA_DIR ${APP_BASE}/conda
ENV NB_PYTHON_PREFIX ${CONDA_DIR}/envs/notebook
ENV KERNEL_PYTHON_PREFIX ${NB_PYTHON_PREFIX}
# Special case PATH
ENV PATH ${NB_PYTHON_PREFIX}/bin:${CONDA_DIR}/bin:${NPM_DIR}/bin:${PATH}
# If scripts required during build are present, copy them

#COPY conda/install-miniconda.bash /tmp/install-miniconda.bash
RUN wget https://astro.uni-bonn.de/~ocordes/repo2docker/install-miniconda.bash -O /tmp/install-miniconda.bash

#COPY conda/activate-conda.sh /etc/profile.d/activate-conda.sh
RUN wget https://astro.uni-bonn.de/~ocordes/repo2docker/activate-conda.sh -O /etc/profile.d/activate-conda.sh

#COPY conda/environment.frozen.yml /tmp/environment.yml
RUN wget https://astro.uni-bonn.de/~ocordes/repo2docker/environment.frozen.yml -O /tmp/environment.yml

RUN mkdir -p ${NPM_DIR} && \
chown -R ${NB_USER}:${NB_USER} ${NPM_DIR}

USER ${NB_USER}
RUN npm config --global set prefix ${NPM_DIR}

USER root
RUN bash /tmp/install-miniconda.bash && \
rm /tmp/install-miniconda.bash /tmp/environment.yml



# Allow target path repo is cloned to be configurable
ARG REPO_DIR=${HOME}
ENV REPO_DIR ${REPO_DIR}
WORKDIR ${REPO_DIR}

# We want to allow two things:
#   1. If there's a .local/bin directory in the repo, things there
#      should automatically be in path
#   2. postBuild and users should be able to install things into ~/.local/bin
#      and have them be automatically in path
#
# The XDG standard suggests ~/.local/bin as the path for local user-specific
# installs. See https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html
ENV PATH ${HOME}/.local/bin:${REPO_DIR}/.local/bin:${PATH}

# Copy and chown stuff. This doubles the size of the repo, because
# you can't actually copy as USER, only as root! Thanks, Docker!
USER root
COPY . ${REPO_DIR}
RUN chown -R ${NB_USER}:${NB_USER} ${REPO_DIR}

# fix the BUG in Ubuntu bionic image
RUN sed -i '/path-exclude=\/usr\/share\/man\/*/c\#path-exclude=\/usr\/share\/man\/*' /etc/dpkg/dpkg.cfg.d/excludes && \
  apt-get -qq update && \
  apt-get install --yes --no-install-recommends man manpages-posix && \
  dpkg -l | grep ^ii | cut -d' ' -f3 | xargs apt-get install -y --reinstall && \
  apt-get -qq purge && \
  apt-get -qq clean


# Run assemble scripts! These will actually build the specification
# in the repository into the image.
RUN test -f ${REPO_DIR}/apt.txt && apt-get -qq update && \
apt-get install --yes --no-install-recommends `cat ${REPO_DIR}/apt.txt` && \
apt-get -qq purge && \
apt-get -qq clean && \
rm -rf /var/lib/apt/lists/*


# Add start script
# Add entrypoint
#COPY /repo2docker-entrypoint /usr/local/bin/repo2docker-entrypoint
RUN wget https://astro.uni-bonn.de/~ocordes/repo2docker/repo2docker-entrypoint -O /usr/local/bin/repo2docker-entrypoint
RUN chmod 755 /usr/local/bin/repo2docker-entrypoint

USER ${NB_USER}
#RUN conda env update -p ${NB_PYTHON_PREFIX} -f "environment.yml" && \
#conda clean -tipsy && \
#conda list -p ${NB_PYTHON_PREFIX} && \
#rm -rf /srv/conda/pkgs
RUN pip install --no-cache-dir -r requirements.txt

# This is an image from ocordes

# We always want containers to run as non-root
USER ${NB_USER}

ENTRYPOINT ["/usr/local/bin/repo2docker-entrypoint"]

# Specify the default command to run
CMD ["jupyter", "notebook", "--ip", "0.0.0.0"]

# bash_binder_test

A repository to test the BinderHub integration of a Jupyter notebook
with a `bash`-kernel.

## Test with binderhub
Please click [![Binder](https://binderhub.astro.uni-bonn.de/badge_logo.svg)](https://binderhub.astro.uni-bonn.de/v2/gh/terben/bash_binder_test/master) to test this repository within binderhub.

## The binderhub-setup
We setup a manual Dockerfile for the bash--container (see `binder`-subdirectory)
because the standard binderhub-setup does not allow to integrate `man`-pages
into containers.

## Local notebook creation
To create the notebook on my local computer, I did:

- `Anaconda`-Install of `Python 3.7`
- `pip install calysto_bash`
- create the notebook with the `bash`-kernel

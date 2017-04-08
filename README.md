# talend_distro

Bash scripts to download Talend distribution files to local storage.

* Use an S3Fuse or similar mounting tool to use Cloud Storage.
* Alternatively run this from Dockerfile or from a Docker tool container and save to a Docker Data Container.

Bash scripts to (re)package Talend Jobs for use in containers.

* Manifest downloads multiple Talend Jobs from Nexus, unzips, and merges thems
* Each Job launch script is modified to use `exec` so that Talend Jobs run as PID 1

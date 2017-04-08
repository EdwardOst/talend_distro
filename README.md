# talend_distro

Bash scripts to download Talend distribution files to local storage.

* Use an S3Fuse or similar mounting tool to use Cloud Storage.
* Alternatively run this from Dockerfile or from a Docker tool container and save to a Docker Data Container.

Bash scripts to configure 

Bash scripts to (re)package Talend Jobs for use in containers.

* Manifest downloads multiple Talend Jobs from Nexus, unzips, and merges thems
* Each Job launch script is modified to use `exec` so that Talend Jobs run as PID 1

Index

| File                    |  Description                                               |
:------------------------:|:----------------------------------------------------------:|
| job_manifest.cfg        | sample manifest file used by test-talend-packager          |
| LICENSE                 | Apache license                                             |
| parse-url.sh            | utility to parse a url returns a bash dictionary           |
| README.md               |                                                            |
| repo.sh                 | utility wrapper for using wget                             |
| talend-6.2.1.cfg        | download manifest for Talend packages                      |
| talend-packager.sh      | repackage Talend Jobs for use with Docker                  |
| talend-tomcat.sh        | download Apache Tomcat and upload to local nexus repo      |
| test_nexus_wget.sh      | test sandbox for wget interaction wth nexus                |
| test-parse-url          | test parse-url script                                      |
| test-repo               | test repo script                                           |
| test-talend-packager    | test talend-packager script                                |
| test-talend-tomcat      | test tomcat download                                       |
| util.sh                 | common bash utilities                                      |
|-------------------------|------------------------------------------------------------|


# talend_distro

### util

shared bash script utilities.

### talend-6.2.1

Bash scripts to download Talend distribution files to local storage.

* Use an S3Fuse or similar mounting tool to use Cloud Storage.
* Alternatively run this from Dockerfile or from a Docker tool container and save to a Docker Data Container.

### apache

Bash scripts to download Apache products used by Talend, e.g. Tomcat

### packager

Bash scripts to (re)package Talend Jobs for use in containers.

* Manifest downloads multiple Talend Jobs from Nexus, unzips, and merges them
* Each Job launch script is modified to use `exec` so that Talend Jobs run as PID 1

### talend-job

sample talend job image


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

### Talend Docker Workflow

These directions assume you have an enterprise Talend subscription and that you have correctly configured Talend Studio to use the Talend Artifact Repository (i.e Nexus).

The workflow is fairly simple.  All work is done on Linux.  I have used Ubuntu.  
Your linux machine will need Docker installed.
The Talend Studio steps can be run in any environment.
In my case I ran Studio on my Windows laptop and published to Nexus.
From there I ran the scripts in this project on an Ubuntu image running in a VirtualBox VM.
You can clone the files from github, or just download the zip file of the repo.
The sample scripts are available on github `https://github.com/EdwardOst/talend_distro` .

1.  Select Publish Job from the Talend Studio to create a Talend job zip file.
2.  Create a manifest file for use by the Talend container packager.
3.  Run the packager.
4.  Invoke the Talend build script to create the Talend image.
5.  Invoke the Talend run script to run the resulting container.

Publish the job to Nexus by right clicking and using the context menu in Talend Studio.

Get the URL of your published zip file from Nexus.

If necessary, switch to your linux VM and clone this github repo.

    git clone https://github.com/EdwardOst/talend_distro.git

Now go to the `talend_distro/test` directory and edit the `job_manifest.cfg` file.
It should have one entry in it which is the url of your published job.
Edit the url if necessary to reflect the url you got from Nexus.  Save the file.

Still in the `talend_distro/test directory`, run the `test-talend-packager` script.
This should retrieve the published job zip file from Nexus, unzip, modify it, and compress in tgz format before publishing it back to Nexus.
 
Change to the `talend_distro/talend-job` directory and run the build script.
The build script will create your docker image.  It is very simple.

    docker build --no-cache -t eost/create_customer:0.1 .

The Dockerfile inherits the `anapsix` base image which is already populated with Oracle JDK.
It then downloads the packaged Talend jobs from Nexus and uzips it.
It then copies a lookup table needed to the `/talend/in directory`.
Strictly speaking, the lookup table is not needed since the run command below mounts a host directory over the container `/talend/in` directory.
You could just copy the lookup table the host directory.
But it is included in the example so that the example can run independently in EC2 without any extra parameters in your task.

Although the script will accept arguments, you can just use the defaults.
You may wish to change the default image tag to use your own id rather than "eost", but it is not required.
The script just calls the Docker `run` command and uses Docker `volumes` to mount host directories in the container.
  
The style of use of the container follows common industry practice in using Docker volumes to support immutable containers for the different runtime aspects.
This means that different volumes are used to provision and isolate data used by the containerized job.

* data – for persistent data required by the container, survives restarts, is read-write
* log – for log files only, persistent, is write-only
* temp – for temporary files, transient and can always be deleted prior to the container (re)start, read-write
* config – for configuration files that must be injected for the container to work properly, persistent, read-only

I have attached these volumes to host files so that we can see the resulting output and verify that things ran successfully.  In practice you might well use other Docker data containers for this purpose.

If you choose to run this in EC2 Container Services, then the steps that write to S3 will persist the output so that you can tell whether it ran successfully.

What this also means is that you need to mount your S3 credentials via the context.txt file in the config volume.


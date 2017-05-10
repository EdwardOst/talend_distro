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
The sample scripts are available on github `https://github.com/EdwardOst/talend_distro` .
You can clone the files from github, or just download the zip file of the repo.

In my case I ran Studio on my Windows laptop and published to Nexus.
From there I ran the scripts in this project on an Ubuntu image running in a VirtualBox VM.

1.  Import the sample job found in the `talend_distro/sample_job` directory into Talend Studio. 
2.  Select Publish Job from the Talend Studio to create a Talend job zip file.
3.  Create a manifest file for use by the Talend container packager.
4.  Create your local Context Variable configuration file with S3 credentials.
5.  Invoke the packager.
6.  Invoke the build script to create the Talend Docker image.
7.  Invoke the Talend run script to create and execute a container.

Publish the job to Nexus by right clicking and using the context menu in Talend Studio.

![publish job](pictures/01_publish_job.png)

Get the URL of your published zip file from Nexus.

![get nexus job url](pictures/02_nexus_get_job_url)

If necessary, switch to your linux VM and clone this github repo.

    git clone https://github.com/EdwardOst/talend_distro.git

Now go to the `talend_distro/sample_job` directory and edit the `job_manifest.cfg` file.
It should have one entry in it which is the url of your published job.
Edit the url if necessary to reflect the url you got from Nexus.  Save the file.

You should still be in the `talend_distro/sample_job` directory.
Run the `package` script.
This should retrieve the published job zip file from Nexus, unzip, modify it, and compress in tgz format before publishing it back to Nexus.
 
You should still be in the `talend_distro/sample_job` directory.
Run the `build` script.
It is a symbolic link to a script in the image subdirectory.

The Dockerfile inherits the `anapsix` base image which is already populated with Oracle JDK.
It then downloads the packaged Talend jobs from Nexus and uzips it.
It then copies a lookup table needed to the `/talend/in directory`.
Strictly speaking, the lookup table is not needed since the run command below mounts a host directory over the container `/talend/in` directory.
You could just copy the lookup table the host directory.
But it is included in the example so that the example can run independently in EC2 Container Services (ECS) without any extra parameters in your ECS Task definition.
The default image tag will be use your linux user.  You may wish to change this if you are logged in as root, but it is not required.


The style of use of the container follows common industry practice in using Docker volumes to support immutable containers for the different runtime aspects.
This means that different volumes are used to provision and isolate data used by the containerized job.  For example:

* data – for persistent data required by the container, survives restarts, is read-write
* log – for log files only, persistent, is write-only
* temp – for temporary files, transient and can always be deleted prior to the container (re)start, read-write
* config – for configuration files that must be injected for the container to work properly, persistent, read-only

In this simplictic example all volumes are mounted to the host directories  `~/in` or `~/out`.  These correspond to the `/talend/in` and `/talend/out` directories within the container.

I have attached these volumes to host files so that we can see the resulting output and verify that things ran successfully.  In practice you might well use other Docker data containers for this purpose.

The job itself also writes to S3.  
This means you need to provide your S3 credentials via Context variables.
Since Context variables in Job are not secure, the job uses tContextLoad to read the Context Variables from the `~/in/context.txt` file.
This file does not exist in github since it is sensitive, so you will need to create it.

Edit the `~/in/context.txt` file as shown below.

    connection_awss3_secret_key=your_s3_secret
    connection_awss3_access_key=your_s3_access_key

You are now ready to launch the container.  Still in the `talend_distro/sample_job` directory, invoke the `run` script.  This script uses the Docker `run` command along with Docker volumes to mount host directories in the container.

When you run the container the Talend Job will run as PID 1.  When the Talend Job is finished running it will end and the container will shut down.

If you do not wish to write to S3 then just edit the sample job.

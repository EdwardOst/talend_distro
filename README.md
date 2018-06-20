# Talend Container Factory

This repository includes sample bash scripts which allow you to deploy Talend jobs to Docker containers.

Two methods are supported.  The first job2docker approach converts a single Talend job zip file to a container.
The resulting Docker image will have a single entry point for the job.
It is intended for use by developers during their build / test / debug cycle and provides desktop parity.

The second Manifest based approach reads a file with links to one or more Talend jobs to create a docker image.
All jobs in the manifest must have been published to your Talend Nexus repository.
The resulting Docker image requires users to provide the Docker CMD to run the desired job.

* [Pre-requisites](#pre-requisites)
* [Environment](#environment)
* [Directory Index](#directory-index)
* [Design Overview](#design-overview)
    * [Job2Docker Design](#job2docker-design)
    * [Manifest Design](#manifest-design)
* [Getting Started](#getting-started)
    * [HelloWorld with Job2Docker](#helloworld-with-job2docker)
* [Sample Jobs](#sample-jobs)
    * [Setup](#setup)
    * [Running the Sample Jobs in Docker](#running-the-sample-jobs-in-docker)
    * [Running the Sample Jobs in AWS](#running-the-sample-jobs-in-aws)
    * [Running the Sample Jobs in Azure](#running-the-sample-jobs-in-azure)
    * [Sample Job Design](#sample-job-design)


### Pre-Requisites

* Talend enterprise subscription
* Talend Studio
* Talend Artifact Repository for the manifest based approach
* Docker
* Basic knowledge of Docker
* Bash 4.3 - supporting scripts use a nameref feature


### Environment

* All containerization work is done on Linux with Docker installed.
* Talend Studio steps can run on a separate machine if desired, it could be a Windows machine.
* For the manifest based approach Both Linux and Studio machines need access to a Nexus instance provided with a Talend enterprise subscription.
* For the job2docker approach, a common drop point (shared directory, shared network drive, shared folder) for Jobs built from Studio for the job2docker approach.

* The environment used to test these scripts was a Windows laptop running Studio and Nexus.
* The docker script were run on an Ubuntu VM running on the same Windows laptop.
* VirtualBox was used for the VM hosting.
* A shared folder was created using VirtualBox so that Studio builds would be visible to the Linux VM.


### Directory Index

* bin - scripts for creating docker images, creating containers, and deploying images to the cloud
* job2docker - working directory for running the agent that monitors the build directory for Talend zip files
* job2docker_build - sample Dockerfile used to create Docker image containing the Talend job
* manifest_build - docker build artifacts for manifest based build
* pictures - jpg files used in this readme
* sample_job - scripts for step-by-step walkthrough
* util - utility bash scripts

### Design Overview

The job2docker and manifest based approaches are intended to compliment each other.
Job2docker provides a simple mechanism for developers to automate builds of containers from their Studio.
It is intended to run locally for a single developer.

In contrast, the manifest based approach allows a set of jobs to be released as a unit.
This allows but does _not_ ensure a consistent set of metadata, configuration, and supporting artifacts delivered by the manifest based Docker image.

In a true CI/CD environment the set of Jobs in the manifest would ideally be built from scratch and then packaged with these scripts.
That would ensure consistency of the artifacts within the Image which would then become the single point of control in the chain of custody.

Either manifest or job2docker can be incorporated into a CI build environment.
The advantage of the manifest approach is it leverages the Nexus infrastruxture so it can be easily combined with standard Talend CI.
Since the CI build script is presumably running on a CI server local to Nexus and the SCM it will create a Docker image and supporting artifacts closer to the Nexus repository and Docker registry so there will be less network overhead than transferring from a laptop.

When running multiple jobs within a single container there can be collisions in some Talend configuration files.
This is addressed by the packaging step in the Manifest approach.
While not strictly necessary for the job2docker approach (since there is just a single Job), the same packaing structure is used to ensure consistency between developer and CI images.

### Job2Docker Design

1.  A Talend job2docker_listener job is used to monitor a shared directory.
2.  The developer clicks Build in Talend Studio to create Talend job zip file in the shared directory.
3.  The Talend `job2docker_listener` triggers the `job2docker` script to convert the Talend zip file to a tgz ready for Docker.
4.  The Talend `job2docker_listener` triggers the `job2docker_build` script.
5.  The Talend `job2docker_listener` optionally publishes the resulting container to a Docker Registry.

### Manifest Design

1.  Download Talend Jobs from Nexus based on the Manifest.
2.  Unzip and merge jobs to avoid collisions
3.  Modify each Job launch script to use `exec` so that Talend Jobs run as PID 1
4.  Repackage as a tgz preserving privileges
5.  Publish back to Nexus
6.  Build a Docker image with job entry points
7.  Deploy Docker image


### Getting Started

#### HelloWorld with Job2Docker

1.  Download scripts
2.  Create a shared directory
3.  Start job2docker_listener
4.  Build helloworld job to shared directory
5.  Run helloworld job container
6.  Run helloworld job container with context parameters

See [HelloWorld with Job2Docker Step-by-Step](helloworld-with-job2docker.md) for details

#### Passing Parameters with Implicit Context Load from File

1.  Create a sample parameter file
2.  Modify HelloWorld to use implicit context load from file
3.  Test HelloWorld in Studio
4.  Create a parameter directory for volume mount point
5.  Copy sample parameter file to parameter directory
5.  Rebuild HelloWorld image
6.  Run helloworld job container with mount point

#### Passing Parameters with Implicit Context Load from Database

This step requires a database that is accessible from the Docker container.

1.  Create database tables to hold parameters
2.  Populate database with sample parameters
3.  Modify HelloWorld to use implicit context load from database
4.  Test HelloWorld in Studio
5.  Rebuild HelloWorld image
6.  Run helloworld job with parameter group id

#### Separating Configuration from Parameters

1.  Create database tables to hold configuration
2.  Populate database with sample configuration
3.  Modify HelloWorld to use impllicit context load for both parameters and configuration
4.  Test HelloWorld in Studio
5.  Rebuild HelloWorld image
6.  Run helloworld job with parameter group id

#### HelloWorld with Manifest

1.  Modify Nexus to accept non-maven artifacts
2.  Publish Helloworld to Nexus from Studio
3.  Modify manifest
4.  Run package command
5.  Run build command
6.  Run helloworld job container
7.  Run helloworld job container with context parameters

### Sample Jobs

(work in progress)

Slightly more advanced sample jobs are provided in the sample_job/jobs directory.
The sample jobs are used to illustrate the use of some basic Docker practices like creating immutable containers.
The sample jobs are also set up to run in a Cloud environment so they use Cloud storage.
As a result, additional steps are required to configure Cloud credentials.
When jobs are run in the Cloud, the container can inherit permissions from the hosting EC2 instance.
But when run locally things need to be configured.  So this adds some complexity.

* t0_docker_create_customer
* t1_docker_create_customer_aws
* (tbd) t2_docker_create_customer_az
* t3_docker_tmap_customer
* (tbd) t4_docker_tmap_customer_aws
* (tbd) t5_docker_tmap_customer_az

### Setup

Configuration is externalized outside the SCM directory tree.

Run the following command

````bash
sample_jobs/setup/init
````

This will initialize `TALEND_DOCKER_HOME` in `${HOME}/talend/docker` as the root of your work area.
It will be populated with default config files for the sample jobs.

````
${HOME}/talend
└── docker
    ├── config
    │   └── global.cfg
    ├── SE_DEMO
    │   ├── config
    │   │   └── project.cfg
    │   └── talend_sample_container_app
    │       ├── in
    │       │   └── states.csv
    │       ├── t0_docker_create_customer
    │       │   └── config
    │       │       └── job.cfg
    │       ├── t0_docker_create_customer_s3
    │       │   └── config
    │       │       └── job.cfg
    │       └── t3_docker_tmap_customers
    │           └── config
    │               └── job.cfg
    └── talend-docker.env
````

Edit the `docker/config/global.cfg` file with your AWS access and secret key.
The file permissions should already be limited to -rw for the current user, but doublechck.

The scripts for building docker images publish files to Nexus which do not conform to the strict maven filename conventions.
Set the Nexus 3 Layout policy to permissive for the Snapshots repository.

![get nexus job url](pictures/03_nexus_3_permissive.png)


### Running the Sample Jobs in Docker

1.  Import the sample job found in the `sample_job/jobs` directory into Talend Studio. 
2.  Select Publish Job from the Talend Studio to create a Talend job zip file.
3.  Create a manifest file for use by the Talend container packager.
5.  Invoke the packager.
6.  Invoke the build script to create the Talend Docker image.
7.  Invoke the run script to create and execute a container.

Import the `t0_docker_create_customer.zip` sample job from `sample_job/jobs` directory.

![import_job](pictures/00_import_job_a.png)

Publish the job to Nexus by right clicking and using the context menu in Talend Studio.

![publish job](pictures/01_publish_job.png)

Get the URL of your published zip file from Nexus.

![get nexus job url](pictures/02_nexus_get_job_url.png)

Now go to the `sample_job` directory and edit the `job_manifest.cfg` file.
It should have one entry in it which is the url of your published job.
Edit the url if necessary to reflect the url you got from Nexus.  Save the file.

Repeat this process for any sample jobs of interest.  Remove or comment out other manifest entries.

You should still be in the `sample_job` directory.
Run the `d01-package` script.  It is a symbolic link to a script in the /bin directory.
This should retrieve the published job zip file from Nexus, unzip, modify it, and compress in tgz format before publishing it back to Nexus.
 
You should still be in the `sample_job` directory.
Run the `d02-build` script.  It is a symbolic link to a script in the image subdirectory.
This should create a docker image in the local docker registry.

The Dockerfile inherits the `anapsix` base image which is already populated with Oracle JDK.
It then downloads the packaged Talend jobs from Nexus and uzips it.
It copies a lookup table needed to the `/talend/in directory`.
Strictly speaking, the lookup table is not needed since the run command below mounts a host directory over the container `/talend/in` directory.
You could just copy the lookup table to the host directory.
But it is included in the example so that the example can run independently in the Cloud without any extra parameters in your ECS Task definition.
The default image tag will use your linux user name.  You may wish to change this if you are logged in as root, but it is not required.

#### Running the Sample Jobs in AWS

The job itself also writes to S3.  
This means you need to provide your S3 credentials via Context variables.
Since Context variables in Job are not secure, the job uses tContextLoad to read the Context Variables from the `~/in/context.txt` file.
This file does not exist in github since it is sensitive, so you will need to create it.

Edit the `~/in/context.txt` file as shown below.

    connection_awss3_secret_key=your_s3_secret
    connection_awss3_access_key=your_s3_access_key

You are now ready to launch the container.  Still in the `sample_job` directory, invoke the `run` script.  This script uses the Docker `run` command along with Docker volumes to mount host directories in the container.

When you run the container the Talend Job will run as PID 1.  When the Talend Job is finished running it will end and the container will shut down.

If you do not wish to write to S3 then just edit the sample job.

#### Running the Sample Jobs in Azure

#### Sample Job Design

The sample jobs attempt to illustrate some common practices in using Docker volumes to support immutable containers for different runtime aspects.
Different volumes are used to provision and isolate data used by the containerized job.

* job-root/config (ro) – configuration files common to all job instances
* job-instance/config (ro) – configuration files specific to this job instance
* in (ro) - input data
* data (rw) – data required by the container, survives restarts
* log (w) – log files
* amc (w) - activity monitor console log files
* out (rw) - output data
* temp (rw) – transient and can always be deleted prior to the container (re)start

The volume mounts are addressed when launching containers with the Docker Run command rather than in the Docker Image build.
As a result, this has no impact on the Manifest or job2docker approach.  It a container issue rather than an image issue.

The sample jobs include a custom run script which attaches these volumes to host files so that the resulting output is visible.

The sample jobs use volumes for sensitive data.  While it separated from less sensitive configuraiton data, this is not best practice.
A preferred approach would be to use [Kubernetes Service Catalog](https://kubernetes.io/docs/concepts/service-catalog/)


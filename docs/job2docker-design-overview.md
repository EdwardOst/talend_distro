# Job2Docker Design Overview

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


## Job2Docker Design

1.  A Talend job2docker_listener job is used to monitor a shared directory.
2.  The developer clicks Build in Talend Studio to create Talend job zip file in the shared directory.
3.  The Talend `job2docker_listener` triggers the `job2docker` script to convert the Talend zip file to a tgz ready for Docker.
4.  The Talend `job2docker_listener` triggers the `job2docker_build` script.
5.  The Talend `job2docker_listener` optionally publishes the resulting container to a Docker Registry.

## Manifest Design

1.  Download Talend Jobs from Nexus based on the Manifest.
2.  Unzip and merge jobs to avoid collisions
3.  Modify each Job launch script to use `exec` so that Talend Jobs run as PID 1
4.  Repackage as a tgz preserving privileges
5.  Publish back to Nexus
6.  Build a Docker image with job entry points
7.  Deploy Docker image


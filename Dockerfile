# Use a Red Hat UBI base image
FROM registry.access.redhat.com/ubi8/ubi:latest

# Define the user and group IDs used in the original failing pod
ARG CUSTOM_USER_ID=1000690000
ARG CUSTOM_GROUP_ID=103000

# 1. Create the custom user and group (used by the Pod security context)
RUN groupadd -g ${CUSTOM_GROUP_ID} customgroup && \
    useradd -u ${CUSTOM_USER_ID} -g ${CUSTOM_GROUP_ID} -m -s /bin/bash customuser

# 2. Create the source directory and content that the 'cp' command tries to copy
# This simulates the internal data the pod needs to copy to the volume.
RUN mkdir -p /cc-home-content/_global_

# 3. Create the entrypoint script to execute the problematic command
RUN echo "#!/bin/sh" > /entrypoint.sh && \
    echo "set -ex" >> /entrypoint.sh && \
    echo "" >> /entrypoint.sh && \
    echo "echo 'Executing cp command that will fail due to Permission Denied:'" >> /entrypoint.sh && \
    echo "cp -rpu /cc-home-content/_global_ /cc-home/" >> /entrypoint.sh && \
    echo "if [ \$? -ne 0 ]; then echo 'Command failed as expected.'; fi" >> /entrypoint.sh && \
    # Keep the container running so the Deployment doesn't immediately exit
    echo "sleep 3600" >> /entrypoint.sh && \
    chmod +x /entrypoint.sh

# 4. Set the container to run as the custom user
# This is the key step that causes the Permission Denied error when combined with the missing fsGroup in the Pod spec.
USER ${CUSTOM_USER_ID}

# Set the entrypoint
ENTRYPOINT ["/entrypoint.sh"]

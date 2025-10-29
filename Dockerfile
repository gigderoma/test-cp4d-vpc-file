# Use a Red Hat UBI base image
FROM registry.access.redhat.com/ubi8/ubi:latest

# Define the user and group IDs used in the original failing pod
# runAsUser: 1000690000 (Custom User ID)
# runAsGroup: 103000 (Custom Group ID)
ARG CUSTOM_USER_ID=1000690000
ARG CUSTOM_GROUP_ID=103000

# 1. Create the custom group and user
RUN groupadd -g ${CUSTOM_GROUP_ID} customgroup && \
    useradd -u ${CUSTOM_USER_ID} -g ${CUSTOM_GROUP_ID} -m -s /bin/bash customuser

# 2. Create the source directory and content that the 'cp' command tries to copy
# This simulates the /cc-home-content directory from the original image
RUN mkdir -p /cc-home-content/_global_/security/customer-keystores && \
    echo "Dummy Keystore Content" > /cc-home-content/_global_/security/customer-keystores/idp.keystore.jks && \
    mkdir -p /cc-home-content/_global_/security/customer-truststores && \
    echo "Dummy Certs Content" > /cc-home-content/_global_/security/customer-truststores/cacerts && \
    mkdir -p /cc-home-content/.scripts && \
    touch /cc-home-content/.scripts/publishing-startup-scripts

# 3. Create the startup script with the problematic commands
# This script will fail on 'cp -rpu /cc-home-content/_global_ /cc-home/'
RUN cat << 'EOF' > /entrypoint.sh && chmod +x /entrypoint.sh
+ umask 002
+ '[' -d /cc-home ']' # Check if mount exists
+ '[' -d /cc-home-content ']' # Check if content exists
======= Setting up the cc-home directory tree =======
+ echo '======= Setting up the cc-home directory tree ======='
+ '[' -f /cc-home/_global_/security/customer-keystores/idp.keystore.jks ']'
======= Cluster has no keystore setup =======
+ echo '======= Cluster has no keystore setup ======='
+ '[' -f /cc-home/_global_/security/customer-truststores/cacerts ']'
======= Cluster has no truststore setup =======
+ echo '======= Cluster has no truststore setup ======='
+ unlink /cc-home-content/.scripts/publishing-startup-scripts
+ cp -rpu /cc-home-content/_global_ /cc-home/
cp: cannot create directory '/cc-home/_global_': Permission denied
EOF
# 4. Set the container to run as the custom user
USER ${CUSTOM_USER_ID}

# Set the entrypoint to run the script
ENTRYPOINT ["/entrypoint.sh"]

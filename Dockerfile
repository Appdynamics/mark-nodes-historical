#Dockerfile for mark node as historical 

FROM mcr.microsoft.com/powershell

# Install required packages
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get clean

# Install AppDynamics Machine Agent
ENV SCRIPT_HOME /opt/appdynamics/mark-node-historical
RUN mkdir -p ${SCRIPT_HOME}

# Copy the content of the entire parent folder into SCRIPT_HOME
COPY * ${SCRIPT_HOME}/

# Set workdir
WORKDIR ${SCRIPT_HOME}

# Run command
CMD ls -ltr & pwsh ./NodeReaper.ps1

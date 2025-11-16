FROM tomcat:8.5

MAINTAINER "CI/CD Demo"

# Build args passed from Jenkins
ARG NEXUS_URL
ARG NEXUS_REPO
ARG NEXUS_GROUP_PATH
ARG NEXUS_ARTIFACT
ARG NEXUS_VERSION
ARG NEXUS_USERNAME
ARG NEXUS_PASSWORD

# Optional tools (for debugging in the container)
RUN apt-get update && \
    apt-get install -y \
      net-tools \
      tree \
      vim \
    && rm -rf /var/lib/apt/lists/* && apt-get clean && apt-get purge

# Set a sample Java option (not mandatory, just to show env)
RUN echo 'export JAVA_OPTS="-Dapp.env=staging"' > /usr/local/tomcat/bin/setenv.sh

# Create directory where we’ll drop the WAR
RUN mkdir -p /usr/local/tomcat/webapps

# Download WAR from Nexus into Tomcat webapps
RUN echo "Downloading WAR from Nexus..." && \
    curl -u "${NEXUS_USERNAME}:${NEXUS_PASSWORD}" \
      -o /usr/local/tomcat/webapps/demo.war \
      "${NEXUS_URL}/repository/${NEXUS_REPO}/${NEXUS_GROUP_PATH}/${NEXUS_ARTIFACT}/${NEXUS_VERSION}/${NEXUS_ARTIFACT}-${NEXUS_VERSION}.war"

EXPOSE 8080

CMD ["catalina.sh", "run"]


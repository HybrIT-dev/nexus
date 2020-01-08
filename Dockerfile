FROM sonatype/nexus3:3.18.0

ENV TINI_VERSION v0.18.0
ENV NEXUS_HOST=localhost:8081
ENV NEXUS_AUTHORIZATION=admin123
ENV NEXUS_SECURITY_RANDOMPASSWORD=false

COPY extensions/helm/nexus-repository-helm-0.0.13.jar /opt/sonatype/nexus/system/org/sonatype/nexus/plugins/nexus-repository-helm/0.0.13/
COPY extensions/nexus-core-feature-3.18.0-01-features.xml /opt/sonatype/nexus/system/org/sonatype/nexus/assemblies/nexus-core-feature/3.18.0-01/

COPY setup /opt/sonatype/nexus/setup
COPY entrypoint.sh entrypoint.sh

ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini

USER root

RUN chmod +x /tini
RUN chgrp -R 0 /nexus-data
RUN chmod -R g+rw /nexus-data
RUN find /nexus-data -type d -exec chmod g+x {} +

ENTRYPOINT ["/tini", "--", "./entrypoint.sh"]
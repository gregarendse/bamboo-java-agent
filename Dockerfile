FROM ubuntu

ENV BAMBOO_USER=bamboo
ENV BAMBOO_GROUP=bamboo

ENV BAMBOO_USER_HOME=/home/${BAMBOO_USER}
ENV BAMBOO_AGENT_HOME=${BAMBOO_USER_HOME}/bamboo-agent-home

ENV INIT_BAMBOO_CAPABILITIES=${BAMBOO_USER_HOME}/init-bamboo-capabilities.properties
ENV BAMBOO_CAPABILITIES=${BAMBOO_AGENT_HOME}/bin/bamboo-capabilities.properties

RUN set -x \
    && addgroup ${BAMBOO_GROUP} \
    && adduser ${BAMBOO_USER} --home ${BAMBOO_USER_HOME} --ingroup ${BAMBOO_GROUP} --disabled-password

RUN set -x \
    && apt-get update \
    && apt-get install --yes --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    openssh-client \
    tini \
    && rm -rf /var/lib/apt/lists/*

# Add Azul Apt repository
RUN echo 'deb http://repos.azulsystems.com/ubuntu stable main' | tee /etc/apt/sources.list.d/zulu.list \
    &&  apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 0xB1998361219BD9C9

RUN set -x \
    && apt-get update  \
    && apt-get --no-install-recommends --no-install-suggests --yes install \
    git \
    maven \
    zulu-8 \
    zulu-11 \
    && rm -rf /var/lib/apt/lists/* \
    && update-java-alternatives --set /usr/lib/jvm/zulu-8-amd64

RUN set -x \
    && curl --silent https://api.github.com/repos/openshift/okd/releases/latest \
    | sed --silent --regexp-extended 's#\s*"browser_download_url"\s*:\s*"(.*openshift-client-linux.*)"#\1#p' \
    | xargs curl --location --silent --output openshift-client-linux-latest.tar.gz \
    && mkdir -p /opt/openshift-client \
    && tar xf openshift-client-linux-latest.tar.gz --directory /opt/openshift-client \
    && rm openshift-client-linux-latest.tar.gz \
    && ln -s /opt/openshift-client/oc /usr/bin/oc \
    && ln -s /opt/openshift-client/kubectl /usr/bin/kubectl

WORKDIR ${BAMBOO_USER_HOME}
USER ${BAMBOO_USER}

ARG BAMBOO_VERSION="7.2.4"
ARG DOWNLOAD_URL=https://packages.atlassian.com/maven-closedsource-local/com/atlassian/bamboo/atlassian-bamboo-agent-installer/${BAMBOO_VERSION}/atlassian-bamboo-agent-installer-${BAMBOO_VERSION}.jar
ENV AGENT_JAR=${BAMBOO_USER_HOME}/atlassian-bamboo-agent-installer.jar

RUN set -x \
    && curl -L --silent --output ${AGENT_JAR} ${DOWNLOAD_URL} \
    && mkdir -p ${BAMBOO_USER_HOME}/bamboo-agent-home/bin

COPY --chown=bamboo:bamboo bamboo-update-capability.sh bamboo-update-capability.sh
RUN set -x \
    && ${BAMBOO_USER_HOME}/bamboo-update-capability.sh "system.builder.mvn3.Maven 3" "/usr/share/maven" \
    && ${BAMBOO_USER_HOME}/bamboo-update-capability.sh "system.jdk.JDK 8" "/usr/lib/jvm/zulu-8-amd64" \
    && ${BAMBOO_USER_HOME}/bamboo-update-capability.sh "system.jdk.JDK 11" "/usr/lib/jvm/zulu-11-amd64" \
    && ${BAMBOO_USER_HOME}/bamboo-update-capability.sh "system.oc.executable" "/usr/bin/oc" \
    && ${BAMBOO_USER_HOME}/bamboo-update-capability.sh "system.kubectl.executable" "/usr/bin/kubectl"

COPY --chown=bamboo:bamboo runAgent.sh runAgent.sh
ENTRYPOINT ["./runAgent.sh"]

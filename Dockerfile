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
    && apt-get --no-install-recommends --no-install-suggests --yes install \
    ca-certificates \
    curl \
    gnupg \
    openssh-client \
    tini

# Add Azul Apt repository
RUN set -x\
    &&  echo 'deb [ arch=amd64 ] https://repos.azul.com/zulu/deb/ stable main' | tee /etc/apt/sources.list.d/zulu.list \
    &&  apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 0xB1998361219BD9C9

RUN set -x \
    && apt-get update  \
    && apt-get --no-install-recommends --no-install-suggests --yes install \
    git \
    maven \
    zulu8-jdk \
    zulu11-jdk \
    zulu17-jdk \
    && rm -rf /var/lib/apt/lists/*

RUN set -x \
    && update-java-alternatives --set /usr/lib/jvm/zulu17-ca-amd64

#   Install kubectl
RUN set -x \
    && KUBE_CTL_VERSION="$(curl --location --silent https://dl.k8s.io/release/stable.txt)" \
    && curl --location --remote-name "https://dl.k8s.io/release/${KUBE_CTL_VERSION}/bin/linux/amd64/kubectl" \
    && echo "$(curl --location --silent "https://dl.k8s.io/${KUBE_CTL_VERSION}/bin/linux/amd64/kubectl.sha256") kubectl" | sha256sum --check \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
    && kubectl version --client

#   Install oc
RUN set -x \
    && curl --silent https://api.github.com/repos/openshift/okd/releases/latest \
    | sed --silent --regexp-extended 's#\s*"browser_download_url"\s*:\s*"(.*openshift-client-linux.*)"#\1#p' \
    | xargs curl --location --silent --output openshift-client-linux-latest.tar.gz \
    && mkdir -p /opt/openshift-client \
    && tar xf openshift-client-linux-latest.tar.gz --directory /opt/openshift-client \
    && rm openshift-client-linux-latest.tar.gz \
    && ln -s /opt/openshift-client/oc /usr/bin/oc

#   Install Helm
RUN set -x \
    &&  curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

WORKDIR ${BAMBOO_USER_HOME}
USER ${BAMBOO_USER}

RUN set -x \
    && mkdir -p ${BAMBOO_USER_HOME}/bamboo-agent-home/bin

COPY --chown=bamboo:bamboo bamboo-update-capability.sh bamboo-update-capability.sh
RUN set -x \
    && ${BAMBOO_USER_HOME}/bamboo-update-capability.sh "system.builder.mvn3.Maven 3" "$(which mvn)" \
    && ${BAMBOO_USER_HOME}/bamboo-update-capability.sh "system.builder.mvn3.mvn" "$(which mvn)" \
    && ${BAMBOO_USER_HOME}/bamboo-update-capability.sh "system.jdk.JDK 8" "/usr/lib/jvm/zulu8-ca-amd64" \
    && ${BAMBOO_USER_HOME}/bamboo-update-capability.sh "system.jdk.JDK 11" "/usr/lib/jvm/zulu11-ca-amd64" \
    && ${BAMBOO_USER_HOME}/bamboo-update-capability.sh "system.jdk.JDK 17" "/usr/lib/jvm/zulu17-ca-amd64" \
    && ${BAMBOO_USER_HOME}/bamboo-update-capability.sh "system.oc.executable" "$(which oc)" \
    && ${BAMBOO_USER_HOME}/bamboo-update-capability.sh "oc" "$(which oc)" \
    && ${BAMBOO_USER_HOME}/bamboo-update-capability.sh "system.kubectl.executable" "$(which kubectl)" \
    && ${BAMBOO_USER_HOME}/bamboo-update-capability.sh "kubectl" "$(which kubectl)" \
    && ${BAMBOO_USER_HOME}/bamboo-update-capability.sh "system.helm.executable" "$(which helm)" \
    && ${BAMBOO_USER_HOME}/bamboo-update-capability.sh "helm" "$(which helm)"

COPY --chown=bamboo:bamboo runAgent.sh runAgent.sh
ENTRYPOINT ["./runAgent.sh"]

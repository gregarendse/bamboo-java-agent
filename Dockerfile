FROM atlassian/bamboo-agent-base:8.2.1

USER root

RUN set -x \
    && apt-get update \
    && apt-get --no-install-recommends --no-install-suggests --yes install \
    ca-certificates \
    curl \
    git \
    gnupg \
    openssh-client \
    tini \
    wget \
    lsb-release \
    && rm -rf /var/lib/apt/lists/*

# Add Azul Apt repository
RUN set -x \
    &&  echo 'deb [ arch=amd64 ] https://repos.azul.com/zulu/deb/ stable main' | tee /etc/apt/sources.list.d/zulu.list \
    &&  apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 0xB1998361219BD9C9

#   Install Java
RUN set -x \
    && apt-get update  \
    && apt-get --no-install-recommends --no-install-suggests --yes install \
    zulu8-jdk \
    zulu11-jdk \
    zulu17-jdk \
    && rm -rf /var/lib/apt/lists/*

ARG MAVEN_VERSION=3.6.3

#   Install Maven
RUN set -x \
    &&  wget -O /tmp/maven.tar.gz https://dlcdn.apache.org/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz \
    && echo "$(curl https://downloads.apache.org/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz.sha512) /tmp/maven.tar.gz" | sha512sum --check \
    &&  mkdir -p /opt/maven \
    &&  tar xf /tmp/maven.tar.gz -C /opt/maven \
    &&  rm -rf /tmp/maven.tar.gz \
    && /opt/maven/apache-maven-${MAVEN_VERSION}/bin/mvn --version

ENV PATH="/opt/maven/apache-maven-${MAVEN_VERSION}/bin:$PATH"

#   Install kubectl
RUN set -x \
    && KUBE_CTL_VERSION="$(curl --location --silent https://dl.k8s.io/release/stable.txt)" \
    && curl --location --remote-name "https://dl.k8s.io/release/${KUBE_CTL_VERSION}/bin/linux/amd64/kubectl" \
    && echo "$(curl --location --silent "https://dl.k8s.io/${KUBE_CTL_VERSION}/bin/linux/amd64/kubectl.sha256") kubectl" | sha256sum --check \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
    && kubectl version --client

#   Install oc
RUN set -x \
    && curl -L --silent https://api.github.com/repos/openshift/okd/releases/latest \
    | sed --silent --regexp-extended 's#\s*"browser_download_url"\s*:\s*"(.*openshift-client-linux.*)"#\1#p' \
    | xargs curl --location --silent --output openshift-client-linux-latest.tar.gz \
    && mkdir -p /opt/openshift-client \
    && tar xf openshift-client-linux-latest.tar.gz --directory /opt/openshift-client \
    && rm openshift-client-linux-latest.tar.gz \
    && ln -s /opt/openshift-client/oc /usr/bin/oc \
    && oc version --client

#   Install Helm
RUN set -x \
    &&  curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

#   Install Docker

RUN set -x \
    && mkdir -p /etc/apt/keyrings  \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
      | tee /etc/apt/sources.list.d/docker.list > /dev/null

RUN set -x \
    && apt-get update \
    && apt-get --no-install-recommends --no-install-suggests --yes install \
      docker-ce \
      docker-ce-cli \
      containerd.io \
      docker-buildx-plugin \
      docker-compose-plugin

WORKDIR ${BAMBOO_USER_HOME}
USER ${BAMBOO_USER}

RUN set -x \
    && ${BAMBOO_USER_HOME}/bamboo-update-capability.sh "system.builder.mvn3.Maven 3" "/opt/maven/apache-maven-${MAVEN_VERSION}" \
    && ${BAMBOO_USER_HOME}/bamboo-update-capability.sh "system.builder.mvn3.mvn" "/opt/maven/apache-maven-${MAVEN_VERSION}" \
    && ${BAMBOO_USER_HOME}/bamboo-update-capability.sh "system.jdk.JDK 8" "/usr/lib/jvm/zulu8-ca-amd64" \
    && ${BAMBOO_USER_HOME}/bamboo-update-capability.sh "system.jdk.JDK 11" "/usr/lib/jvm/zulu11-ca-amd64" \
    && ${BAMBOO_USER_HOME}/bamboo-update-capability.sh "system.jdk.JDK 17" "/usr/lib/jvm/zulu17-ca-amd64" \
    && ${BAMBOO_USER_HOME}/bamboo-update-capability.sh "system.oc.executable" "$(which oc)" \
    && ${BAMBOO_USER_HOME}/bamboo-update-capability.sh "oc" "$(which oc)" \
    && ${BAMBOO_USER_HOME}/bamboo-update-capability.sh "system.kubectl.executable" "$(which kubectl)" \
    && ${BAMBOO_USER_HOME}/bamboo-update-capability.sh "kubectl" "$(which kubectl)" \
    && ${BAMBOO_USER_HOME}/bamboo-update-capability.sh "system.helm.executable" "$(which helm)" \
    && ${BAMBOO_USER_HOME}/bamboo-update-capability.sh "helm" "$(which helm)"

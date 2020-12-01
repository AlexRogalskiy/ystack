FROM yolean/node:3baccea320a5d1b644e37044fa7445a972a0a9c2@sha256:7c5162114bbd280a59c12e9c5bc9076e82b081b1ba65440b83ef3fb9417ba719 as yolean-node

FROM ubuntu:20.04@sha256:fff16eea1a8ae92867721d90c59a75652ea66d29c05294e6e2f898704bdb8cf1

COPY --from=yolean-node /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=yolean-node /usr/local/bin/node /usr/local/bin/
RUN cd /usr/local/bin && ln -s ../lib/node_modules/npm/bin/npm-cli.js npm

COPY lib/package* /usr/local/lib/node_modules/@yolean/ystack/
RUN cd /usr/local/lib/node_modules/@yolean/ystack && npm ci --ignore-scripts
RUN for B in \
  tsc ts-node \
  jest ts-jest \
  rollup \
  ; do ln -s -v /usr/local/lib/node_modules/@yolean/ystack/node_modules/.bin/$B /usr/local/bin/$B; done

RUN set -ex; \
  export DEBIAN_FRONTEND=noninteractive; \
  runDeps='ca-certificates curl git jq unzip findutils'; \
  buildDeps=''; \
  apt-get update && apt-get install -y $runDeps $buildDeps --no-install-recommends; \
  \
  echo disabled: apt-get purge -y --auto-remove $buildDeps; \
  rm -rf /var/lib/apt/lists/*; \
  rm -rf /var/log/dpkg.log /var/log/alternatives.log /var/log/apt /root/.gnupg

RUN set -e; \
  F=$(mktemp); \
  curl -SLs https://dl.k8s.io/v1.17.14/kubernetes-client-linux-amd64.tar.gz \
    | tee $F \
    | tar xzf - --strip-components=3 -C /usr/local/bin/; \
  echo "027945e245693c4c0dfd818eb7b4213d21d90b2d0191d9d62c218e150ee1e604ba8b9f329704ef4089327abf3be9fa31672dd637d7518efe80fb03e40fbe6e37 $F" \
    | sha512sum -c -; \
  rm $F

ENV YSTACK_HOME=/usr/local/src/ystack
ENV PATH="${PATH}:${YSTACK_HOME}/bin"
ENV SKAFFOLD_INSECURE_REGISTRY='builds-registry.ystack.svc.cluster.local,prod-registry.ystack.svc.cluster.local'

COPY bin/y-bin-dependency-download /usr/local/src/ystack/bin/

COPY bin/y-kustomize /usr/local/src/ystack/bin/
RUN y-kustomize

COPY bin/y-helm /usr/local/src/ystack/bin/
RUN y-helm

COPY bin/y-buildctl /usr/local/src/ystack/bin/
RUN y-buildctl

COPY bin/y-container-structure-test /usr/local/src/ystack/bin/
RUN y-container-structure-test

COPY bin/y-crane /usr/local/src/ystack/bin/
RUN y-crane

COPY bin/y-deno /usr/local/src/ystack/bin/
RUN y-deno -V

ENV SKAFFOLD_UPDATE_CHECK=false
COPY bin/y-skaffold /usr/local/src/ystack/bin/
RUN y-skaffold

COPY . /usr/local/src/ystack
WORKDIR /usr/local/src/ystack

RUN echo 'nonroot:x:65532:65534:nonroot:/home/nonroot:/usr/sbin/nologin' >> /etc/passwd && \
  mkdir -p /home/nonroot && touch /home/nonroot/.bash_history && chown -R 65532:65534 /home/nonroot
USER nonroot:nogroup

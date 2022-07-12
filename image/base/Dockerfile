FROM alpine:3.15.0 AS tools

ARG HELM_VERSION
ARG HELMFILE_VERSION=latest
ARG KUBECTL_VERSION
ARG YQ_VERSION=latest

RUN apk add --update curl jq bash openssl
RUN mkdir /tools \
  && echo "---> Downloading yq ${YQ_VERSION}" \
  && yq_dl_url="$(curl -s https://api.github.com/repos/mikefarah/yq/releases/latest | jq -r '.assets[] | select(.browser_download_url | test("linux.amd64.tar.gz")) | .browser_download_url')" \
  && curl --progress-bar -L "$yq_dl_url" | tar -xvz -C /tools \
  && mv /tools/yq_linux_amd64 /tools/yq \
  && chmod 755 /tools/yq \
  && /tools/yq --version \
  && echo "---> Downloading helmfile ${HELMFILE_VERSION}" \
  && helmfile_dl_url="$(curl -s https://api.github.com/repos/roboll/helmfile/releases/${HELMFILE_VERSION} | jq -r '.assets[] | select(.browser_download_url | test("linux.amd64")) | .browser_download_url')" \
  && curl --progress-bar -L -o /tools/helmfile "$helmfile_dl_url" \
  && chmod 755 /tools/helmfile \
  && /tools/helmfile version \
  && echo "---> Downloading helm ${HELM_VERSION:-latest}" \
  && curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash -s -- --no-sudo ${HELM_VERSION:+--version ${HELM_VERSION}} \
  && /usr/local/bin/helm version --short \
  && echo "---> Downloading kubectl ${KUBECTL_VERSION:-latest}" \
  && KUBECTL_VERSION="${KUBECTL_VERSION:-$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)}" \
  && curl -L -o /tools/kubectl "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl" \
  && chmod 755 /tools/kubectl \
  && /tools/kubectl version --client=true

FROM alpine:3.15.0
COPY --from=tools /tools/* /usr/local/bin/
COPY --from=tools /usr/local/bin/helm /usr/local/bin/
COPY rootfs/ /

ENV XDG_DATA_HOME=/root/.local/share \
  XDG_CONFIG_HOME=/root/.config \
  XDG_CACHE_HOME=/root/.cache \
  XDG_DATA_DIRS=/usr/local/share/:/usr/share/

RUN apk add --update --no-cache \
  bash \
  coreutils \
  curl \
  dumb-init \
  git \
  jq \
  rsync \
  util-linux

WORKDIR /project
ENTRYPOINT [ "/usr/bin/dumb-init", "--", "stdbuf", "--output=0", "--error=0", "bash", "/usr/local/bin/render-manifests.sh" ]


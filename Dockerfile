ARG BASE_IMAGE=debian:13-slim
FROM ${BASE_IMAGE}

ARG DEBIAN_FRONTEND=noninteractive

RUN if command -v apt-get >/dev/null 2>&1; then \
      apt-get update && \
      apt-get install -y --no-install-recommends bash coreutils grep sed findutils util-linux procps expect shellcheck bats ca-certificates && \
      rm -rf /var/lib/apt/lists/*; \
    elif command -v dnf >/dev/null 2>&1; then \
      dnf install -y bash coreutils grep sed findutils util-linux util-linux-core util-linux-user procps-ng expect ShellCheck bats ca-certificates && \
      dnf clean all; \
    else \
      echo "Unsupported test image: no apt-get or dnf" >&2; exit 1; \
    fi

COPY shieldctl /opt/shieldctl/shieldctl
COPY tests/run.sh /opt/shieldctl/tests/run.sh
COPY tests/firewall_test.sh /opt/shieldctl/tests/firewall_test.sh
COPY tests/run_all.sh /opt/shieldctl/tests/run_all.sh
RUN chmod 755 /opt/shieldctl/shieldctl /opt/shieldctl/tests/*.sh

WORKDIR /workspace
ENTRYPOINT ["/opt/shieldctl/tests/run_all.sh"]

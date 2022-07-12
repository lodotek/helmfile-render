ARG base_image=lodotek/helmfile-render
FROM ${base_image}
COPY docker-entrypoint.sh /docker-entrypoint.sh
ENTRYPOINT ["/usr/bin/dumb-init", "--", "/docker-entrypoint.sh"]

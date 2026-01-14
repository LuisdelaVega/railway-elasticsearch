# Default Elasticsearch version to use
ARG ELASTICSEARCH_VERSION=8.19.10

# Use the Elasticsearch image with the specified version
FROM elasticsearch:${ELASTICSEARCH_VERSION}

# Copy in our custom config file that disables the use of nmap
COPY elasticsearch.yml /usr/share/elasticsearch/config/elasticsearch.yml

# Copy in our custom role file that add an anonymous role
COPY roles.yml /usr/share/elasticsearch/config/roles.yml

# Copy in the new entrypoint and set the execution bit
COPY --chmod=755 entrypoint-new.sh /usr/local/bin/entrypoint-new.sh

# Switch to the root user
USER 0

# Install sudo and allow the elasticsearch user to run chown as root
RUN apt-get update && apt-get install -y sudo && \
    echo "elasticsearch ALL=(root) NOPASSWD: /bin/chown" > /etc/sudoers.d/elasticsearch

# Switch back to the elasticsearch user as elasticsearch can only run as non-root
USER 1000:0

# Run our new entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint-new.sh"]

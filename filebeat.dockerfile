FROM elastic/filebeat:8.13.4

COPY filebeat.yml /usr/share/filebeat/filebeat.yml

USER root
RUN mkdir -p /var/log/shared && \
    chown -R filebeat:filebeat /var/log/shared && \
    chmod go-w /usr/share/filebeat/filebeat.yml

USER filebeat
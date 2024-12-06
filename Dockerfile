FROM  quay.io/fedora/httpd-24:2.4

USER 0

# Copy configuration files
#COPY custom.conf /etc/httpd/conf.d/custom.conf
COPY merge-custom.conf /etc/httpd/conf.d/merge-custom.conf
COPY cache-custom.conf /etc/httpd/conf.d/cache-custom.conf
# Enable mod_deflate (this one is already enabled too in the base image)
# RUN sed -i '/#LoadModule deflate_module/s/^#//' /etc/httpd/conf/httpd.conf


RUN dnf install php -y && \
    dnf clean all

# Reset permissions of filesystem to default values
RUN /usr/libexec/httpd-prepare && rpm-file-permissions

# Expose ports

EXPOSE 8080
EXPOSE 8443

# Switch to non-root user
USER 1001

# Start Apache
CMD ["/usr/bin/run-httpd"]

#@OSS_ARTIFACT=true
#@NAME=all-in-one-driver
FROM phusion/baseimage:0.10.0

# Clean up APT when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists* /tmp/* /var/tmp/*

#@BUILD=go install github.com/turbinelabs/all-in-one/driver/...
#@ARTIFACT=/tbn/bin/all-in-one-driver:all-in-one-driver
ADD build/all-in-one-driver /usr/local/bin/all-in-one-driver

# Use baseimage-docker's init system.
CMD ["/sbin/my_init", "--", "/usr/local/bin/all-in-one-driver"]

From centos:7

RUN yum -y install epel-release \
    && yum -y install python34-devel net-tools\
       	      	      postfix rsyslog \
                      cyrus-sasl cyrus-sasl-lib cyrus-sasl-plain \
    && yum clean all

RUN curl https://bootstrap.pypa.io/get-pip.py | python3.4 && \
    pip3 install chaperone

COPY chaperone.conf /etc/chaperone.d/chaperone.conf

COPY docker-entrypoint.sh /usr/local/bin/
RUN ln -s usr/local/bin/docker-entrypoint.sh /entrypoint.sh # backwards compat

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["run"]

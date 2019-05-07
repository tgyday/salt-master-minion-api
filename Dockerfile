FROM centos:centos7

MAINTAINER tgyday <tgyday@gmail.com>

ENV SALT_VERSION 2018.3-1
ENV SALT_API_PORT 8000
ENV SALT_API_HOST 0.0.0.0
ENV PRE_CREATE_USERS saltapi
ENV PRE_CREATE_USERS_PASS 123456

RUN yum install -y https://repo.saltstack.com/yum/redhat/salt-repo-${SALT_VERSION}.el7.noarch.rpm
RUN yum install -y salt-master salt-minion salt-ssh salt-syndic salt-cloud salt-api

ADD epel.repo /etc/yum.repos.d/epel.repo

RUN yum install -y python2-pip vim iproute
RUN pip install -i https://pypi.douban.com/simple/ PyOpenSSL

ADD run.sh /run.sh
RUN chmod a+x /run.sh

# salt-master, salt-api
EXPOSE 4505 4506 8000

ENV SALT_CONFIG /etc/salt
ENV BEFORE_EXEC_SCRIPT ${SALT_CONFIG}/before-exec.sh
ENV SALT_API_CMD /usr/bin/salt-api -c ${SALT_CONFIG} -l info
ENV EXEC_CMD /usr/bin/salt-master -c ${SALT_CONFIG} -l info
ENV MINION_EXEC_CMD /usr/bin/salt-minion -c ${SALT_CONFIG} -l info

CMD ["/run.sh"]

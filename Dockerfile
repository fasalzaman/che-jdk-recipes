
    
# Copyright (c) 2012-2018 Red Hat, Inc.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
#
# Contributors: Madou Coulibaly mcouliba@redhat.com

FROM eclipse/centos_jdk8

ARG OC_VERSION=3.11.43
ARG ODO_VERSION=v0.0.17

# Install Cmake 3.6
RUN wget https://cmake.org/files/v3.6/cmake-3.6.2.tar.gz
RUN tar -zxvf cmake-3.6.2.tar.gz
RUN cd cmake-3.6.2
RUN sudo yum group install "Development Tools"
RUN sudo ./bootstrap --prefix=/usr/local
RUN sudo make
RUN sudo make install
RUN echo export PATH=/usr/local/bin:$PATH:$HOME/bin >> ~/.bash_profile
RUN source ~/.bash_profile


# Install nss_wrapper and tools
RUN sudo yum update -y && \
    sudo yum install -y cmake gettext make gcc && \
    cd /home/user/ && \
    git clone git://git.samba.org/nss_wrapper.git && \
    cd nss_wrapper && \
    mkdir obj && cd obj && \
    cmake -DCMAKE_INSTALL_PREFIX=/usr/local -DLIB_SUFFIX=64 .. && \
    make && sudo make install && \
    cd /home/user && rm -rf ./nss_wrapper && \
    sudo yum remove -y cmake make gcc && \
    sudo yum clean all && \
    sudo rm -rf /tmp/* /var/cache/yum

# Install jq
RUN sudo yum install -y epel-release && \
    sudo yum install -y jq

# Install nodejs for ls agents and OpenShift CLI
RUN sudo yum update -y && \
    curl -sL https://rpm.nodesource.com/setup_8.x | sudo -E bash - && \
    sudo yum install -y bzip2 tar curl wget nodejs && \
    sudo wget -qO- "https://mirror.openshift.com/pub/openshift-v3/clients/${OC_VERSION}/linux/oc.tar.gz" | sudo tar xvz -C /usr/local/bin && \
    sudo yum remove -y wget && \
    sudo yum clean all && \
    sudo rm -rf /tmp/* /var/cache/yum

# Install Ansible
RUN sudo yum install -y ansible

# Install Siege
RUN sudo yum -y install epel-release && \
    sudo yum -y install siege

# Install Yarn
RUN sudo yum update -y && \
    curl --silent --location https://dl.yarnpkg.com/rpm/yarn.repo | sudo tee /etc/yum.repos.d/yarn.repo
RUN sudo yum install -y yarn

# Install Openshift DO (ODO)
RUN sudo curl -L https://github.com/redhat-developer/odo/releases/download/${ODO_VERSION}/odo-linux-amd64 -o /usr/local/bin/odo && \
    sudo chmod +x /usr/local/bin/odo

# The following lines are needed to set the correct locale after `yum update`
# c.f. https://github.com/CentOS/sig-cloud-instance-images/issues/71
RUN sudo localedef -i en_US -f UTF-8 C.UTF-8
ENV LANG="C.UTF-8"

# Maven settings
COPY ./settings.xml $HOME/.m2/settings.xml
RUN wget https://spektraazurelabs.blob.core.windows.net/openshift-jboss/m2_folder_preloaded.tgz 
RUN tar -xzvf m2_folder_preloaded.tgz
RUN rm m2_folder_preloaded.tgz
RUN cd $HOME
#install RHAMT
RUN wget https://spektraazurelabs.blob.core.windows.net/openshift-jboss/migrationtoolkit-rhamt-cli-4.0.0.Beta4-offline.zip
RUN unzip migrationtoolkit-rhamt-cli-4.0.0.Beta4-offline.zip

# download Jboss EAP 7.1.0
RUN wget https://spektraazurelabs.blob.core.windows.net/openshift-jboss/jboss-eap-7.1.0.zip 

# Intall tree
RUN sudo yum install tree -y
# Give write access to /home/user for 
# users with an arbitrary UID 
RUN sudo chgrp -R 0 /home/user \
  && sudo chmod -R g+rwX /home/user \
  && sudo chgrp -R 0 /etc/passwd \
  && sudo chmod -R g+rwX /etc/passwd \
  && sudo chgrp -R 0 /etc/group \
  && sudo chmod -R g+rwX /etc/group \
  && sudo mkdir -p /projects \
  && sudo chgrp -R 0 /projects \
  && sudo chmod -R g+rwX /projects
  
# Generate passwd.template
RUN cat /etc/passwd | \
    sed s#user:x.*#user:x:\${USER_ID}:\${GROUP_ID}::\${HOME}:/bin/bash#g \
    > /home/user/passwd.template

# Generate group.template
RUN cat /etc/group | \
    sed s#root:x:0:#root:x:0:0,\${USER_ID}:#g \
    > /home/user/group.template

RUN sed -i '/MAVEN_OPTS/d' /home/user/.bashrc && \
    echo "export MAVEN_OPTS=\"\$MAVEN_OPTS \$JAVA_OPTS\"" >> /home/user/.bashrc

ENV HOME /home/user

# Overwride entrypoint
COPY ["entrypoint.sh","/home/user/entrypoint.sh"]

ENTRYPOINT ["/home/user/entrypoint.sh"]
CMD tail -f /dev/null

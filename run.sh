#!/bin/bash

set -m

abort() {
    msg="$1"
    echo "$msg"
    echo "=> Environment was:"
    env
    echo "=> Program terminated!"
    exit 1
}

create_user() {
    user=$1
    password=$2
    if [ -z "${user}" ] || [ -z "${password}" ]; then
        abort "=> create_user 2 args are required (user, password)."
    fi
    useradd ${user}
    echo "${user}:${password}" | chpasswd
    if [ $? -eq 0 ]; then
        echo "=> User \"${user}\" ok."
    else
        abort "=> Failed to create user \"${user}\"!"
    fi
}

# create users from environment variables and docker secrets
if [ -z "${PRE_CREATE_USERS}" ] && [ -z "${PRE_CREATE_USERS_PASS}" ]; then
    echo "=> No user names supplied: no user will be created."
else
    for user in $(echo ${PRE_CREATE_USERS} | tr "," "\n"); do
        for password in $(echo ${PRE_CREATE_USERS_PASS} | tr "," "\n"); do
            create_user $user $password
        done
    done
fi

# create salt master keys from env variables
if [ -n "${KEY_MASTER_PRIV}" ]; then
    if [ -z "${KEY_MASTER_PUB}" ]; then
        abort "=> Both KEY_MASTER_PRIV and KEY_MASTER_PUB should be set."
    fi
    echo "=> Overwriting master public & private key"
    mkdir -p "${SALT_CONFIG}/pki/master"
    chmod 700 "${SALT_CONFIG}/pki/master"
    echo -e "${KEY_MASTER_PRIV}" > "${SALT_CONFIG}/pki/master/master.pem"
    echo -e "${KEY_MASTER_PUB}" > "${SALT_CONFIG}/pki/master/master.pub"
fi

# create salt master keys from docker secrets
if [ -f /run/secrets/master.pem ] && [ -f /run/secrets/master.pub ]
then
    mkdir -p "${SALT_CONFIG}/pki/master"
    chmod 700 "${SALT_CONFIG}/pki/master"
    echo "=> Overwriting master public & private key from docker secrets"
    cp /run/secrets/master.pem "${SALT_CONFIG}/pki/master/master.pem"
    cp /run/secrets/master.pub "${SALT_CONFIG}/pki/master/master.pub"
fi

if [ -f "${SALT_CONFIG}/pki/master/master.pem" ]
then
    if [ -z "${PRE_ACCEPT_MINIONS}" ]; then
        echo "=> No minion key supplied: no minion key will be pre-accepted."
    else
        for minion in $(echo ${PRE_ACCEPT_MINIONS} | tr "," "\n"); do
            mkdir -p "${SALT_CONFIG}/pki/master/minions"
            minionkey_var="${minion//-/_}_KEY"
            if [ -f "/run/secrets/${minion}.pub" ]
            then
                echo "=> Overwriting minion ${minion} key from docker secrets"
                cp "/run/secrets/${minion}.pub" "${SALT_CONFIG}/pki/master/minions/${minion}"
            elif ! [ -z "${!minionkey_var}" ]
            then
                echo "=> Overwriting minion ${minion} key from env variables"
                echo -e "${!minionkey_var}" > "${SALT_CONFIG}/pki/master/minions/${minion}"
            else
                abort "=> Failed to preaccept minion \"${minion}\"!"
            fi
        done
    fi
fi

if [ -x "${BEFORE_EXEC_SCRIPT%% *}" ];then
    echo "=> Running BEFORE_EXEC_SCRIPT [$BEFORE_EXEC_SCRIPT]..."
    $BEFORE_EXEC_SCRIPT
    if [ $? -ne 0 ]
    then
        abort "=> BEFORE_EXEC_SCRIPT [$BEFORE_EXEC_SCRIPT] has failed."
    fi
fi

if [ -f /etc/salt/master ];then
    if [ -z ${SALT_API_PORT} ];then
        SALT_API_PORT=8000
    fi
    if [ -z ${SALT_API_HOST} ];then
        SALT_API_HOST=0.0.0.0
    fi

grep '^rest_cherrypy' /etc/salt/master 
if [ $? -ne 0 ];then
cat >> /etc/salt/master << EOF
rest_cherrypy:
  port: ${SALT_API_PORT}
  host: ${SALT_API_HOST}
  #disable_ssl: True
  ssl_crt: /etc/pki/tls/certs/localhost.crt
  ssl_key: /etc/pki/tls/certs/localhost.key
  log_access_file: /var/log/salt/api_access.log
  log_error_file: /var/log/salt/api_error.log
EOF
fi

grep '^external_auth' /etc/salt/master
if [ $? -ne 0 ];then
cat >> /etc/salt/master << EOF
external_auth:
  pam:
    ${PRE_CREATE_USERS}:
      - .*
      - '@wheel'
      - '@runner'
      - '@jobs'
EOF
fi

fi

if [ -f /etc/salt/minion ];then
    sed -i 's/^master:.*/master: 127.0.0.1/g' /etc/salt/minion
fi

if [ ! -f /etc/pki/tls/certs/localhost.crt ];then
    salt-call --local tls.create_self_signed_cert
fi

echo "=> Running EXEC_CMD [$EXEC_CMD]..."
exec $EXEC_CMD &

echo "=> Running MINION_EXE_CMD [$MINION_EXE_CMD]..."
exec $MINION_EXEC_CMD &

echo "=> Running SALT_API_CMD [$SALT_API_CMD]..."
exec $SALT_API_CMD


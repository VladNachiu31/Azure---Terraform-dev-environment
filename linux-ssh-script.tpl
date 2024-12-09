$ cat << EOF >> ~/.ssh/config

Host ${hostname}
    Hostname ${hostname}
    User ${username}
    IdentityFile ${identityfile}
EOF
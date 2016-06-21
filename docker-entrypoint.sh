#!/bin/bash

function run {
    postconf -e 'inet_interfaces = all'

    if [ ! -z "$MTP_HOST" ]; then
	postconf -e "myhostname = $MTP_HOST"
    fi

    postconf -e 'myorigin = $mydomain'
    postconf -e 'mydestination = $myhostname, localhost.$mydomain, localhost, $mydomain'

    ## SMTP-AUTH configuration
    # The name of the Postfix SMTP server's local SASL authentication realm. (default: empty)
    postconf -e 'smtpd_sasl_local_domain ='
    # Enable SASL authentication in the Postfix SMTP server. By default, the
    # Postfix SMTP server does not use authentication.
    postconf -e 'smtpd_sasl_auth_enable = yes'
    # The SASL plug-in type that the Postfix SMTP server should use for authentication.
    postconf -e 'smtpd_sasl_type = cyrus'
    # Postfix SMTP server SASL security options. noanonymous disallow methods
    # that allow anonymous authentication.
    postconf -e 'smtpd_sasl_security_options = noanonymous'
    # Enable inter-operability with remote SMTP clients that implement an obsolete
    # version of the AUTH command
    postconf -e 'broken_sasl_auth_clients = yes'
    # Do not report the SASL authenticated user name in the smtpd Received message header.
    postconf -e 'smtpd_sasl_authenticated_header = no'
    # Optional restrictions that the Postfix SMTP server applies in the context of
    # a client RCPT TO command, after smtpd_relay_restrictions.
    postconf -e 'smtpd_recipient_restrictions = permit_sasl_authenticated, permit_mynetworks, reject_unauth_destination'

    # Generate sasldb2
    echo $MTP_USERS | tr , \\n | while IFS=':' read -r _user _password; do
	echo $_password | saslpasswd2 -p -c -u $MTP_HOST $_user
    done
    chown postfix.saslauth /etc/sasldb2

    # Use sasl2
    cat > /etc/sasl2/smtpd.conf <<EOF
pwcheck_method: auxprop
auxprop_plugin: sasldb
mech_list: PLAIN LOGIN CRAM-MD5 DIGEST-MD5 NTLM
EOF

    # Launch
    exec chaperone
}

if [ "$1" = 'run' ]; then
    run;
else
    exec "$@"
fi

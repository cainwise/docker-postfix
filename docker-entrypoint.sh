#!/bin/bash

function run {
    ## Basic configuration
    # The network interface addresses that this mail system receives mail on.
    # Specify "all" to receive mail on all network interfaces.
    postconf -e 'inet_interfaces = all'

    # The internet hostname of this mail system.
    if [ ! -z "$MTA_HOST" ]; then
	postconf -e "myhostname = $MTA_HOST"
    fi

    # The domain name that locally-posted mail appears to come from, and that
    # locally posted mail is delivered to. Example: $mydomain
    postconf -e 'myorigin = $mydomain'
    # Network style
    postconf -e 'mynetworks_style = host'
    # The list of domains that are delivered via the $local_transport mail
    # delivery transport. Default: $myhostname, localhost.$mydomain, localhost
    postconf -e 'mydestination = $myhostname, $mydomain, localhost.$mydomain, localhost'
    # What destination domains and/or subdomains this system will relay mail to.
    postconf -e 'relay_domains ='
    # Lookup tables with all names or addresses of local recipients. The default
    # (proxy:unix:passwd.byname $alias_maps) will cause postfix to access
    # the /etc/passwd file.
    postconf -e 'local_recipient_maps ='

    ## Spam configuration
    # This can reduce the amount of spam you will receive.
    # From http://wiki.apache.org/spamassassin/OtherTricks#line-69
    # This setting will slow down the sending from connecting clients. This trick
    # can reduce spam as spammers dont have time to wait.
    postconf -e 'smtpd_client_restrictions = sleep 5'
    postconf -e 'smtpd_delay_reject = no'
    # Reject if the MAIL FROM domain has
    #   1) no DNS A or MX record
    #   2) a malformed MX record or MAIL FROM address is not a fully-qualified domain
    postconf -e 'smtpd_sender_restrictions = reject_unknown_sender_domain'
    # Protect against bots/spammers that trigger lots of errors or scan for
    # accounts. When the error count reaches the soft-limit, delay the response by
    # the sleep-time but if the hard-limit is reached, postfix will disconnect.
    postconf -e 'smtpd_error_sleep_time = 30'
    postconf -e 'smtpd_soft_error_limit = 10'
    postconf -e 'smtpd_hard_error_limit = 20'

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
    #
    postconf -e 'smtpd_relay_restrictions = permit_mynetworks, permit_sasl_authenticated, defer_unauth_destination'
    # Optional restrictions that the Postfix SMTP server applies in the context of
    # a client RCPT TO command, after smtpd_relay_restrictions.
    postconf -e 'smtpd_recipient_restrictions = permit_mynetworks, permit_sasl_authenticated, reject_unauth_destination'

    ## TLS configuration
    # postconf -e 'smtpd_tls_auth_only = yes'

    # Use sasl2
    cat > /etc/sasl2/smtpd.conf <<EOF
pwcheck_method: auxprop
auxprop_plugin: sasldb
mech_list: PLAIN LOGIN CRAM-MD5 DIGEST-MD5 NTLM
EOF

    # Generate sasldb2
    echo $MTA_USERS | tr , \\n | while IFS=':' read -r _user _password; do
	echo $_password | saslpasswd2 -p -c -u $MTA_HOST $_user
    done
    chown postfix.saslauth /etc/sasldb2

    # Launch
    exec chaperone
}

if [ "$1" = 'run' ]; then
    run;
else
    exec "$@"
fi

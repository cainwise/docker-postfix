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

    ## TLS configuration
    # postconf -e 'smtpd_tls_auth_only = yes'
    TLSDIR=/etc/postfix/tls
    mkdir -p $TLSDIR
    CA=$(find $TLSDIR -name *.crt)
    PRIVATE_KEY=$(find $TLSDIR -name *.key)

    if [ -n "$CA" -a -n "$PRIVIATE_KEY" ]; then
	echo "TLS: $CA and $PRIVATE_KEY are found, enabling..."
	postconf -e "smtp_tls_cert_file = $CA"
	postconf -e "smtp_tls_key_file= $PRIVATE_KEY"
	chmod 0400 $TLSDIR/*.*
    else
	echo "TLS: Certificate and Private key are missing, skip..."
    fi

    ## OpenDKIM
    # Directory to store DKIM keys
    DKIM_KEYDIR=/etc/opendkim/keys
    # A Selector is created while generating keys, a selector can be unique
    # keyword which is associated in keys and included in DKIM signature.
    DKIM_SELECTOR=mail

    if [ -z "$(find $DKIM_KEYDIR -iname *.private)" ]; then
	echo "OpenDKIM: Default DKIM keys for $DOMAIN doesn't exist, generating..."
	opendkim-genkey -D $DKIM_KEYDIR -s $DKIM_SELECTOR -d $DOMAIN
	echo "OpenDKIM: Default DKIM keys for $DOMAIN created in $DKIM_KEYDIR"
    else
	echo "OpenDKIM: Default DKIM keys for $DOMAIN exists, skip..."
    fi

    # $DKIM_SELECTOR.private is the private key for the domain
    # $DKIM_SELECTOR.txt is the public key that will publish in DNS TXT record
    echo "OpenDKIM: Regulating the permissions of Default DKIM Keys..."
    chown -R root:opendkim $DKIM_KEYDIR
    chmod 640 $DKIM_KEYDIR/$DKIM_SELECTOR.private
    chmod 644 $DKIM_KEYDIR/$DKIM_SELECTOR.txt

    echo "OpenDKIM: Showing contents of $DKIM_KEYDIR/$DKIM_SELECTOR.txt"
    cat $DKIM_KEYDIR/$DKIM_SELECTOR.txt

    DKIM_CONF=/etc/opendkim.conf
    DKIM_KEY_TABLE=/etc/opendkim/KeyTable
    DKIM_SIGNING_TABLE=/etc/opendkim/SigningTable
    DKIM_TRUSTED_HOSTS=/etc/opendkim/TrustedHosts
    echo "OpenDKIM: Configuring $DKIM_CONF..."
    cat >> $DKIM_CONF <<EOF

# Set by docker-postfix
Mode                sv
Socket              inet:8891@127.0.0.1

Selector	    ${DKIM_SELECTOR}
Domain              ${DOMAIN}
KeyFile             ${DKIM_KEYDIR}/${DKIM_SELECTOR}.private
Canonicalization    relaxed/simple
ExternalIgnoreList  refile:${DKIM_TRUSTED_HOSTS}
InternalHosts       refile:${DKIM_TRUSTED_HOSTS}
KeyTable            refile:${DKIM_KEY_TABLE}
SigningTable        refile:${DKIM_SIGNING_TABLE}
EOF

    echo "OpenDKIM: Configuring $DKIM_KEY_TABLE..."
    cat >> $DKIM_KEY_TABLE <<EOF

# Set by docker-postfix
${DKIM_SELECTOR}._domainkey.${DOMAIN} ${DOMAIN}:${DKIM_SELECTOR}:${DKIM_KEYDIR}/${DKIM_SELECTOR}.private
EOF

    echo "OpenDKIM: Configuring $DKIM_SIGNING_TABLE..."
    cat >> $DKIM_SIGNING_TABLE <<EOF

# Set by docker-postfix
*@${DOMAIN} ${DKIM_SELECTOR}._domainkey.${DOMAIN}
EOF

    echo "OpenDKIM: Configuring $DKIM_TRUSTED_HOSTS..."
    cat >> $DKIM_TRUSTED_HOSTS <<EOF

# Set by docker-postfix
*.${DOMAIN}
EOF

    echo "OpenDKIM: Configuring Postfix..."
    postconf -e 'smtpd_milters = inet:127.0.0.1:8891'
    postconf -e 'non_smtpd_milters=$smtpd_milters'
    postconf -e 'milter_default_action=accept'

    ## Launch
    exec chaperone
}

if [ "$1" = 'run' ]; then
    run;
else
    exec "$@"
fi

docker-postfix
==============
Run postfix with smtp authentication (sasldb) in a docker container.

TLS and OpenDKIM support are optional.

## Usage
1. Create postfix container with smtp authentication

	```bash
	$ docker run -p 25:25 \
            -e MTA_HOST=mail.example.com -e MTA_USERS=user:pwd \
			--name postfix -d m31271n/postfix
	# Set multiple user credentials: -e MTA_USERS=user1:pwd1,user2:pwd2,...,userN:pwdN
	```
2. Enable OpenDKIM: save your domain key `.private` in `/path/to/domainkeys`

	```bash
	$ docker run -p 25:25 \
			-e MTA_HOST=mail.example.com -e MTA_USERS=user:pwd \
			-v /path/to/domainkeys:/etc/opendkim/domainkeys \
			--name postfix -d m31271n/postfix
	```
3. Enable TLS(587): save your SSL certificates `.key` and `.crt` to `/path/to/certs`

	```bash
	$ sudo docker run -p 587:587 \
			-e MTA_HOST=mail.example.com -e MTA_USERS=user:pwd \
			-v /path/to/certs:/etc/postfix/certs \
			--name postfix -d m31271n/postfix
	```

## Note
+ Login credential should be set to (`username@mail.example.com`, `password`) in SMTP Client
+ You can assign the port of MTA on the host machine to one other than 25 ([Managing multiple Postfix instances on a single host](http://www.postfix.org/MULTI_INSTANCE_README.html))
+ Read the reference below to find out how to generate domain keys and add public key to the domain's DNS records

## Reference
+ [Postfix Standard Configuration Examples](http://www.postfix.org/STANDARD_CONFIGURATION_README.html)
+ [Postfix SASL Howto](http://www.postfix.org/SASL_README.html)


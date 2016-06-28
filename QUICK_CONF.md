# 快速设置

假设要为 `example.com` 域设置一个邮件服务器 `mail.example.com`（IP 地址为 1.2.3.4），并开启 STARTTLS 的支持。

## 提前准备
准备为 `mail.example.com` 开启 STARTTLS 支持时需要使用的证书和私钥：

* `mail.example.com.crt`
* `mail.example.com.key`

## 创建 Postfix 容器

创建目录 `dkim_keys` 和 `tls`。

在目录 `tls` 中放置证书和私钥，运行容器时，STARTTLS 支持将自动开启。

```sh
shell> docker run
           -p 25:25 \
           -e MTA_DOMAIN=example.com \
           -e MTA_HOST=mail.example.com \
           -e MTA_USERS=user:passwd \
           -v dkim_keys:/etc/opendkim/keys \
           -v tls:/etc/postfix/tls \
           --name postfix -d m31271n/postfix
```

## 配置 MX 记录 和 A 记录

| Type   | Host              | Answer            |
|--------|-------------------|-------------------|
| MX     | example.com       | mail.example.com  |
| A      | mail.example.com  | 1.2.3.4           |

* MX 保证向 `example.com` 域发送的邮件就会被递送到 `mail.example.com`。
* A 记录保证能解析到 `mail.example.com` 的 IP 地址。

## 配置 PTR 记录

为 `1.2.3.4` 配置反向解析，值为 `mail.example.com`。

## 配置 SPF 记录

| Type   | Host              | Answer              |
|--------|-------------------|---------------------|
| TXT    | example.com       | `v=spf1 mx ~all`    |
| SPF    | example.com       | `v=spf1 mx ~all`    |

## 配置 DKIM 记录

容器创建后，会在容器日志中显示公钥值，将其中的值按如下方式填写即可：

| Type   | Host                        | Answer              |
|--------|-----------------------------|---------------------|
| TXT    | mail._domainkey.example.com | `v=DKIM1; k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCi3zFH65YkLK+Edfu3VeZH2ylOpNC3ADfkL2p1PjhWQXrzn65rvrh2YTqEEb8xGunWD9c422SBoxRdpVENhUqnbb1Tk0Xu58gfrN2muTIedFDtWx7irvySNtDgcWWIdXDaPFk/nodeutahtueaszEuLqI/DpKD/9mY9Mm5QIDAQAB`|

## 配置 DMARC 记录

| Type   | Host              | Answer              |
|--------|-------------------|---------------------|
| TXT    | _dmarc.example.com| `v=DMARC1; p=reject; rua=postmaster@mexample.com` |

## 测试

用一个简单 Node 程序来测试邮件服务是否可以正常工作。

```js
'use strict';

const nodemailer = require('nodemailer');

const transporter = nodemailer.createTransport({
  host: 'mail.example.com',
  port: 25,
  secure: false,
  requireTLS: true,
  auth: {
    user: 'user@mail.example.com',
    pass: 'passwd'
  },
});

// setup e-mail data with unicode symbols
var mailOptions = {
  from: '"BOSS" <boss@example.com>', // sender address
  to: '<your mail>', // list of receivers
  subject: '风中的来信', // Subject line
  text: '为了防止垃圾邮件，现在有许多 SMTP 服务器要求客户端的 IP 地址必须要能够查到有效的 PTR 记录。', // plaintext body
  html: '为了防止垃圾邮件，现在有许多 SMTP 服务器要求客户端的 IP 地址必须要能够查到有效的 PTR 记录。' // html body
};

// send mail with defined transport object
transporter.sendMail(mailOptions, function(error, info){
  if(error){
    return console.log(error);
  }
  console.log('Message sent: ' + info.response);
})
```

（完）


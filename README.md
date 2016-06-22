# docker-postfix
支持的 SMTP 验证的 Postfix 容器。 可选的 OpenDKIM 和 TLS 支持。

## 使用方法

> `user:passwd` 形如 `username@mail.example.com:password`。

### 创建支持 SMTP 验证的 Postfix 容器

    ```sh
    shell> docker run -p 25:25 \
               -e MTA_HOST=mail.example.com -e MTA_USERS=user:passwd \
               --name postfix -d m31271n/postfix
    # Set multiple user credentials: -e MTA_USERS=user1:passwd1,user2:passwd2,...,userN:passwdN
    ```
### 启用 OpenDKIM

    ```sh
    shell> docker run -p 25:25 \
               -e MTA_HOST=mail.example.com -e MTA_USERS=user:passwd \
               -v /path/to/domainkeys:/etc/opendkim/domainkeys \
               --name postfix -d m31271n/postfix
    ```
### 启用 TLS(587)

    ```sh
    shell> docker run -p 587:587 \
               -e MTA_HOST=mail.example.com -e MTA_USERS=user:passwd \
               -v /path/to/certs:/etc/postfix/certs \
               --name postfix -d m31271n/postfix
    ```

## DNS 设置
### 理论（引自 Postfix 权威指南）
与邮件系统的相关的 DNS 记录有：

* A
* MX
* PTR

#### 所有 MX 主机必须有合法的 A 记录
MX 记录所指的主机名称，必须要有一笔有效的 A 记录。因为 MTA 在选出收信主机之后，还必须查出其 IP 地址才能连接。


#### MX 记录不可以指向别名
MX 记录所指的主机名称，不应该是别名（CNAME 记录）。在正常情况下，当 MTA 在检查 MX 记录列表时，是依据自己的“规范名称”是否在列表中，
来决定要不要排除优先程序低于自己的 MX 主机。为了避免邮件循环，请确定列在 MX 记录中是规范名称，而不是别名。

就算 MTA 能接受 CNAME 记录（如果 MTA 能够查出并使用规范名称），也可能在递送邮件时造成问题。

#### MX 记录应该指向主机名称，而非 IP 地址
虽然目前将 MX 记录指向 IP 地址还不会出现问题，但是一句 RFC 974 的声明，你应该使用主机名称才对。如果将来网络有所改变（比如说，升级到 IPv6），
纯 IP 地址就可能在递送邮件时造成问题。

#### PTR 记录
为了防止垃圾邮件，现在有许多 SMTP 服务器要求客户端的 IP 地址必须要能够查到有效的 PTR 记录。

因此，你的 Postfix 系统的 IP 地址必须在 DNS 系统里有一个指向 Postfix 主机规范名称的 PTR 记录，这样才能保证所有 SMTP 服务器都愿意收下你寄出的邮件。

> PTR 记录的设置多由主机提供商提供。

### 实践
假设 Postfix 运行在 `email.m31271n.com` 上：

| Type   | Host              | Answer            |
|--------|-------------------|-------------------|
| A      | email.m31271n.com | 1.2.3.4           |
| MX     | m31271n.com       | email.m31271n.com |
| PTR    | 1.2.3.4           | email.m31271n.com |

## 参考
+ 《Postfix 权威指南》
+ [Postfix Standard Configuration Examples](http://www.postfix.org/STANDARD_CONFIGURATION_README.html)
+ [Postfix SASL Howto](http://www.postfix.org/SASL_README.html)
+ [Managing multiple Postfix instances on a single host](http://www.postfix.org/MULTI_INSTANCE_README.html)


<!-- markdown-toc start - Don't edit this section. Run M-x markdown-toc-generate-toc again -->
**Table of Contents**

- [docker-postfix](#docker-postfix)
    - [使用方法](#)
        - [创建支持 SMTP 验证的 Postfix 容器](#-smtp--postfix-)
        - [启用 OpenDKIM](#-opendkim)
        - [启用 TLS(587)](#-tls587)
    - [DNS 设置](#dns-)
        - [理论（引自 Postfix 权威指南）](#-postfix-)
            - [所有 MX 主机必须有合法的 A 记录](#-mx--a-)
            - [MX 记录不可以指向别名](#mx-)
            - [MX 记录应该指向主机名称，而非 IP 地址](#mx--ip-)
            - [PTR 记录](#ptr-)
        - [实践](#)
    - [避免你的邮件被当成垃圾邮件](#)
        - [确定发送的不是垃圾](#)
        - [查看你是否在黑名单中](#)
        - [配置 PTR 记录](#-ptr-)
        - [配置 SPF（Sender Policy Framework） 记录](#-spfsender-policy-framework-)
            - [SPF 记录的语法规则](#spf-)
            - [Mechanism](#mechanism)
                - [all](#all)
                - [ip4](#ip4)
                - [ip6](#ip6)
                - [a / mx](#a--mx)
                - [include](#include)
                - [exists](#exists)
                - [ptr](#ptr)
            - [Modifier](#modifier)
                - [redirect](#redirect)
                - [exp](#exp)
        - [配置 DKIM 记录](#-dkim-)
    - [测试](#)
    - [参考](#)

<!-- markdown-toc end -->

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

#### 所有 MX 主机必须有合法的 A 记录
MX 记录所指的主机名称，必须要有一笔有效的 A 记录。因为 MTA 在选出收信主机之后，还必须查出其 IP 地址才能连接。


#### MX 记录不可以指向别名
MX 记录所指的主机名称，不应该是别名（CNAME 记录）。在正常情况下，当 MTA 在检查 MX 记录列表时，是依据自己的“规范名称”是否在列表中，
来决定要不要排除优先程序低于自己的 MX 主机。为了避免邮件循环，请确定列在 MX 记录中是规范名称，而不是别名。

就算 MTA 能接受 CNAME 记录（如果 MTA 能够查出并使用规范名称），也可能在递送邮件时造成问题。

#### MX 记录应该指向主机名称，而非 IP 地址
虽然目前将 MX 记录指向 IP 地址还不会出现问题，但是一句 RFC 974 的声明，你应该使用主机名称才对。如果将来网络有所改变（比如说，升级到 IPv6），
纯 IP 地址就可能在递送邮件时造成问题。

### 实践
假设 Postfix 运行在 `mail.m31271n.com` 上：

| Type   | Host              | Answer            |
|--------|-------------------|-------------------|
| MX     | m31271n.com       | mail.m31271n.com  |
| A      | mail.m31271n.com  | 1.2.3.4           |

## 避免你的邮件被当成垃圾邮件
### 确定发送的不是垃圾
首先，确定你发送的不是垃圾。如果是，那就得学学反垃圾邮件的技术。

### 查看你是否在黑名单中
你的邮件服务器的域名或者 IP 进了邮件服务提供商（Email Service Provider）的黑名单。

由于中国的垃圾邮件发送者众多，再加上中国的 IPv4 地址很少，大部分的中国大陆 IP 都会出现在某个黑名单上，
所以被当成垃圾邮件也很正常。

可以通过 [MX Toolbox](http://www.mxtoolbox.com/blacklists.aspx) 来查询黑名单。

如果你确实在黑名单里，可以去列有你 IP 的黑名单的组织进行申诉，请求在黑名单上抹掉你。

### 配置 PTR 记录
PTR 记录，是电子邮件系统中的邮件交换记录的一种，也就是 IP 反向解析，通过设置 PTR 可以提高发信方信誉，提高送达率。

因此，你的 Postfix 系统的 IP 地址必须在 DNS 里有一个指向 Postfix 主机规范名称的 PTR 记录，这样才能保证所有 SMTP 服务器都愿意收下你寄出的邮件。

> PTR 记录的设置多由主机提供商提供。

可以通过 `dig -x IP` 来查看 PTR 记录是否设置正常。

### 配置 SPF（Sender Policy Framework） 记录

> SPF 是为了防止冒充邮件发送方身份而产生的技术。

一种以 IP 地址认证电子邮件发送方身份的技术。原理很简单：

假设邮件接收方收到了一封邮件，来自主机的 IP 是 `1.2.3.4`，并且声称邮件发送方为 `email@example.com`。
为了邮件发送方不是冒充的，邮件接收方会去查询域名 `example.com` 的 SPF 记录。
如果该域名的 SPF 记录设置允许 IP 为 `1.2.3.4` 的主机发送邮件，邮件服务器就认为这封邮件是合法的；
如果不允许，则通常会退信，或将其标记为垃圾/仿冒邮件。

> 不怀好意的人虽然可以声称他的邮件来自 `example.com`，但是他没法操作 `example.com` 的 DNS 记录，
> 同时他也无法伪造自己的 IP 地址。基于这两点，SPF 才变得可以信赖。


SPF 数据应该创建为 SPF 记录。但是很多 DNS 服务商并不支持 SPF 记录，有的邮件服务器也不支持 SPF 记录。
针对这种现状，OpenSPF 建议同时添加 SPF 记录和 TXT 记录都要添加。

| Type   | Host              | Answer              |
|--------|-------------------|---------------------|
| TXT    | m31271n.com       | `v=spf1 mx ~all`    |
| SPF    | m31271n.com       | `v=spf1 mx ~all`    |

这条记录表示发信 IP 指向的主机为可信主机， `~all` 表示除此以外的主机为软拒绝。

#### SPF 记录的语法规则

> 详细规则，请查阅 [SPF Record Syntax](http://www.openspf.org/SPF_Record_Syntax)，这里仅提供部分说明。

一条 SPF 记录定义了一个或者多个 Mechanism，而 Mechanism 则定义了哪些 IP 是允许的，哪些 IP 是拒绝的。

Mechanism 包括：
* `all`
* `ip4`
* `ip6`
* `a`
* `mx`
* `ptr`
* `exists`
* `include`

每个 Mechanism 可以有四种前缀：
* `+` Pass （通过）
* `-` Fail （拒绝）
* `~` Soft Fail （软拒绝）
* `?` Neutual （中立）

测试时，将从前往后依次测试每个 Mechanism。如果一个 Mechanism 包含了要查询的 IP 地址（称为命中），则测试结果由相应 Mechanism 的前缀决定。
默认的前缀为 `+`。如果测试完所有的 Mechanism，都没有命中，则结果为 Netual。

除了以上四种情况，还有 None（无结果）、PermError（永久错误）和 TempError（临时错误）三种其他情况。对于这些情况的解释和服务器通常的处理办法如下：

|结果|含义|服务器处理办法|
|----|---|-------------|
|Pass|发件 IP 是合法的|接受来信|
|Fail|发件 IP 是非法的|退信|
|Soft Fail|发件 IP 非法，但是不采取强硬措施|接受来信，但是做标记|
|Neutral|SPF 记录中没有关于发件 IP 是否合法的信息|接受来信|
|None|服务器没有设定 SPF 记录|接受来信|
|PermError|发生了严重错误（例如 SPF 记录语法错误）|没有规定|
|TempError|发生了临时错误（例如 DNS 查询失败）|接受或拒绝|

> 上面所说的「服务器处理办法」仅仅是 SPF 标准做出的建议，并非所有的邮件服务器都严格遵循这套规定。

#### Mechanism

> `v=spf1` 是必须写在头部的，它表示采用 SPF 第一版标准。

开始介绍上面提到的 Mechanism。

##### all
表示所有 IP，肯定会命中，因此通常把它放在 SPF 记录的结尾，表示处理剩下的所有情况，比如：

```
# 拒绝所有，表示这个域名不会发出邮件
v=spf1 -all
# 通过所有，域名所有者认为 SPF 没用，根本不鸟它。
v=spf1 +all
```

##### ip4
格式为 `ip4:<ip4-address>` 或者 `ip4:<ip4-network>/<prefix-length>`，指定一个 IPv4 地址或者地址段。
`prefix-length` 的默认值为 32。比如：

```
# 只允许在 192.168.0.1 ~ 192.168.255.255 范围内的 IP
v=spf1 ip4:192.168.0.1/16 -all
```

##### ip6
格式和 `ip4`的很类似，`prefix-length` 的默认值为 `128`。例如：

```
# 只允许在 1080::8:800:0000:0000 ~ 1080::8:800:FFFF:FFFF 范围内的 IP
v=spf1 ip6:1080::8:800:200C:417A/96 -all
```

##### a / mx
两者格式相同，以 `a` 为例，格式可为：

```
a
a/<prefix-length>
a:<domain>
a:<domain>/<prefix-length>
```

会命中相应域名的 A 记录或 MX 记录中包含的 IP 地址或地址段。如果没有提供域名，则使用当前域名，比如：

```
# 允许当前域名的 MX 记录对应的 IP 地址
v=spf1 mx -all

# 允许当前域名和 mail.example.com 的 MX 记录对应的 IP 地址
v=spf1 mx mx:mail.example.com -all

# 类似地，这个用法则允许一个地址段
v=spf1 a/24 -all
```

例子说完了，给出一个比较常见的 SPF 记录，它表示：通过当前域名 A 记录和 MX 记录所指向的 IP 地址，同时支持一个给定的
IP 地址，其他地址则拒绝。

```
v=spf1 a mx ip4:173.194.72.103 -all
```

##### include
格式为 `include:<domain>`，表示引入 `<domain>` 域名下的 SPF 记录。比如：

```
# 采用和 example.com 完全一样的 SPF 记录
v=spf1 include:example.com -all
```

> 如果 `<domain>` 下不存在 SPF 记录，则会导致一个 `PermError` 结果。

##### exists
格式为 `exists:<domain>`。对 `<domain>` 执行一个 A 查询，如果有返回结果（无论结果是什么），都会看作命中。

##### ptr
格式为 `ptr` 或者 `ptr:<domain>`。使用 `ptr` 会带来大量开销极大的 DNS 查询，所以官方不推荐使用它。

#### Modifier
SPF 记录中还可以包含两种可选的 Modifier，一个 Modifier 只能出现一次。
##### redirect
格式为 `redirect=<domain>`。用给定 <domain> 的 SPF 记录替换当前记录。

##### exp
格式为 `exp=<domain>`。如果邮件被拒绝，可以给出一个消息，消息的具体内容会先对 <domain> 进行 TXT 查询，然后执行宏拓展得到。

### 配置 DKIM 记录

## 测试
* 测试工具：[Mail Tester](http://www.mail-tester.com/)
* 测试方法：向页面上的邮箱随便发送一封邮件，然后点击提交可以看到测试结果，其中会有一些优化建议。

## 参考
+ 《Postfix 权威指南》
+ [Postfix Standard Configuration Examples](http://www.postfix.org/STANDARD_CONFIGURATION_README.html)
+ [Postfix Legacy TLS Support](http://www.postfix.org/TLS_README.html)
+ [Postfix SASL Howto](http://www.postfix.org/SASL_README.html)
+ [Managing multiple Postfix instances on a single host](http://www.postfix.org/MULTI_INSTANCE_README.html)

encoding
dkim
spf
dmarc
dns reverse record
mail blacklist
spamassassin

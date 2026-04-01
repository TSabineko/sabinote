+++
draft = false
date = 2026-04-01T12:00:00+09:00
title = "VPSとWireGuardでグローバルIPなし環境を外部公開する"
description = "VPS、VyOS、WireGuard を組み合わせて、自宅側のサービスを外部公開する設定を整理します。"
slug = "no-global-ip-external-publishing-detail"
tags = ["homelab", "network", "wireguard", "vps", "vyos"]
categories = ["homelab"]
series = []
+++

## 概要

この記事では、VPS 側と自宅側の VyOS を WireGuard で接続し、VPS 側で受けたアクセスを自宅側のサービスまで転送するところまでをまとめます。

自分の環境を構築したときの再現メモも兼ねているので、個人環境向けの手順になっています。細かな設計やセキュリティ要件は環境によって変わるので、そのままではなく参考情報として見てもらえると助かります。

## 前提

- VPS 側と自宅側の両方で VyOS を使っている
- 自宅側にはグローバル IP がなく、VPS 側を公開の受け口にする
- WireGuard で VPS 側と自宅側を常時接続する
- 今回は HTTP の転送を例にする

今回の記事で出てくるアドレスの役割は次のとおりです。

- `10.1.0.1/30`: Vultr 側 WireGuard インターフェース
- `10.1.0.2/30`: Kawasaki 側 WireGuard インターフェース
- `192.168.10.13`: 公開したい Web サービス VM のアドレス

## この記事で扱う構成

流れとしては、まず VPS 側と自宅側で WireGuard を張り、そのうえで Vultr 側で受けた 80 番ポートへのアクセスを WireGuard 越しに自宅側へ流します。さらに Kawasaki 側で Web サービス VM へ destination NAT することで、最終的に LAN 内のサービスまで到達させます。

## 手順1: WireGuard インターフェースを作成する

### Vultr 側

```bash
set interfaces wireguard wg01 address '10.1.0.1/30'
set interfaces wireguard wg01 description 'VPN-to-Kawasaki'
set interfaces wireguard wg01 port '51820'
```

### Kawasaki 側

```bash
set interfaces wireguard wg01 address '10.1.0.2/30'
set interfaces wireguard wg01 description 'VPN-to-Vultr'
set interfaces wireguard wg01 port '51820'
```

ここでは WireGuard 用のインターフェースを先に用意しています。`/30` を使っているので、VPS 側と自宅側の 2 台だけを結ぶ小さなネットワークとして扱う想定です。

## 手順2: 鍵を生成してインターフェースへ設定する

### 両方で同じ操作を実行する

```bash
generate pki wireguard key-pair install interface wg01
```

鍵を生成したら、相手側の公開鍵を控えて次の peer 設定で使います。

## 手順3: WireGuard の peer を設定する

### Vultr 側

```bash
set interfaces wireguard wg01 peer to-Kawasaki allowed-ips '0.0.0.0/0'
set interfaces wireguard wg01 peer to-Kawasaki persistent-keepalive '15'
set interfaces wireguard wg01 peer to-Kawasaki public-key '<Kawasaki_pubkey>'
```

### Kawasaki 側

```bash
set interfaces wireguard wg01 peer to-Vultr address '<address>'
set interfaces wireguard wg01 peer to-Vultr allowed-ips '0.0.0.0/0'
set interfaces wireguard wg01 peer to-Vultr persistent-keepalive '15'
set interfaces wireguard wg01 peer to-Vultr public-key '<Vultr_pubkey>'
```

今回は自宅側にグローバル IP がないので、VPS 側を待ち受けにして自宅側から接続する形を前提にしています。`<address>` には Vultr 側のグローバル IP または名前解決できるアドレスを入れます。

## 手順4: WireGuard の接続を確認する

### 両方で同じ操作を実行する

```bash
vyos@router:$
show interfaces wireguard wg01 summary
```

ハンドシェイクが確認できること、`wg01` に期待したアドレスが付いていることを見ておくと安心です。余裕があれば、Vultr 側から `10.1.0.2`、Kawasaki 側から `10.1.0.1` に ping を打って疎通を見ておくと次の切り分けがしやすくなります。

## 手順5: Vultr 側で受けた通信を WireGuard 側へ流す

ここでは VPS 側で受けた HTTP アクセスを、そのまま Kawasaki 側の WireGuard アドレスへ転送します。まず Vultr 側で受け口を作るイメージです。

```bash
set nat destination rule 10 destination port '80'
set nat destination rule 10 inbound-interface name 'eth0'
set nat destination rule 10 protocol 'tcp'
set nat destination rule 10 translation address '10.1.0.2'
set protocols static route 192.168.10.0/24 next-hop 10.1.0.2
```

ここで静的ルートも入れているのは、Vultr 側から見た `192.168.10.0/24` を WireGuard 越しに Kawasaki 側へ送るためです。必要に応じて `translation port` も追加できますが、今回は 80 番をそのまま内側へ流す前提です。HTTPS も公開するなら、同様に 443 番のルールも作ることになります。

## 手順6: Kawasaki 側で LAN 内の Web サービスへ転送する

- `192.168.10.13` は Web サービス VM の IP アドレス

Vultr 側から Kawasaki 側の `wg01` まで届いた通信を、最後に実際の Web サービス VM へ転送します。今回の構成では、Vultr 側と Kawasaki 側の 2 段階で destination NAT している形です。

```bash
set nat destination rule 10 destination port '80'
set nat destination rule 10 inbound-interface name 'wg01'
set nat destination rule 10 protocol 'tcp'
set nat destination rule 10 translation address '192.168.10.13'
```

## 手順7: Kawasaki 側の送信元 NAT を設定する

Kawasaki 側の LAN 内サービスが外へ出るときに戻り通信で困らないよう、必要に応じて source NAT も設定しておきます。`192.168.10.0/24` は Kawasaki 側のサブネットです。

```bash
set nat source rule 10 outbound-interface name 'eth0'
set nat source rule 10 source address '192.168.10.0/24'
set nat source rule 10 translation address 'masquerade'
set nat source rule 20 outbound-interface name 'eth0'
set nat source rule 20 source address '10.1.0.2/32'
set nat source rule 20 translation address 'masquerade'
```

eth0 はインターネット側のインターフェースです。
rule 10 は LAN 側の通信を外へ出すための設定で、rule 20 は WireGuard インターフェース自身の通信も外に出せるようにするための設定です。

## 手順8: Kawasaki 側の経路を VPN 優先にする

```bash
set protocols static route 0.0.0.0/0 next-hop 10.1.0.1
set protocols static route <address>/32 next-hop 192.168.11.1
```
`<address>` には Vultr 側のグローバル IP を入れます。Vultr 側そのものへの通信まで VPN に流してしまうとトンネルが不安定になるので、VPS のアドレスだけは元の経路へ逃がしています。

## 手順9: 動作確認をする

ここまで設定したら、少なくとも次の確認をしておくと安心です。

- WireGuard が両側で `up` になっているか
- Vultr 側から `10.1.0.2` に到達できるか
- Kawasaki 側から `10.1.0.1` に到達できるか
- Kawasaki 側から `192.168.10.13` に到達できるか
- 外部から Vultr 側の 80 番へアクセスしたときに、実際に Web サービスが表示されるか

Web サービス側でアクセスログを見られるなら、どこまで通信が届いているかを追いやすくなります。

## 詰まりやすいポイント

- WireGuard の鍵は作成しただけでは相手側設定に反映されないので、公開鍵の控え忘れに注意する
- `allowed-ips` の設定次第で意図しない経路になることがある
- NAT ルールは inbound interface を間違えると効かない
- デフォルトルートを VPN 側へ向ける場合は、VPS 自身への例外ルートを先に考えておく
- 80 番だけ設定している状態では HTTPS は通らない

## おわりに

今回は、自宅側にグローバル IP がない環境で、VPS と WireGuard を使って外部公開するところまでを整理しました。同じような構成を検討しているときのたたき台として、少しでも参考になればうれしいです。

<h1 align="center">scoop-ghproxy</h1>

<p align="center">给官方 <a href="https://github.com/ScoopInstaller/Scoop">Scoop</a> 加一个 GitHub 加速开关。</p>

---

这是 [ScoopInstaller/Scoop](https://github.com/ScoopInstaller/Scoop) 的 Fork，只多一个配置项 `github_proxy`。配上之后，GitHub 相关地址会自动套上你指定的加速前缀；不配时行为和官方完全一样。仓库每天自动同步官方。

## 和其他方案的区别

| 方案 | 加速范围 | 限制 |
|---|---|---|
| 本 Fork | 任意 bucket 的 GitHub 下载、`scoop update`（本体、桶） | — |
| [scoop-cn](https://github.com/duzyn/scoop-cn) / [scoop-proxy-cn](https://github.com/lzwme/scoop-proxy-cn) | 只有自己的 bucket（改 manifest） | 加速地址写死，不能换 |
| [Gitee 中国版](https://gitee.com/scoop-installer/scoop) | 内置代理 + 镜像 bucket | 镜像大多只支持 GitHub，其它源直接下不动|

## 配置

```console
scoop config github_proxy https://your-proxy.example.com/   # 开启
scoop config github_proxy                                   # 查看
scoop config rm github_proxy                                # 关闭
```

只改写这三个主机：`github.com`、`raw.githubusercontent.com`、`objects.githubusercontent.com`。

```
https://github.com/user/repo/releases/download/v1/app.zip
↓
https://your-proxy.example.com/https://github.com/user/repo/releases/download/v1/app.zip
```

其它地址不动。manifest 里本来就套了代理的会先剥掉外层再重新套，`gh-proxy.com/github.com/...`、`gh-proxy.com/http://github.com/...`、多层嵌套都能认。

配置对这三处生效：

- 应用下载（Release）。
- 拉桶（`scoop update`）：先走加速地址，失败回退直连。改写只在这一次 `git pull` 里生效（git 的 `insteadOf`），桶的 remote 不改，`scoop bucket list` 还是原地址。
- 更新本体（`scoop update`）：直接按 `scoop_repo` 拉取，地址剥掉旧前缀后套当前加速地址，本体的 `remote.origin.url` 不参与判断也不会被改。

## 安装

已经在用官方 Scoop：

```powershell
# 首次切换要带加速前缀，把xxx.com换成你自己的镜像
scoop config scoop_repo https://xxx.com/https://github.com/dingyanwu/scoop-ghproxy
scoop config github_proxy https://xxx.com/
scoop update
```

切过来之后 `scoop_repo` 带不带前缀都行。如果卡在 git 上，删掉 `$(scoop prefix scoop)\.git` 再跑一次，会按 `scoop_repo` 重新克隆。

回官方：

```powershell
scoop config scoop_repo https://github.com/ScoopInstaller/Scoop
scoop update                 # 会提示确认离开本 Fork，输入 y
scoop config rm github_proxy
```

全新安装：

```powershell
irm https://xxx.com/https://raw.githubusercontent.com/dingyanwu/scoop-ghproxy/master/install.ps1 | iex
```

`xxx.com` 换成能用的加速地址，装完之后自更新和下载继续用它。

> 安装脚本改自[官方安装器](https://github.com/ScoopInstaller/Install)：仓库换成本 Fork，并从安装 URL 识别加速前缀。`-ScoopDir`、`-Proxy` 等参数与官方一致。

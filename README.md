<h1 align="center">scoop-ghproxy</h1>

<p align="center">在官方 <a href="https://github.com/ScoopInstaller/Scoop">Scoop</a> 上添加一个 GitHub 下载加速的开关。</p>

---

这是 [ScoopInstaller/Scoop](https://github.com/ScoopInstaller/Scoop) 的 Fork，只多了一个配置项 `github_proxy`：给 GitHub 下载地址自动加上加速前缀，解决 Release 下载慢的问题，
不配置时行为和官方完全一样，每天自动同步官方。

## 和其他方案的区别

| 方案 | 做法 | 加速范围 | 优点 | 缺点 |
|------|------|------|------|------|
| **本 Fork** | 改 Scoop 下载引擎 | 任意 bucket 的 GitHub 下载 | 加速地址自己定、随时可关；官方/第三方 bucket 都能加速；一键脚本自带加速安装 | 感觉没什么缺点了.. |
| [scoop-cn](https://github.com/duzyn/scoop-cn) / [scoop-proxy-cn](https://github.com/lzwme/scoop-proxy-cn) | 改 manifest | 仅自己的 bucket | 开箱即用 | 加速地址写死不能换，速度往往很慢 |
| [Gitee 中国版 Scoop](https://gitee.com/scoop-installer/scoop) | 托管在 Gitee | 内置代理 + 镜像 bucket | 国外流量全走镜像加速 | 很多镜像只支持 GitHub 加速，不支持其它地址加速，需频繁开关URL_PROXY |

本 Fork 的核心区别：加速和软件桶解耦，代理地址自己定、随时可关，内置下载器和 aria2 都生效。

## `github_proxy` 是怎么工作的

只改写这三个主机的地址：`github.com`、`raw.githubusercontent.com`、`objects.githubusercontent.com`。

```console
scoop config github_proxy https://your-proxy.example.com/   # 启用
scoop config github_proxy                                    # 查看
scoop config rm github_proxy                                 # 关闭
```

配置后，

`https://github.com/user/repo/releases/download/v1/app.zip`

会变成

 `https://your-proxy.example.com/https://github.com/user/repo/releases/download/v1/app.zip`。

非 GitHub 地址不受影响。

## 安装

Scoop 的流量分两类，要分别加速：

- **git 操作**（拉本体、`bucket add`）：靠给仓库地址加加速前缀（`scoop_repo`）；
- **应用下载**（Release）：靠设置 `github_proxy` 参数。

下面用 [`gh-proxy.org`](https://gh-proxy.org) 做加速说明。

### 已装官方 Scoop


```powershell
# 把自更新源切到本 Fork（加速前缀 + 完整地址）
scoop config scoop_repo https://gh-proxy.org/https://github.com/dingyanwu/scoop-ghproxy

# 删掉本体目录里残留的 .git、.github，避免切源后 scoop update 不生效（自动定位路径）
$dir = scoop prefix scoop
Remove-Item "$dir\.git", "$dir\.github" -Recurse -Force -ErrorAction SilentlyContinue

scoop update

# 开启下载加速
scoop config github_proxy https://gh-proxy.org/
```


恢复官方：

```powershell
scoop config scoop_repo https://github.com/ScoopInstaller/Scoop
scoop config rm github_proxy
scoop update
```

### 全新安装

用加速地址跑安装脚本，直接装本仓库的版本（本体、main 桶、`scoop_repo`、`github_proxy` 都会自动配好）：

```powershell
irm https://gh-proxy.org/raw.githubusercontent.com/dingyanwu/scoop-ghproxy/master/install.ps1 | iex
```

**加速地址就是命令里用的那个前缀，脚本会自动识别**，装完继续用它自更新和下载。想换加速地址或直连，直接改命令里的前缀就行：

```powershell
# 换成别的加速地址
irm https://xxx.com/https://raw.githubusercontent.com/dingyanwu/scoop-ghproxy/master/install.ps1 | iex

# 不用镜像（直连 GitHub）
irm https://raw.githubusercontent.com/dingyanwu/scoop-ghproxy/master/install.ps1 | iex
```

> 脚本改自[官方安装器](https://github.com/ScoopInstaller/Install)，只是把写死的 `ScoopInstaller/Scoop` 换成本 Fork，并从安装 URL 自动识别加速地址套到所有 GitHub 地址上。其余参数（`-ScoopDir`、`-Proxy` 等）与官方一致。


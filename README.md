# Shadowsocks macOS Client

> macOS Apple Silicon 原生 Shadowsocks 代理客户端 — SwiftUI + shadowsocks-rust

## System Requirements

- macOS 13.0 (Ventura) or above
- Apple Silicon (M1/M2/M3/M4) or Intel (x86_64)

## Features

- **原生 M芯片支持** — ARM64 原生编译，利用 AES/NEON/SHA3 硬件加速
- **SOCKS5 + PAC** — 系统代理一键开启，PAC 模式国内直连国外代理
- **订阅导入** — SIP002 URL + SIP008 JSON 自动解析，定时更新
- **延迟测试** — 批量测速 + 自动排序，快速选择最优节点
- **崩溃恢复** — sslocal 进程崩溃自动重启（最多 3 次）
- **安全存储** — 密码存 Keychain，配置存 UserDefaults
- **状态栏应用** — MenuBarExtra 界面，无 Dock 图标，轻量运行

## Building

### 方式一：xcodegen（推荐）

```bash
# 安装 xcodegen
brew install xcodegen

# 生成 Xcode 项目
cd Shadowsocks
xcodegen generate

# 打开项目
open Shadowsocks.xcodeproj

# 或命令行构建
xcodebuild -scheme Shadowsocks -destination 'platform=macOS,arch=arm64' build
```

### 方式二：手动 Xcode 设置

1. Xcode → File → New → Project → macOS → App
2. Product Name: Shadowsocks, Interface: SwiftUI, Language: Swift
3. Minimum macOS: 13.0
4. 参考 `XCODE_SETUP.md` 中的详细步骤

### 嵌入 sslocal 二进制

```bash
# 下载 shadowsocks-rust 的 macOS ARM64 release
# https://github.com/shadowsocks/shadowsocks-rust/releases
# 将 sslocal 放入 Resources/ 目录

# 或从源码编译
cargo build --release --target aarch64-apple-darwin \
  --features local-http,local-tun,local-online-config,aead-cipher-2022
cp target/aarch64-apple-darwin/release/sslocal Resources/sslocal
```

### 运行测试

```bash
xcodebuild test -scheme Shadowsocks -destination 'platform=macOS,arch=arm64'
```

## Architecture

| 层 | 技术 | 作用 |
|---|---|---|
| **GUI** | SwiftUI + MenuBarExtra | 状态栏界面 + 设置窗口 |
| **编排** | ProxyService | 统一代理控制（启动/停止/崩溃恢复） |
| **引擎** | SslocalBridge → Process | 管理 sslocal 子进程生命周期 |
| **配置** | SslocalConfig → JSON | 生成 shadowsocks-rust 配置文件 |
| **系统** | SystemProxyService → networksetup | macOS SOCKS5 + PAC 系统代理 |
| **网络** | NetworkService → NWConnection | 延迟测试 + 连通性检查 |
| **订阅** | SubscriptionParser | SIP002/SIP008 解析 |
| **存储** | ServerStore + KeychainHelper | 配置持久化 + 安全密码存储 |
| **加速** | CryptoAccelerator | M芯片硬件加速检测 |

## Project Structure

```
Shadowsocks/
├── App/                          → SwiftUI App 入口 + AppDelegate
│   ├── ShadowsocksApp.swift      → MenuBarExtra 主入口
│   └── AppDelegate.swift         → 生命周期管理 + 代理回滚
├── Models/                       → 数据模型
│   ├── Server.swift              → 服务器配置 + 加密方式枚举
│   ├── ServerStore.swift         → CRUD + Keychain 密码管理
│   └── Subscription.swift        → 订阅配置 + Store
├── Services/                     → 业务逻辑层
│   ├── ProxyService.swift        → 代理控制编排 + 崩溃恢复
│   ├── SystemProxyService.swift  → macOS 系统代理设置/回滚
│   ├── NetworkService.swift      → 延迟测试 + SOCKS5 连通性
│   ├── SubscriptionService.swift → SIP002/SIP008 解析器
│   └── SubscriptionUpdateService.swift → 订阅获取+合并
├── Bridges/                      → Swift ↔ sslocal 桥接
│   ├── SslocalBridge.swift       → 进程管理（启动/停止/日志）
│   ├── SslocalConfig.swift       → 配置文件生成
├── Utils/                        → 工具
│   ├── KeychainHelper.swift      → macOS Keychain 安全存储
│   ├── PasteboardParser.swift    → 剪贴板 ss:// URL 检测
│   ├── CryptoAccelerator.swift   → M芯片硬件加速检测
├── Views/                        → SwiftUI 视图
│   ├── StatusBarView.swift       → 状态栏主面板
│   ├── ServerListView.swift      → 服务器管理 + 添加
│   ├── ServerDetailView.swift    → 服务器详情编辑 + 测速
│   ├── SubscriptionView.swift    → 订阅管理 + 更新
│   ├── SettingsView.swift        → 设置面板（4个Tab）
├── Resources/                    → 资源
│   ├── Info.plist                → LSUIElement=true 无Dock图标
│   ├── Shadowsocks.entitlements  → 网络权限
│   ├── Assets.xcassets           → 图标资源
│   ├── default-pac.js            → PAC 文件模板
│   ├── sslocal                   → 嵌入的 Rust 二进制（需手动下载）
├── Tests/                        → 测试
│   ├── ShadowsocksTests/         → 单元+集成测试
│   ├── ShadowsocksUITests/       → UI 测试
├── .github/workflows/            → CI/CD
│   ├── ci.yml                    → 构建+测试
│   ├── release.yml               → Release + DMG 打包
├── homebrew/                     → 分发
│   └── shadowsocks-macos.rb      → Homebrew Cask formula
├── project.yml                   → xcodegen 项目配置
└── .swiftlint.yml                → SwiftLint 规则
```

## Cipher Methods & Hardware Acceleration

| 加密方式 | 类型 | M芯片 AES 加速 | 推荐度 |
|---------|------|:---:|:---:|
| `2022-blake3-aes-256-gcm` | AEAD-2022 | ✅ | ⭐⭐⭐⭐⭐ |
| `2022-blake3-aes-128-gcm` | AEAD-2022 | ✅ | ⭐⭐⭐⭐⭐ |
| `2022-blake3-chacha20-poly1305` | AEAD-2022 | ❌ (NEON) | ⭐⭐⭐⭐ |
| `aes-256-gcm` | AEAD | ✅ | ⭐⭐⭐⭐ |
| `aes-128-gcm` | AEAD | ✅ | ⭐⭐⭐⭐ |
| `chacha20-ietf-poly1305` | AEAD | ❌ (NEON) | ⭐⭐⭐ |

## License

MIT

# 工具使用手册：Wireshark / SimpleLauncher / Web海图前端

> 生成时间：2026-03-03  
> 配合文档：`系统报告_全船信息系统.md`

---

## 一、Wireshark —— 网络抓包分析工具

### 1.1 它在本系统中的角色

全船信息系统的**核心数据传输协议是 UDP**。`ship_info_system.py` 监听约30个 UDP 端口，与十几台船载设备（IMU、雷达、PLC、柴油机等）通过 UDP 通信。当出现以下问题时，Wireshark 是首选的诊断工具：

- **数据不上来**：某个传感器数据在 Redis 中没有更新
- **设备连接丢失**：`LOST` 标志变为 0
- **数据异常**：数值跳变、乱码、解析报错
- **新设备接入**：需要确认数据格式和端口
- **调试转发规则**：验证数据是否正确转发到目标 IP/端口

### 1.2 启动方式

```bash
# 方式1：命令行启动（需要root权限抓包）
sudo wireshark

# 方式2：桌面应用菜单搜索 "Wireshark" 启动
```

### 1.3 常用使用场景与过滤器

#### 场景A：检查 IMU(GPS) 数据是否到达

当 Redis 中 `LOST:GPS` = 0 或 IMU 数据不更新时：

```
# 过滤 IMU UniStrong 数据（端口 8819）
udp.dstport == 8819

# 或按来源设备过滤
ip.src == 193.0.1.xx && udp
```

操作步骤：
1. 打开 Wireshark → 选择对应网卡（通常选能看到 193.0.1.x 网段的网卡）
2. 在过滤器栏输入 `udp.dstport == 8819`
3. 观察是否有数据包到达：
   - **有包但程序无反应** → 检查 `ship_info_system.py` 是否在运行、端口是否被占用
   - **无包** → 设备端物理线路/配置问题

#### 场景B：检查雷达融合数据

```
# 渔船融合雷达（端口 9090）
udp.dstport == 9090

# 辽无二雷达（端口 9191）
udp.dstport == 9191

# Gewo雷达变换后（端口 6555 → 转发到 9191）
udp.dstport == 6555
```

#### 场景C：检查全信向设备发出的控制指令

```
# 舵机控制指令（发往 193.0.1.88 或 193.0.1.99）
ip.dst == 193.0.1.88 && udp
ip.dst == 193.0.1.99 && udp.dstport == 8500

# PLC 转速控制
ip.dst == 193.0.1.98 && udp.dstport == 8500

# 向大连雷达发送 GPS
ip.dst == 193.0.1.89 && udp.dstport == 3008

# 向 Gewo 雷达发送航向
ip.dst == 193.0.1.72 && udp.dstport == 20842
```

#### 场景D：检查全信向 Web 后端的数据转发

```
# 转发到 HaiTub 的雷达目标数据（端口 20003）
udp.dstport == 20003

# 转发到 USV 的数据（端口 6002）
udp.dstport == 6002
```

#### 场景E：查看本机所有 UDP 流量

```
# 所有进入本机的 UDP
udp && ip.dst == 193.0.1.73

# 所有从本机发出的 UDP
udp && ip.src == 193.0.1.73

# 排除干扰：只看船载设备网段
udp && ip.addr == 193.0.1.0/24
```

### 1.4 实用技巧

| 技巧 | 说明 |
|------|------|
| **查看数据内容** | 点击数据包 → 底部 "Data" 区域可以看到原始字节和 ASCII |
| **统计流量** | 菜单 Statistics → Conversations → UDP tab → 按 Bytes 排序 |
| **过滤 HEX 内容** | `udp contains "$GNGGA"` 过滤含 NMEA 报文的 GPS 数据 |
| **时间戳** | 设置 View → Time Display Format → Seconds Since Epoch，与日志对比 |
| **跟踪特定设备** | `ip.addr == 193.0.1.89` 查看与某设备的所有通信 |
| **查看丢包** | 对比发送频率和接收频率，Statistics → IO Graphs |
| **保存抓包** | File → Save As → 保存 .pcap 文件供后续分析 |

### 1.5 核心端口速查表（Wireshark 过滤用）

```
# ===== 全信接收端口（船载设备 → 本机）=====
udp.dstport == 8819    # IMU UniStrong (GPS/航向)
udp.dstport == 9090    # 渔船融合雷达
udp.dstport == 9191    # 辽无二雷达
udp.dstport == 6555    # Gewo雷达
udp.dstport == 6444    # 辽无二变幻
udp.dstport == 5678    # 舵反馈
udp.dstport == 6006    # 6081舵反馈
udp.dstport == 6001    # 转速反馈
udp.dstport == 5858    # PLC舵机数据(五元组)
udp.dstport == 6606    # 柴油机数据
udp.dstport == 6605    # 舵角传感器
udp.dstport == 6634    # 控制状态
udp.dstport == 6635    # 控制舵令
udp.dstport == 58553   # 融合雷达
udp.dstport == 58554   # 全局路径
udp.dstport == 6608    # AIS数据

# ===== 全信发送端口（本机 → 船载设备）=====
ip.dst == 193.0.1.88 && udp.dstport == 3000   # 6081舵机控制
ip.dst == 193.0.1.99 && udp.dstport == 8500   # PLC舵机控制
ip.dst == 193.0.1.98 && udp.dstport == 8500   # PLC转速控制
ip.dst == 193.0.1.89 && udp.dstport == 3008   # 大连雷达GPS
ip.dst == 193.0.1.72 && udp.dstport == 20842  # Gewo雷达航向
ip.dst == 193.0.1.65 && udp.dstport == 3000   # IMU转发
ip.dst == 193.0.1.65 && udp.dstport == 6165   # AIS转发
```

---

## 二、SimpleLauncher —— 跨平台进程启动器

### 2.1 它在本系统中的角色

SimpleLauncher 是一个**跨平台的进程管理器**，用于**统一管理和启动全船信息系统中的算法模块**。它不是管理 `ship_info_system.py` 或 Redis 的，而是管理避碰、路径规划、跟随等**上层算法进程**。

这些算法模块通过 Redis 和 UDP 与全信中枢交互。

### 2.2 程序位置与启动方式

```bash
# 可执行文件路径
/home/ship6081/module/SimpleLauncher

# 配置文件路径
/home/ship6081/module/launch.conf

# 启动方式
cd /home/ship6081/module/
./SimpleLauncher
```

### 2.3 管理的算法模块

SimpleLauncher 通过 `launch.conf` 配置管理以下进程：

| 模块名 | 可执行文件 | 分组 | 功能 | 自启 | 自动重启 |
|--------|-----------|------|------|------|----------|
| **ca_ms** | `neuAPF_6081_new/dist/ca_ms` | A | 避碰算法（新版，基于转速控制） | 否 | 是 |
| **follow** | `neuAPFFollow_6081/dist/follow` | A | 跟随模式算法 | 否 | 是 |
| **ca_rpm** | `neuAPF_6081_old/dist/ca_rpm` | B | 避碰算法（旧版，基于RPM控制） | 否 | 是 |
| **pathplan** | `pathplanning/ship_route_planner` | A,B | 路径规划算法 | 否 | 是 |
| **chart** | `chart` | 无 | 海图应用（桌面版） | 否 | 否 |
| **scan** | `plow` | 无 | 扫描模式（耕地式扫描） | 否 | 是 |

### 2.4 分组机制

```json
"groupModes": {
    "A": { "mode": "on" },   // A组：新版避碰 + 跟随 + 路径规划
    "B": { "mode": "off" }   // B组：旧版避碰 + 路径规划（默认关闭）
}
```

- **A组**（默认开启）：`ca_ms`（新避碰） + `follow`（跟随） + `pathplan`（路径规划）
- **B组**（默认关闭）：`ca_rpm`（旧避碰） + `pathplan`（路径规划）
- A、B 组互斥：同时只应启用一组避碰算法

### 2.5 何时使用 SimpleLauncher

| 场景 | 操作 |
|------|------|
| **启动自动导航** | 在 Web 前端切换到"自动导航"后，需通过 SimpleLauncher 启动 `ca_ms` + `pathplan` |
| **启用跟随模式** | 在 Web 前端选择"跟随模式"后，需启动 `follow` 模块 |
| **扫描作业** | 选择"扫描模式"后，需启动 `scan`（plow）模块 |
| **切换避碰版本** | 关闭 A 组、启用 B 组 → 切换到旧版避碰算法 |
| **查看桌面海图** | 启动 `chart` 模块 → 打开 Qt/OpenGL 桌面海图应用 |
| **模块崩溃** | SimpleLauncher 配置了 `autoRestart: true`，大部分模块会自动重启 |
| **调试算法** | 可以单独停止/启动某个模块，观察日志 |

### 2.6 配置说明

`launch.conf` 中每个模块的关键参数：

```
path            - 可执行文件路径
group           - 所属分组（A/B），决定是否随组启停
autoStart       - 是否随 SimpleLauncher 自动启动
autoRestart     - 崩溃后是否自动重启
postLaunchDelay - 启动后延迟（秒），ca_ms 设为5秒等待初始化
```

### 2.7 与全信系统的交互关系

```
SimpleLauncher
  ├── ca_ms (避碰) ──── 读Redis(IMU/data:*/Navi) → 计算避碰 → 写Redis(TargetDuo等)
  ├── follow (跟随) ─── 读Redis(IMU/data:目标) → 计算跟随 → 写Redis
  ├── pathplan ──────── 读Redis(Navi:GPath) → 路径规划 → 写Redis(Navi:LPath)
  ├── scan (扫描) ───── 读Redis → 生成扫描路径 → 写Redis
  └── chart (海图) ──── 独立桌面应用，通过UDP接收数据显示
```

---

## 三、Web 海图前端 (`1_shilliang.html`) —— 智能辅助驾驶系统界面

### 3.1 它在本系统中的角色

这是整个系统的**主要人机交互界面**，运行在浏览器中，用于：
- 显示矢量电子海图（S-57）
- 显示本船位置、航向、航速
- 显示所有目标船（雷达/AIS融合）及碰撞警报
- 编辑和管理航线
- 切换驾驶模式（手动/自动）
- 控制导航功能（避碰/跟随/扫描/靠泊/定点定向）

### 3.2 访问方式

```
# 在浏览器中打开（本机或同网段任意设备）
http://193.0.1.73:8899/1_shilliang.html

# 或使用 localhost
http://localhost:8899/1_shilliang.html
```

### 3.3 技术架构

```
浏览器页面 (1_shilliang.html)
│
├── 前端框架: Vue.js 2 + Element UI
├── 地图引擎: MapLibre GL JS (矢量渲染)
├── 底图数据: TileServer-GL (localhost:8383) → S-57 MBTiles
│
├── WebSocket 连接:
│   ├── ws://host:18080  ← 接收 Navi + IMU + LOST 数据 (1Hz)
│   ├── ws://host:8181   ← 接收所有目标船 data:* 数据 (1Hz)
│   └── ws://host:8282   → 发送航线编辑数据 (GPath)
│
├── REST API 连接 (http://host:3000):
│   ├── GET  /api/get-checkbox-status    ← 获取手动/自动状态
│   ├── POST /api/set-checkbox-status    → 设置手动/自动状态
│   ├── POST /api/set-redis              → 通用 Redis 写入
│   ├── GET  /api/get-Sudu-status        ← 获取目标速度
│   ├── POST /api/set-Sudu-status        → 设置目标速度
│   ├── GET  /api/get-BiPeng-status      ← 获取避碰开关
│   ├── POST /api/set-BiPeng-status      → 设置避碰开关
│   └── GET  /api/History_Gpath          ← 获取历史航线列表
│
└── Socket.IO 连接 (http://host:3030):
    └── 实时事件广播（状态变更同步）
```

### 3.4 界面功能区域详解

#### 顶部导航栏
- 标题：**智能辅助驾驶系统** (Intelligent Advanced Driver Assistance System)
- Logo显示

#### 左侧主区域 —— 矢量海图
- **海图底图**：S-57 矢量海图，包含水深、陆地、浮标、航道、障碍物等图层
- **本船标记**：实时显示本船位置和航向
- **目标船标记**：显示所有雷达/AIS探测到的目标船，含碰撞警报颜色
- **航线显示**：全局路径(GPath)和局部路径(LPath)
- **轨迹线**：本船和目标船的历史轨迹

#### 地图控件（右侧悬浮）
| 控件 | 功能 |
|------|------|
| 全屏按钮 | 切换全屏模式 |
| 轨迹按钮 | 显示/隐藏本船轨迹、目标船轨迹、清空轨迹 |
| 围栏按钮 | 绘制/显示电子围栏 |
| +/- 按钮 | 地图缩放 |
| N/H/C 按钮 | 北向上(North Up) / 艏向上(Head Up) / 航向上(Course Up) 切换 |
| 方向盘控件 | 上下左右平移地图，中心锁定按钮 |
| 缩放滑块 | 精确控制地图缩放级别 |

#### 底部信息栏
| 显示项 | 数据来源 |
|--------|----------|
| 经度/纬度 | Redis:IMU → WebSocket:18080 |
| 航向(COG) | Redis:IMU:angle |
| 艏向(HDG) | Redis:IMU:heading |
| 航速(节) | Redis:IMU:speed |

#### 右侧面板 —— 航行配置
| 功能区 | 说明 |
|--------|------|
| **航行速度** | RPM 显示 + 滑动条调节（0/450/550/650/750/850） |
| **驾驶模式** | 手动/自动 下拉选择 → 写入 Redis:Navi:State |
| **报警控制** | 报警声音开关、自动避碰紧急处理开关 |
| **导航模式** | 6种模式切换（见下表） |
| **导航设置** | 根据当前模式动态显示不同设置项 |
| **消息列表** | 系统事件和报警消息 |
| **设备状态灯** | 各子系统连接状态（绿色正常/红色异常） |

### 3.5 六种导航模式操作指南

| 模式 | 界面操作 | 对应 SimpleLauncher 模块 | Redis 交互 |
|------|----------|--------------------------|------------|
| **编辑航线** | 在地图上点击画航线点 → "保存航线" | 无需额外模块 | 写入 `Navi:GPath` |
| **自动导航** | 勾选"局部避碰"/"自动舵" → 自动沿航线行驶 | `ca_ms` + `pathplan` | 读 GPath，写 LPath/TargetDuo |
| **跟随模式** | 输入目标ID、跟随方位角、跟随距离 → 勾选"开始跟随" | `follow` | 写 `Follow_Mode` |
| **扫描模式** | "绘制扫描区域" → 画多边形 → "开始扫描" | `scan` (plow) | 写 `Scan_Mode` |
| **靠泊模式** | 输入泊位ID → 勾选"开始靠泊" | 待确认 | 写相关控制键 |
| **定点定向** | 勾选"稳如泰山" → 船舶保持当前位置和朝向 | 待确认 | 写相关控制键 |

### 3.6 典型使用流程

#### 流程1：编辑航线并启动自动导航

```
1. 打开浏览器 → http://193.0.1.73:8899/1_shilliang.html
2. 右侧面板 → 导航模式 → 选择"编辑航线"
3. 点击"编辑航线"按钮 → 在地图上依次点击航点
4. 点击"保存航线" → 航线数据写入 Redis:Navi:GPath
5. 导航模式 → 选择"自动导航"
6. 驾驶模式 → 选择"自动"
7. 勾选"局部避碰"（可选）和"自动舵"
8. 确保 SimpleLauncher 中 ca_ms + pathplan 已启动
9. 系统开始自动沿航线行驶
```

#### 流程2：跟随目标船

```
1. 在地图上点击目标船 → 获取目标ID
2. 导航模式 → 选择"跟随模式"
3. 输入目标ID、跟随方位(°)、跟随距离(m)
4. 勾选"开始跟随"
5. 确保 SimpleLauncher 中 follow 模块已启动
```

#### 流程3：查看系统健康状态

```
1. 底部信息栏 → 检查经纬度/航速是否更新
2. 设备状态灯 → 绿色=正常，红色=异常
3. 如某设备红灯 → 用 Wireshark 抓对应端口排查
```

### 3.7 前端 → Redis → 设备 的完整闭环示例

以"设置目标速度"为例：

```
用户在前端拖动速度滑条 → 850
    ↓
前端调用 POST /api/set-Sudu-status {status: 850}
    ↓
HaiTub/app.js → redis.hSet('Navi', 'TargetSpeed', '850')
    ↓
ship_info_system.py 定时器读取 Redis:Navi
    ↓
PLC_zhuan_suCTRL() → 打包为字节 → UDP发送到 193.0.1.98:8500
    ↓
PLC 接收指令 → 控制柴油机转速
    ↓
柴油机转速反馈 → UDP:6001 → zhuansu_fankui_QJ() → Redis:engine_parameters:zhuan_su
    ↓
DataToUI() → UDP:16161 → 前端显示当前转速
```

---

## 四、三个工具的协作关系

```
┌─────────────────────────────────────────────────────────────────┐
│                       操作员日常使用流程                          │
│                                                                 │
│  1. 启动 SimpleLauncher  ← 管理算法模块(避碰/路径/跟随/扫描)     │
│         ↓                                                       │
│  2. 打开 Web海图前端      ← 查看海图、编辑航线、切换模式、监控     │
│         ↓                                                       │
│  3. 遇到问题用 Wireshark  ← 诊断UDP通信、排查设备连接、抓包分析   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

| 工具 | 使用频率 | 使用时机 |
|------|----------|----------|
| **Web海图前端** | 每次使用系统时 | 核心操作界面，始终打开 |
| **SimpleLauncher** | 每次启动系统时 | 启动/管理算法模块，启动后可最小化 |
| **Wireshark** | 出问题时 | 数据不上来、设备离线、指令不到达时用于诊断 |

---

*手册结束*

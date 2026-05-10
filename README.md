# MirrorImage

macOS 原生高性能图片/视频对比浏览工具，面向摄影师、视频工作者等专业用户。

## 平台要求

| 属性 | 值 |
|------|-----|
| 操作系统 | macOS 14+（Sonoma 及以上） |
| 芯片 | Apple Silicon（M1+）；Intel 兼容但不保证 HDR/AV1 特性 |
| Swift | 5.9+ |

## 技术栈

- **SwiftUI** — 导航、文件管理、设置等上层 UI
- **AppKit** — `CALayer` + `AVPlayerLayer` + Core Animation，负责渲染核心，对 EDR/HDR、手势事件链、自定义布局有完整控制力
- **ColorSync** — 系统色彩管理，自动匹配显示器
- **VideoToolbox** — 视频硬件解码

## 架构

```
MirrorImage.app
├── App Layer (SwiftUI)
│   ├── ContentView              // 顶层路由：首页 / 对比模式
│   ├── HomeView
│   │   ├── SidebarView          // 左侧：多选目录树
│   │   └── ContentArea          // 右侧：筛选栏 + 多列文件列表
│   └── DiffView                 // 对比模式容器（NSViewRepresentable 桥接）
│       ├── ImageDiffView
│       └── VideoDiffView
│
├── Rendering Core (AppKit)
│   ├── ComparisonView           // 核心 NSView：动态子图层布局
│   ├── LayoutEngine             // 自适应布局计算
│   ├── HistogramOverlay         // 直方图叠加层（H 键切换）
│   ├── ZoomController           // 缩放控制器（全局/单图双模式）
│   ├── ImageLayerController     // 图片图层管理
│   ├── VideoLayerController     // 视频图层管理
│   └── AudioAlignmentEngine     // 视频音频指纹帧对齐
│
├── Data Layer
│   ├── FileBrowserModel         // 文件系统扫描、目录树构建
│   ├── ComparisonViewModel      // 对比状态管理
│   ├── HomeViewModel            // 首页状态管理
│   └── MediaMetadataProvider    // 元数据提取
│
└── Services
    ├── ThumbnailGenerator       // 异步缩略图 + 双层缓存
    ├── ThumbnailCache           // L1 内存 / L2 磁盘缓存
    └── HistogramCalculator      // 亮度/色彩直方图计算
```

## 功能

### 文件浏览

- **多选目录树** — 左侧 checkbox 多选文件夹，支持 Cmd/Shift 批量选择，递归懒加载子目录
- **多列文件列表** — 每个选中文件夹独立一列，水平滚动，每列独立竖向滚动
- **全局筛选** — 全部 / 仅图片 / 仅视频（Segmented Picker）
- **缩略图网格** — QLThumbnailGenerator 硬件加速生成，双层缓存（L1 内存 200 张 / L2 磁盘 500MB LRU），保留 Display P3 色彩空间
- **文件系统监听** — FSEvents 自动刷新当前目录变更

### 图片对比

- 自适应布局：2 张左右均分、3 张竖排均分、4 张田字形 2×2、5-20 张竖排均分
- 等比缩放适配图层（contentsRect），不拉伸变形，纯黑背景
- **全局缩放**（鼠标滚轮，以窗口中心为锚点）/ **单图缩放**（Cmd+滚轮，以鼠标位置为锚点）
- 缩放范围 0.1x ~ 50x，支持缩放后拖拽平移
- 数字键 1-9 切换同组内对应图层显隐
- 色彩管理：`CALayer.contents` 绑定 CGImage 保留嵌入 ICC Profile，Core Animation + ColorSync 自动匹配

### 视频对比

- 分组与布局同图片对比，进入时所有视频自动 seek 到开头，不自动播放
- **同步控制模式** — 空格同步播放/暂停，← → 同步快进/快退 5 秒
- **独立控制模式** — 单击视频图层进入，空格仅控制当前视频，支持独立 seek
- **音频指纹帧对齐（Q 键）** — 提取 PCM → FFT 频谱峰值 → 低维特征向量 → 归一化互相关（NCC）匹配，帧级精度（±33ms）
- HDR 支持：`NSWindow.wantsExtendedDynamicRangeContent = true`，HDR10+ / 杜比视界元数据自动直通，画质对标 QuickTime
- 立体声归一化为单声道匹配，采样率不匹配统一重采样到 16kHz

### 直方图

- H 键全局切换，每张图/视频左下角叠加显示
- 白线：亮度直方图（256 bins）；红绿蓝三线叠加：色彩直方图
- 半透明背景 `rgba(0,0,0,0.35)` 圆角样式
- 图片使用 `CIFilter.areaHistogram` / vImage 异步计算
- 视频播放每 500ms 采样一帧更新

### 动态照片（Live Photos）

- 识别 `.heic` + 同名 `.mov` 配对
- 右键菜单 / 空格弹窗选择"作为图片对比"或"作为视频对比"

### 窗口模式

- 默认窗口模式，可自由缩放
- Cmd+Ctrl+F 全屏进入专属 Space，纯黑背景
- 外接显示器独立评估 EDR headroom

## 支持的格式

### 图片

| 格式 | 解码 | 位深 | 色域 |
|------|------|------|------|
| JPEG | CGImageSource | 8bit | sRGB/P3 |
| PNG | CGImageSource | 8/16bit | sRGB/P3 |
| HEIC | CGImageSource (HIF) | 8/10/12bit | P3/HLG |
| WebP | CGImageSource | 8bit | sRGB |
| TIFF | CGImageSource | 8/16bit | sRGB/P3/AdobeRGB |
| RAW (CR2/NEF/ARW) | CGImageSource + 内嵌预览 | 10-14bit | 相机原生 |
| PSD | CGImageSource (合并快照) | 8/16bit | 嵌入 Profile |
| GIF | CGImageSource (首帧) | 8bit | sRGB |

### 视频

| 编码 | 解码 | HDR 格式 |
|------|------|---------|
| H.264 | VideoToolbox | SDR |
| H.265 | VideoToolbox | HDR10/HLG/Dolby Vision 8 |
| ProRes RAW | VideoToolbox | HDR RAW |
| VP9 | VideoToolbox (macOS 12+) | HDR10 |
| AV1 | VideoToolbox (macOS 14+ M3+) | HDR10 |
| Dolby Vision | AVPlayer RPU 直通 | Profile 5/7/8 |

容器：MP4 / MOV

## 快捷键

| 按键 | 上下文 | 行为 |
|------|--------|------|
| ↑↓ | 首页 | 列内移动焦点 |
| Tab | 首页 | 列间跳转 |
| 空格 | 首页 | 选中/取消文件；有已选进入对比 |
| Cmd+A | 首页 | 全选当前列 |
| 鼠标滚轮 | 对比 | 全局缩放 |
| Cmd+滚轮 | 对比 | 单图缩放 |
| 鼠标拖拽 | 对比 | 缩放后平移 |
| 空格 | 图片对比 | 下一组 |
| 空格 | 视频对比 | 同步播放/暂停 |
| Cmd+空格 | 视频对比 | 下一组 |
| B | 对比 | 上一组 |
| H | 对比 | 直方图显隐切换 |
| ← | 视频对比 | 同步快退 5 秒 |
| → | 视频对比 | 同步快进 5 秒 |
| Q | 视频对比 | 音频指纹帧对齐 |
| 数字 1-9 | 图片对比 | 图层显隐切换 |
| Esc | 对比 | 退出对比，返回首页 |

## 性能约束

| 约束项 | 上限 | 说明 |
|--------|------|------|
| 对比组大小 | 20 张 | 超出无意义且内存风险 |
| 单图最大分辨率 | 无硬限 | CATiledLayer 分块，首屏降采样 |
| 视频最大分辨率 | 8K | VideoToolbox 硬件上限 |
| 直方图更新率 | 500ms | 视频播放采样间隔 |
| 缩略图 L1 缓存 | 200 张 | NSCache 自动淘汰 |
| 缩略图 L2 缓存 | 500MB | LRU 磁盘淘汰 |
| 选中文件上限 | 1000 个 | 超出提示"选中文件过多" |

## 构建

```bash
cd MirrorImage
swift build
```

运行：

```bash
swift run
```

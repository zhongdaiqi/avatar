# 头像装修 · Flutter 版

由微信原生小程序 `E:\minipro\avatar` 1:1 移植到 Flutter 的版本。
干净白底 + 珊瑚红强调色，全部素材（边框/纹样/贴纸/形状/背景）仍坚持**代码绘制、零位图**。

## 运行

```powershell
flutter pub get
flutter run -d chrome      # Web 调试
flutter build web --release  # 产物在 build/web
```

> 本机使用的是 OpenHarmony 版 Flutter（`F:\flutter_ohos\flutter_flutter`，3.41.9+ohos），
> `flutter test` 在该分支上无法启动 flutter_tester（WebSocket 握手失败，属分支已知问题），
> 用 `flutter analyze`（当前 0 error）+ 浏览器实测代替。

## 目录结构（与小程序一一对应）

| 小程序 | Flutter | 说明 |
| --- | --- | --- |
| `data/presets.js` | `lib/data/presets.dart` | 60 套内置模板（PresetSpec.build） |
| `data/palettes.js` | `lib/data/palettes.dart` | 23 套配色 |
| `data/recipe.js` | `lib/data/models.dart` | Recipe 数据模型 + JSON 往返 |
| `core/renderer.js` | `lib/core/renderer.dart` | 主渲染入口 + renderSwatch |
| `core/draw/shapes.js` | `lib/draw/shapes.dart` | 9 种形状（含 evenodd 遮罩路径） |
| `core/draw/frames.js` | `lib/draw/frames.dart` | 26 种边框 |
| `core/draw/patterns.js` | `lib/draw/patterns.dart` | 12 种纹样（mulberry32 确定性随机） |
| `core/draw/stickers.js` | `lib/draw/stickers.dart` | 24 个矢量贴纸 + 表情 |
| `core/draw/texts.js` | `lib/draw/texts.dart` | 文字（含弧形、对比度兜底） |
| `core/draw/filters.js` | `lib/draw/filters.dart` | 逐像素调色改为 4×5 颜色矩阵 |
| `core/draw/backdrops.js` | `lib/draw/backdrops.dart` | 6 种背景 |
| `core/draw/placeholder.js` | `lib/draw/placeholder.dart` | 占位剪影 |
| `core/photo.js` | `lib/core/photo_math.dart` | 照片 cover 度量与钳制 |
| `core/gestures.js` | `editor_page.dart` 的 Scale 手势 | 单指拖 / 双指缩放旋转 |
| `core/hit.js` | `lib/core/hit.dart` | 贴纸/文字命中检测 |
| `core/history.js` | `lib/core/history.dart` | 整份配方快照的撤销/重做 |
| `utils/storage.js` | `lib/store/local_store.dart` | 作品(30 上限)/草稿(7 天)/提示标记 |
| `core/remote.js` | `lib/core/remote.dart` | 在线模板通道（唯一对外请求，只下载） |
| `core/remoteimg.js` | `lib/core/remote.dart` fetchBytes | 遮罩图下载（http/https 双候选 + 内存缓存） |
| `pages/index` | `lib/pages/home_page.dart` | 模板首页 |
| `pages/editor` | `lib/pages/editor_page.dart` | 编辑器（6 面板；遮罩模板收敛为 3 面板） |
| `pages/works` | `lib/pages/works_page.dart` | 作品列表 |
| `pages/about` | `lib/pages/about_page.dart` | 关于 |

## 平台差异（移植时的取舍）

- **逐像素调色 → ColorFilter.matrix**：滤镜的亮度/对比/饱和/色相/冷暖改为 4×5
  颜色矩阵合成，顺序与 JS 版一致（hue → saturate → temperature → BC），结果等价。
- **文字对比度采样**：JS 版会读落点像素算亮度，Flutter 的 Canvas 读不了像素，
  改为用模板底色估（照片在场时取底色与中灰的中间值），阈值不变（2.4 翻色 / 2.6 补光晕）。
- **遮罩图透明区自检**：小程序用离屏 canvas 读像素，Flutter 直接
  `ui.Image.toByteData(rawRgba)` 抽样 ~160×160 判 alpha<16 占比（<1% 提示"没挖空"）。
- **选图/保存**：Web 用文件选择框 + `a[download]` 下载 PNG（1080×1080）；
  移动端在 `lib/platform/host_stub.dart` 留了占位，接 image_picker /
  gallery_saver 即可补齐。
- **分享**：小程序因内容安全审核关闭的 `SHARE_IMAGE`，本版本同样不提供对外分享。

## 在线模板通道

- `POST {REMOTE_BASE}/api/public/avatar/template/list`（appId=com.zuime.avatar，
  20/页最多 5 页），6h localStorage 缓存先合并秒开、过期后台刷新；
  任何失败静默回退内置 60 套。拉到的模板插一个「在线」分类紧跟推荐，
  且在线模板在所有列表里排前面。
- 模板两种形态都支持：完整 recipe JSON（normalize 后直接用）与紧凑配置
  （mk 入参）；`templateType=mask` 走遮罩图链路（照片铺满 → 遮罩图 → overlay
  → 贴纸 → 文字），首页卡片直接用后台封面图。
- `REMOTE_BASE` 可用 `--dart-define=REMOTE_BASE=...` 覆盖（本地联调代理）。
- ⚠️ **Web 端依赖服务端 CORS**：截至 2026-11-13，avatar.zuime.com 的 CORS 配置
  有问题——OPTIONS 预检不带 `Access-Control-Allow-Origin`，POST 响应又带了
  两个 ACAO（nginx 与 Spring 各加一个），浏览器 fetch 会失败并回退内置模板。
  Android / 鸿蒙走原生 HTTP 不受影响。修法：nginx 和 Spring 只留一处 CORS 配置，
  且 OPTIONS 也要回 ACAO。

## 数据与隐私

照片只在浏览器内存里处理，导出走浏览器下载；作品（配方 + 360px 缩略图）、
草稿（7 天过期）、提示标记全部存 localStorage，不上传任何服务器。

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/history.dart';
import '../core/hit.dart';
import '../core/photo_math.dart';
import '../core/px.dart';
import '../core/remote.dart';
import '../core/renderer.dart';
import '../data/models.dart';
import '../data/palettes.dart';
import '../draw/filters.dart';
import '../draw/frames.dart';
import '../draw/patterns.dart';
import '../draw/shapes.dart';
import '../draw/stickers.dart';
import '../platform/host.dart';
import '../store/local_store.dart';
import '../widgets/recipe_view.dart';

const List<String> _colors = [
  '#FFFFFF', '#1A1A1A', '#FF6B6B', '#FF9F45', '#F5D76E', '#8FD6A0',
  '#4FC3F7', '#7A8CFF', '#B388FF', '#FF8FBF', '#E24B4A', '#C98B4B',
  '#9A7A52', '#B4B2A9', '#6B6B70', '#00F0FF', '#FF2D95', '#F0C860',
  '#7FE3FF', '#D2C2F7',
];

const List<(String, String)> _tabs = [
  ('frame', '装饰'),
  ('sticker', '贴纸'),
  ('text', '文字'),
  ('shape', '形状'),
  ('bg', '背景'),
  ('filter', '滤镜'),
];

/// 遮罩图模板下还留着有意义的面板：装饰全在那张图上，
/// 边框/纹样/形状/背景对它无意义，留着只会让用户点了看不到变化。
const Set<String> _maskTabs = {'sticker', 'text', 'filter'};

class EditorPage extends StatefulWidget {
  const EditorPage({super.key, required this.initial, this.workId = ''});

  final Recipe initial;
  final String workId;

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late Recipe rec;
  late History hist;
  late String workId;

  ui.Image? photo;
  final int phIdx = math.Random().nextInt(6);

  /// 遮罩图模板（设计师出图）：照片铺满 → 遮罩图 → overlay → 贴纸 → 文字
  bool isMask = false;
  ui.Image? maskImg;
  ui.Image? overlayImg;

  /// 遮罩图没拉下来 / 整张没挖空，都要当面说出来，不能静默出一张光板照片
  bool maskFail = false;
  bool maskBlank = false;
  bool _maskLoading = false;
  bool _maskChecked = false;

  String tab = 'frame';
  String maskMode = 'square';
  bool guides = true;
  bool comparing = false;
  bool busy = false;
  int selSticker = -1;
  String colorTarget = 'frame';
  int archivedIndex = -1;

  double box = 320;

  // 手势基准
  Offset _startFocal = Offset.zero;
  double _baseScale = 1;
  double _baseRotate = 0;
  double _baseX = 0;
  double _baseY = 0;
  HitResult? _drag;
  double _dragScale = 1;
  double _dragRotate = 0;
  Offset _dragPos = Offset.zero;

  @override
  void initState() {
    super.initState();
    rec = widget.initial;
    workId = widget.workId;
    isMask = rec.isMask;
    // 遮罩模板只有贴纸/文字/滤镜可用，默认直接停在贴纸页，
    // 否则第一屏就是一堆点了没反应的装饰选项
    if (isMask) tab = 'sticker';
    hist = History(30)..reset(rec);
    _restorePhoto();
    if (isMask) _loadMaskImages();
  }

  /* ------------------------------ 遮罩图模板 ------------------------------ */

  Future<void> _loadMaskImages({bool retry = false}) async {
    final m = rec.mask;
    if (m == null || m.url.isEmpty || _maskLoading) return;
    _maskLoading = true;
    try {
      final maskBytes =
          await RemoteTemplates.fetchBytes(m.url, retry: retry);
      if (maskBytes != null) {
        final img = await _decode(maskBytes);
        if (img != null) {
          maskImg = img;
          _maskChecked = false;
          _checkMaskAlpha(img);
        }
      }
      if (m.overlay.isNotEmpty) {
        final ob = await RemoteTemplates.fetchBytes(m.overlay, retry: retry);
        if (ob != null) overlayImg = await _decode(ob);
      }
    } finally {
      _maskLoading = false;
    }
    if (!mounted) return;
    setState(() => maskFail = maskImg == null);
  }

  /// 页头那条「模板图没加载出来」的重试
  void _retryMask() {
    setState(() {
      maskImg = null;
      overlayImg = null;
      maskFail = false;
      maskBlank = false;
      _maskChecked = false;
    });
    _loadMaskImages(retry: true);
  }

  /// 遮罩图有没有"挖空"。
  /// 没有透明区的话照片会被整块盖死（换了照片也看不见），进页面就捅一下，
  /// 早说早改素材。读不到像素就算了，这只是提示，不影响出图。
  Future<void> _checkMaskAlpha(ui.Image img) async {
    if (_maskChecked) return;
    _maskChecked = true;
    try {
      final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) return;
      final bytes = data.buffer.asUint8List();
      final pixels = img.width * img.height;
      if (pixels == 0) return;
      // 1080×1080 不必逐像素，均匀抽样 ~160×160 就够判断
      final step = math.max(1, (pixels / 25600).ceil());
      var trans = 0;
      var total = 0;
      for (var i = 0; i < pixels; i += step) {
        if (bytes[i * 4 + 3] < 16) trans++;
        total++;
      }
      if (total > 0 && trans / total < 0.01 && mounted) {
        setState(() => maskBlank = true);
      }
    } catch (_) {}
  }

  Future<ui.Image?> _decode(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  Future<void> _restorePhoto() async {
    if (rec.photo.src.isEmpty) return;
    final bytes = decodeDataUrl(rec.photo.src);
    if (bytes == null) return;
    final img = await _decode(bytes);
    if (img == null || !mounted) return;
    setState(() => photo = img);
  }

  void _commit() {
    hist.commit(rec);
    setState(() {});
  }

  void _touch() => setState(() {});

  /* ------------------------------- 选图 ------------------------------- */

  Future<void> _pickPhoto() async {
    final bytes = await pickImageBytes();
    if (bytes == null) {
      if (isWebHost && mounted) _toast('没有选中图片');
      return;
    }
    final img = await _decode(bytes);
    if (img == null) {
      if (mounted) _toast('这张图读不出来，换一张试试');
      return;
    }
    setState(() {
      photo = img;
      rec.photo.src = bytes.length <= 900000 ? dataUrl(bytes) : '';
      rec.photo
        ..scale = 1.14
        ..x = 0
        ..y = 0
        ..rotate = 0;
    });
    _commit();
  }

  void _removePhoto() {
    setState(() {
      photo = null;
      rec.photo.src = '';
    });
    _commit();
  }

  /* ------------------------------- 手势 ------------------------------- */

  void _onScaleStart(ScaleStartDetails d) {
    if (d.pointerCount <= 1) {
      final hit = hitTest(rec, box, d.localFocalPoint);
      if (hit != null) {
        _drag = hit;
        if (hit.type == 'text') {
          _dragPos = Offset(rec.texts[hit.index].x, rec.texts[hit.index].y);
          _dragScale = 1;
          _dragRotate = 0;
          setState(() => colorTarget = 'text');
        } else {
          final st = rec.stickers[hit.index];
          _dragPos = Offset(st.x, st.y);
          _dragScale = st.scale;
          _dragRotate = st.rotate;
          setState(() => selSticker = hit.index);
        }
        _startFocal = d.localFocalPoint;
        return;
      }
    }
    _drag = null;
    _startFocal = d.localFocalPoint;
    _baseScale = rec.photo.scale;
    _baseRotate = rec.photo.rotate;
    _baseX = rec.photo.x;
    _baseY = rec.photo.y;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final dx = d.localFocalPoint.dx - _startFocal.dx;
    final dy = d.localFocalPoint.dy - _startFocal.dy;

    if (_drag != null) {
      final hit = _drag!;
      if (hit.type == 'text') {
        final t = rec.texts[hit.index];
        t.x = clampd(_dragPos.dx + dx / box, 0.02, 0.98);
        t.y = clampd(_dragPos.dy + dy / box, 0.02, 0.98);
      } else {
        final st = rec.stickers[hit.index];
        st.x = clampd(_dragPos.dx + dx / box, 0.02, 0.98);
        st.y = clampd(_dragPos.dy + dy / box, 0.02, 0.98);
        if (d.pointerCount > 1) {
          st.scale = clampd(_dragScale * d.scale, 0.3, 2.4);
          st.rotate = clampd(
              _dragRotate + d.rotation * 180 / math.pi, -180, 180);
        }
      }
      _touch();
      return;
    }

    if (photo == null) return;
    rec.photo.x = _baseX + dx / box;
    rec.photo.y = _baseY + dy / box;
    if (d.pointerCount > 1) {
      rec.photo.scale = clampd(_baseScale * d.scale, 1, 4);
      rec.photo.rotate = clampd(
          _baseRotate + d.rotation * 180 / math.pi, -180, 180);
    }
    clampPhotoOffset(
        rec.photo, photoMetrics(rec.photo, photo!.width.toDouble(), photo!.height.toDouble()));
    _touch();
  }

  void _onScaleEnd(ScaleEndDetails d) {
    _drag = null;
    _commit();
  }

  /* ------------------------------- 渲染导出 ------------------------------- */

  Future<ui.Image> _renderImage(int size) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    renderRecipe(
      canvas,
      size.toDouble(),
      rec,
      RenderOpts(
        photo: photo,
        placeholder: phIdx,
        mask: 'none',
        maskImg: maskImg,
        overlayImg: overlayImg,
      ),
    );
    final pic = recorder.endRecording();
    final image = await pic.toImage(size, size);
    pic.dispose();
    return image;
  }

  Future<Uint8List?> _png(ui.Image img) async {
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  Future<void> _saveImage() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final img = await _renderImage(1080);
      final bytes = await _png(img);
      img.dispose();
      if (bytes == null) throw StateError('encode failed');
      final msg = await saveImage(
          bytes, 'avatar-${DateTime.now().millisecondsSinceEpoch}.png');
      if (!mounted) return;
      setState(() => busy = false);
      _showSaved(bytes, msg);
    } catch (_) {
      if (!mounted) return;
      setState(() => busy = false);
      _toast('生成图片失败，请重试');
    }
  }

  Future<void> _saveToWorks() async {
    final img = await _renderImage(360);
    final thumb = await _png(img);
    img.dispose();
    if (thumb == null) {
      _toast('保存失败');
      return;
    }
    final id = workId.isEmpty ? LocalStore.uid() : workId;
    final name = rec.texts.isNotEmpty && rec.texts.first.text.trim().isNotEmpty
        ? rec.texts.first.text.trim()
        : rec.name;
    final evicted = LocalStore.saveWork(Work(
      id: id,
      name: name.length > 12 ? name.substring(0, 12) : name,
      thumb: dataUrl(thumb),
      recipe: rec.clone(),
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));
    workId = id;
    archivedIndex = hist.index;
    LocalStore.clearDraft();
    if (!mounted) return;
    _toast(evicted != null ? '已存 $maxWorks 个，最早的已移除' : '已存到作品');
  }

  void _showSaved(Uint8List png, String msg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('已生成 1080×1080',
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(png, width: 180, height: 180),
            ),
            const SizedBox(height: 12),
            Text(msg,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.grey)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _saveToWorks();
                    },
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.coral),
                    child: const Text('存到作品'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('继续装修'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 1600),
    ));
  }

  /* ------------------------------- 保存草稿 ------------------------------- */

  Future<bool> _onWillPop() async {
    if (hist.canUndo && archivedIndex != hist.index) {
      LocalStore.setDraft(rec, workId: workId);
    }
    return true;
  }

  /* ------------------------------- UI ------------------------------- */

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _onWillPop();
        if (mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              _navBar(),
              _stageArea(),
              _maskBanner(),
              _maskPills(),
              _tabBar(),
              Expanded(child: SingleChildScrollView(child: _panel())),
              _actionBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navBar() {
    return SizedBox(
      height: 46,
      child: Row(
        children: [
          IconButton(
            onPressed: () async {
              await _onWillPop();
              if (mounted) Navigator.of(context).pop();
            },
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          ),
          const Spacer(),
          IconButton(
            onPressed: hist.canUndo
                ? () {
                    final s = hist.undo();
                    if (s != null) setState(() => rec = s);
                  }
                : null,
            icon: const Icon(Icons.undo_rounded, size: 20),
          ),
          IconButton(
            onPressed: hist.canRedo
                ? () {
                    final s = hist.redo();
                    if (s != null) setState(() => rec = s);
                  }
                : null,
            icon: const Icon(Icons.redo_rounded, size: 20),
          ),
          IconButton(
            onPressed: _resetAll,
            icon: const Icon(Icons.restart_alt_rounded, size: 20),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Future<void> _resetAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重置装修'),
        content: const Text('会清掉所有装饰，只保留照片。确定吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                TextButton.styleFrom(foregroundColor: AppColors.coral),
            child: const Text('重置'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final src = rec.photo.src;
    final fresh = blankRecipe('pure');
    fresh.photo.src = src;
    setState(() {
      rec = fresh;
      // 重置也要把遮罩模板还原成普通配方模式，
      // 否则面板永远只剩三个、照片还是铺在一张透明图底下
      isMask = false;
      maskImg = null;
      overlayImg = null;
      maskFail = false;
      maskBlank = false;
      tab = 'frame';
      selSticker = -1;
    });
    _commit();
  }

  Widget _stageArea() {
    return LayoutBuilder(builder: (context, c) {
      box = math.min(c.maxWidth - 32, 420.0);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            SizedBox(
              width: box,
              height: box,
              child: GestureDetector(
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                onScaleEnd: _onScaleEnd,
                onLongPressStart: (_) {
                  if (_drag != null || photo == null) return;
                  setState(() => comparing = true);
                },
                onLongPressEnd: (_) {
                  if (comparing) setState(() => comparing = false);
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    RepaintBoundary(
                      child: CustomPaint(
                        painter: RecipePainter(
                          recipe: comparing ? _plainRecipe() : rec,
                          photo: photo,
                          placeholder: phIdx,
                          mask: comparing ? 'none' : maskMode,
                          guides: guides && !comparing,
                          maskImg: comparing ? null : maskImg,
                          overlayImg: comparing ? null : overlayImg,
                        ),
                      ),
                    ),
                    if (!comparing)
                      IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.line),
                          ),
                        ),
                      ),
                    if (comparing)
                      Positioned(
                        left: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xB3000000),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: const Text('原图',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 11)),
                        ),
                      ),
                    if (photo == null)
                      Center(
                        child: GestureDetector(
                          onTap: _pickPhoto,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(99),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 12,
                                )
                              ],
                            ),
                            child: const Text('＋ 选一张照片',
                                style: TextStyle(
                                    fontSize: 13.5,
                                    color: AppColors.ink,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      );
    });
  }

  /// 遮罩图两种异常都要明说（提示条，不是一个转瞬即逝的 toast）：
  /// 拉不到 → 可点重试；没挖空 → 告诉用户照片会被盖住。
  Widget _maskBanner() {
    if (!isMask || (!maskFail && !maskBlank)) return const SizedBox.shrink();
    final fail = maskFail;
    final text = fail
        ? '模板图没加载出来 · 点这里重试'
        : '这张模板图没有透明区，照片会被整块盖住，请联系管理员换图';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: GestureDetector(
        onTap: fail ? _retryMask : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: fail ? const Color(0xFFFFF4E8) : const Color(0xFFFFF0EF),
            border: Border.all(
                color: fail ? const Color(0xFFFFDCB4) : const Color(0xFFFFCFCC)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                fail ? Icons.refresh_rounded : Icons.info_outline_rounded,
                size: 15,
                color: fail ? const Color(0xFFB26A17) : AppColors.coral,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: fail ? const Color(0xFF9A5C12) : const Color(0xFFB03A38),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Recipe _plainRecipe() {
    final r = rec.clone()
      ..frame = FrameCfg(id: '')
      ..pattern = PatternCfg(id: '')
      ..stickers = <StickerCfg>[]
      ..texts = <TextCfg>[]
      ..mask = null;
    return r;
  }

  Widget _maskPills() {
    Widget pill(String label, bool on, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
            decoration: BoxDecoration(
              color: on ? const Color(0xFFFFF0EF) : AppColors.soft,
              border: Border.all(
                  color: on ? const Color(0xFFFFCDCB) : Colors.transparent),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: on ? AppColors.coral : const Color(0xFF6B6B70))),
          ),
        );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          pill('整图', maskMode == 'square',
              () => setState(() => maskMode = 'square')),
          pill('微信圆', maskMode == 'circle',
              () => setState(() => maskMode = 'circle')),
          pill('圆角', maskMode == 'rounded',
              () => setState(() => maskMode = 'rounded')),
          pill('安全区', guides, () => setState(() => guides = !guides)),
        ],
      ),
    );
  }

  List<(String, String)> get _visibleTabs =>
      isMask ? _tabs.where((t) => _maskTabs.contains(t.$1)).toList() : _tabs;

  Widget _tabBar() {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _visibleTabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final (id, name) = _visibleTabs[i];
          final on = tab == id;
          return GestureDetector(
            onTap: () => setState(() => tab = id),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: on ? AppColors.coral : AppColors.soft,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(name,
                  style: TextStyle(
                      fontSize: 13,
                      color: on ? Colors.white : const Color(0xFF6B6B70))),
            ),
          );
        },
      ),
    );
  }

  Widget _actionBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: busy ? null : _saveImage,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.coral,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.download_rounded, size: 19),
                label: Text(busy ? '正在生成…' : '保存图片',
                    style: const TextStyle(fontSize: 15)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text('1080×1080',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  /* ------------------------------- 面板 ------------------------------- */

  Widget _panel() {
    switch (tab) {
      case 'sticker':
        return _stickerPanel();
      case 'text':
        return _textPanel();
      case 'shape':
        return _shapePanel();
      case 'bg':
        return _bgPanel();
      case 'filter':
        return _filterPanel();
      case 'frame':
      default:
        return _framePanel();
    }
  }

  Widget _quickRow() {
    Widget btn(String label, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.soft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(label,
                style: const TextStyle(fontSize: 12.5, color: AppColors.ink)),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          btn('换一张照片', _pickPhoto),
          const SizedBox(width: 8),
          if (photo != null) btn('去掉照片', _removePhoto),
          const Spacer(),
          const Text('双指缩放 · 长按看原图',
              style: TextStyle(fontSize: 11, color: Color(0xFFB4B4BA))),
        ],
      ),
    );
  }

  Widget _pHead(String title, [String? hint]) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w600)),
          if (hint != null) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFFAAAAb0))),
            ),
          ],
        ],
      ),
    );
  }

  Widget _swatchGrid({
    required List<(String, String)> items,
    required String selected,
    required String kind,
    required Color color,
    required void Function(String id) onTap,
    Color bg = const Color(0xFF3A3A44),
    int columns = 5,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.82,
        ),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final (id, name) = items[i];
          final on = id == selected;
          return GestureDetector(
            onTap: () => onTap(id),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAFB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: on ? AppColors.coral : const Color(0xFFEFEFF2),
                        width: on ? 1.6 : 1,
                      ),
                    ),
                    child: id.isEmpty
                        ? const Center(
                            child: Text('无',
                                style: TextStyle(
                                    fontSize: 12, color: Color(0xFFB4B4BA))))
                        : Padding(
                            padding: const EdgeInsets.all(4),
                            child: RepaintBoundary(
                              child: CustomPaint(
                                painter: SwatchPainter(
                                    kind: kind, id: id, color: color, bg: bg),
                                size: Size.infinite,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFF8A8A8E))),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sliderRow(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
    VoidCallback onEnd, {
    String? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B6B70))),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                activeTrackColor: AppColors.coral,
                inactiveTrackColor: const Color(0xFFE6E6E9),
                thumbColor: Colors.white,
                overlayShape: SliderComponentShape.noOverlay,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 9),
                trackShape: const RoundedRectSliderTrackShape(),
              ),
              child: Slider(
                value: value.clamp(min, max).toDouble(),
                min: min,
                max: max,
                onChanged: (v) {
                  onChanged(v);
                },
                onChangeEnd: (_) => onEnd(),
              ),
            ),
          ),
          SizedBox(
            width: 42,
            child: Text(suffix ?? value.round().toString(),
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF9A9AA0))),
          ),
        ],
      ),
    );
  }

  Widget _colorRow(void Function(String hex) onPick, String hintTarget) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final hex in _colors)
            GestureDetector(
              onTap: () {
                onPick(hex);
                _commit();
              },
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: hexColor(hex),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x14000000)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /* ---------- 装饰 ---------- */

  Widget _framePanel() {
    final pal = paletteById(rec.paletteId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _quickRow(),
        _pHead('边框', '贴着形状内侧画，不会被圆形裁掉'),
        _swatchGrid(
          items: [for (final d in frameList) (d.id, d.name)],
          selected: rec.frame.id,
          kind: 'frame',
          color: pal.accent,
          onTap: (id) {
            setState(() {
              rec.frame.id = id;
              colorTarget = 'frame';
            });
            if (id.isNotEmpty && rec.frame.color.a == 1) {
              rec.frame.color = pal.frame;
            }
            _commit();
          },
        ),
        _pHead('纹样', '画在照片之上，靠近边缘'),
        _swatchGrid(
          items: [for (final d in patternList) (d.id, d.name)],
          selected: rec.pattern.id,
          kind: 'pattern',
          color: const Color(0xFFFFFFFF),
          bg: const Color(0xFF3A3A44),
          onTap: (id) {
            setState(() {
              rec.pattern.id = id;
              colorTarget = 'pattern';
            });
            _commit();
          },
        ),
        const SizedBox(height: 6),
        _sliderRow('粗细', rec.frame.width, 2, 30, (v) {
          setState(() => rec.frame.width = v);
        }, _commit),
        _sliderRow('间距', rec.frame.gap, 0, 30, (v) {
          setState(() => rec.frame.gap = v);
        }, _commit),
        _sliderRow('不透明', rec.frame.alpha * 100, 10, 100, (v) {
          setState(() => rec.frame.alpha = v / 100);
        }, _commit),
        _sliderRow('密度', rec.pattern.density * 100, 0, 100, (v) {
          setState(() => rec.pattern.density = v / 100);
        }, _commit),
        _sliderRow('纹样透明', rec.pattern.alpha * 100, 5, 100, (v) {
          setState(() => rec.pattern.alpha = v / 100);
        }, _commit),
        _pHead('颜色'),
        _colorRow((hex) {
          final c = hexColor(hex);
          setState(() {
            if (colorTarget == 'pattern') {
              rec.pattern.color = c;
            } else {
              rec.frame.color = c;
            }
          });
        }, 'frame'),
        const SizedBox(height: 16),
      ],
    );
  }

  /* ---------- 贴纸 ---------- */

  Widget _stickerPanel() {
    final pal = paletteById(rec.paletteId);
    final sel = selSticker >= 0 && selSticker < rec.stickers.length
        ? rec.stickers[selSticker]
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _quickRow(),
        _pHead('图形贴纸', '代码绘制，颜色可调'),
        _swatchGrid(
          items: [for (final d in stickerList) (d.id, d.name)],
          selected: '',
          kind: 'sticker',
          color: const Color(0xFFFF6B6B),
          onTap: (id) => _addSticker(id, 'vector', pal.accent),
        ),
        _pHead('表情贴纸', '不同系统显示略有差异'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in emojiList)
                GestureDetector(
                  onTap: () => _addSticker(e, 'emoji', const Color(0xFFFFFFFF)),
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAFB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFEFEFF2)),
                    ),
                    child: Text(e, style: const TextStyle(fontSize: 20)),
                  ),
                ),
            ],
          ),
        ),
        if (sel != null) ...[
          const SizedBox(height: 6),
          const Divider(height: 24, color: AppColors.line),
          _pHead('调整贴纸'),
          _sliderRow('大小', sel.scale * 100, 30, 240, (v) {
            setState(() => sel.scale = v / 100);
          }, _commit),
          _sliderRow('横向', sel.x * 100, 0, 100, (v) {
            setState(() => sel.x = v / 100);
          }, _commit),
          _sliderRow('纵向', sel.y * 100, 0, 100, (v) {
            setState(() => sel.y = v / 100);
          }, _commit),
          _sliderRow('旋转', sel.rotate, -180, 180, (v) {
            setState(() => sel.rotate = v);
          }, _commit),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text('画布上直接拖动贴纸；双指可缩放、旋转',
                style: TextStyle(fontSize: 11, color: Color(0xFFAAAAb0))),
          ),
          _pHead('颜色'),
          _colorRow((hex) {
            setState(() => sel.color = hexColor(hex));
          }, 'sticker'),
          Center(
            child: TextButton(
              onPressed: () {
                setState(() {
                  rec.stickers.removeAt(selSticker);
                  selSticker = -1;
                });
                _commit();
              },
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFE24B4A)),
              child: const Text('删除这个贴纸', style: TextStyle(fontSize: 12.5)),
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  void _addSticker(String id, String kind, Color color) {
    if (rec.stickers.length >= 6) {
      _toast('贴纸最多 6 个');
      return;
    }
    setState(() {
      rec.stickers.add(StickerCfg(
        id: id,
        kind: kind,
        x: 0.5,
        y: 0.3,
        scale: 1,
        rotate: 0,
        alpha: 1,
        color: color,
      ));
      selSticker = rec.stickers.length - 1;
      colorTarget = 'sticker';
      tab = 'sticker';
    });
    _commit();
  }

  /* ---------- 文字 ---------- */

  Widget _textPanel() {
    final t = rec.texts.isNotEmpty ? rec.texts.first : null;
    final hasValue = t != null && t.text.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _quickRow(),
        _pHead('文字', '微信里显示为圆形，别贴到边'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GestureDetector(
            onTap: _editText,
            child: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: AppColors.soft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                hasValue ? t.text : '添加一行字，比如「上岸」',
                style: TextStyle(
                  fontSize: 13.5,
                  color: hasValue ? AppColors.ink : const Color(0xFFB4B4BA),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _sliderRow('字号', t?.size ?? 46, 20, 110, (v) {
          setState(() => _ensureText().size = v);
        }, _commit),
        _sliderRow('弧度', t?.arc ?? 0, -100, 100, (v) {
          setState(() => _ensureText().arc = v);
        }, _commit),
        _sliderRow('高度', (t?.y ?? 0.85) * 100, 10, 95, (v) {
          setState(() => _ensureText().y = v / 100);
        }, _commit),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Row(
            children: [
              _chip('加粗', (t?.weight ?? 'bold') == 'bold', () {
                setState(() {
                  final tt = _ensureText();
                  tt.weight = tt.weight == 'bold' ? 'normal' : 'bold';
                });
                _commit();
              }),
              const SizedBox(width: 8),
              _chip('描边', (t?.strokeWidth ?? 0) > 0, () {
                setState(() {
                  final tt = _ensureText();
                  tt.strokeWidth = tt.strokeWidth > 0 ? 0 : 4;
                });
                _commit();
              }),
              const SizedBox(width: 8),
              _chip('清空文字', false, () {
                setState(() => rec.texts = <TextCfg>[]);
                _commit();
              }),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Text('文字可以直接在画布上拖动位置',
              style: TextStyle(fontSize: 11, color: Color(0xFFAAAAb0))),
        ),
        _pHead('颜色'),
        _colorRow((hex) {
          setState(() => _ensureText().color = hexColor(hex));
        }, 'text'),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _chip(String label, bool on, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: on ? const Color(0xFFFFF0EF) : AppColors.soft,
          border: Border.all(
              color: on ? const Color(0xFFFFCDCB) : Colors.transparent),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12.5,
                color: on ? AppColors.coral : const Color(0xFF6B6B70))),
      ),
    );
  }

  TextCfg _ensureText() {
    if (rec.texts.isEmpty) {
      rec.texts = [newTextCfg(rec)];
    }
    return rec.texts.first;
  }

  Future<void> _editText() async {
    final cur = rec.texts.isNotEmpty ? rec.texts.first.text : '';
    final controller = TextEditingController(text: cur);
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('输入文字'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 24,
          decoration: const InputDecoration(hintText: '最多 12 个字最好看'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            style: TextButton.styleFrom(foregroundColor: AppColors.coral),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (value == null) return;
    setState(() {
      final t = _ensureText();
      t.text = value.trim();
      colorTarget = 'text';
    });
    _commit();
  }

  /* ---------- 形状 ---------- */

  Widget _shapePanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _quickRow(),
        _pHead('头像形状'),
        _swatchGrid(
          items: [for (final d in shapeList) (d.id, d.name)],
          selected: rec.shape.type,
          kind: 'shape',
          color: const Color(0xFFFF8F8F),
          onTap: (id) {
            setState(() => rec.shape.type = id);
            _commit();
          },
        ),
        const SizedBox(height: 6),
        _sliderRow('内缩', rec.shape.inset * 100, 0, 20, (v) {
          setState(() => rec.shape.inset = v / 100);
        }, _commit, suffix: '${(rec.shape.inset * 100).round()}%'),
        if (rec.shape.type == 'rounded')
          _sliderRow('圆角', (rec.shape.params['radius'] ?? 0.22) * 100, 0, 50,
              (v) {
            setState(() => rec.shape.params['radius'] = v / 100);
          }, _commit, suffix:
              '${((rec.shape.params['radius'] ?? 0.22) * 100).round()}%'),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Text(
            '方形是默认形态，照片满版铺满。微信里头像按圆形显示，用方形做头像四角会被裁掉，'
            '建议点上面「微信圆」先看一眼。',
            style: TextStyle(fontSize: 11.5, height: 1.6, color: Color(0xFF8A8A8E)),
          ),
        ),
      ],
    );
  }

  /* ---------- 背景 ---------- */

  Widget _bgPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _quickRow(),
        _pHead('配色', '一次换掉背景、边框、文字三处颜色'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final p in paletteList)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      rec.paletteId = p.id;
                      rec.backdrop.stops = [(p.bg1, 0), (p.bg2, 1)];
                      rec.frame.color = p.frame;
                      rec.pattern.color = p.frame;
                      if (rec.texts.isNotEmpty) rec.texts.first.color = p.text;
                    });
                    _commit();
                  },
                  child: SizedBox(
                    width: 64,
                    child: Column(
                      children: [
                        Container(
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [p.bg1, p.bg2]),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                                color: rec.paletteId == p.id
                                    ? AppColors.coral
                                    : const Color(0x11000000),
                                width: rec.paletteId == p.id ? 2 : 1),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(p.name,
                            style: const TextStyle(
                                fontSize: 10.5, color: Color(0xFF8A8A8E))),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        _pHead('背景样式'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (id, name) in const [
                ('solid', '纯色'),
                ('linear', '渐变'),
                ('radial', '径向'),
                ('stripes', '条纹'),
                ('checker', '棋盘'),
                ('split', '斜切'),
              ])
                _chip(name, rec.backdrop.type == id, () {
                  setState(() {
                    rec.backdrop.type = id;
                    if (id == 'solid') {
                      final c = rec.backdrop.stops.first.$1;
                      rec.backdrop.stops = [(c, 0), (c, 1)];
                    }
                  });
                  _commit();
                }),
            ],
          ),
        ),
        _pHead('自定义底色'),
        _colorRow((hex) {
          final c = hexColor(hex);
          setState(() {
            rec.backdrop.type = 'linear';
            rec.backdrop.stops = [(c, 0), (lighten(c, 0.36), 1)];
          });
        }, 'bg'),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Text(
            '微信里圆形头像几乎看不到背景，背景主要在方形/圆角场景用得上。',
            style: TextStyle(fontSize: 11.5, height: 1.6, color: Color(0xFF8A8A8E)),
          ),
        ),
      ],
    );
  }

  /* ---------- 滤镜 ---------- */

  Widget _filterPanel() {
    final f = rec.photo.filters;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _quickRow(),
        _pHead('风格', '只对照片调色，不影响装饰'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final st in filterStyles)
                _chip(st.name, f.style == st.id, () {
                  setState(() => f.style = st.id);
                  _commit();
                }),
            ],
          ),
        ),
        _sliderRow('亮度', f.brightness * 100, 50, 180, (v) {
          setState(() => f.brightness = v / 100);
        }, _commit),
        _sliderRow('对比', f.contrast * 100, 50, 180, (v) {
          setState(() => f.contrast = v / 100);
        }, _commit),
        _sliderRow('饱和', f.saturate * 100, 0, 200, (v) {
          setState(() => f.saturate = v / 100);
        }, _commit),
        _sliderRow('暖冷', f.temperature, -100, 100, (v) {
          setState(() => f.temperature = v);
        }, _commit),
        Center(
          child: TextButton(
            onPressed: () {
              setState(() {
                rec.photo.filters = FilterCfg();
              });
              _commit();
            },
            style:
                TextButton.styleFrom(foregroundColor: const Color(0xFFE24B4A)),
            child: const Text('恢复原色', style: TextStyle(fontSize: 12.5)),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

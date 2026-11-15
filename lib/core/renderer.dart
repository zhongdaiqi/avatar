import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../data/models.dart';
import '../draw/backdrops.dart';
import '../draw/filters.dart';
import '../draw/frames.dart';
import '../draw/patterns.dart';
import '../draw/placeholder.dart';
import '../draw/shapes.dart';
import '../draw/stickers.dart';
import '../draw/texts.dart';
import 'photo_math.dart';
import 'px.dart';

class RenderOpts {
  RenderOpts({
    this.photo,
    this.placeholder = 0,
    this.mask = 'square',
    this.guides = false,
    this.maskImg,
    this.overlayImg,
  });

  final ui.Image? photo;
  final int placeholder;

  /// 预览遮罩：'square' 整图 / 'circle' 微信圆 / 'rounded' 圆角 / 'none'
  final String mask;
  final bool guides;
  final ui.Image? maskImg;
  final ui.Image? overlayImg;
}

double _shapeRadius(double L, Recipe rec) {
  final inset = rec.shape.inset;
  return (L / 2) * (1 - inset);
}

/// 文字落点底色的亮度：照片在场时按模板底色估（设计上是配套的），
/// 没照片时就是背景本身的亮度。
double _bgLumaFor(Recipe rec, bool hasPhoto) {
  final st = rec.backdrop.stops;
  if (st.isEmpty) return 1;
  final a = luma(st.first.$1);
  final b = luma(st.last.$1);
  final base = (a + b) / 2;
  if (!hasPhoto) return base;
  // 照片内容不可知，取底色与中灰的中间值，避免过度翻转文字颜色
  return (base + 0.55) / 2;
}

void _drawPhoto(
  Pc c,
  double L,
  Recipe rec,
  ui.Image img,
  double cx,
  double cy,
) {
  final m = photoMetrics(rec.photo, img.width.toDouble(), img.height.toDouble());
  final dw = img.width * m.k * L;
  final dh = img.height * m.k * L;
  c.save();
  c.translate(cx + rec.photo.x * L, cy + rec.photo.y * L);
  c.rotate(rad(rec.photo.rotate));
  final dst = Rect.fromLTWH(-dw / 2, -dh / 2, dw, dh);
  c.canvas.drawImageRect(
    img,
    Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
    dst,
    photoPaint(rec.photo.filters),
  );
  c.restore();
}

void _drawStickers(Pc c, double L, Recipe rec) {
  for (final st in rec.stickers) {
    final size = st.scale * L * 0.3;
    c.save();
    c.alpha = st.alpha;
    c.translate(st.x * L, st.y * L);
    c.rotate(rad(st.rotate));
    drawSticker(c, id: st.id, kind: st.kind, size: size, color: st.color);
    c.restore();
  }
}

void _drawTexts(Pc c, double L, Recipe rec, double bgLuma) {
  for (final t in rec.texts) {
    drawTextCfg(c, L, t, bgLuma: bgLuma);
  }
}

void _drawGuideCircle(Pc c, double L) {
  final gr = math.max(1.0, L * 0.004);
  c.save();
  final r = L / 2 - gr;
  final path = Path()
    ..addArc(
        Rect.fromCircle(center: Offset(L / 2, L / 2), radius: r), 0, math.pi * 2);
  c.strokePath(
    path,
    color: const Color(0x29000000),
    width: math.max(1, L * 0.0025),
    dash: [L * 0.014, L * 0.012],
    cap: StrokeCap.butt,
  );
  c.restore();
}

void _drawShapeMask(
    Pc c, double L, String shape, double r, Map<String, double> params) {
  final cx = L / 2;
  final cy = L / 2;
  final mt = shape == 'circle' ? 'circle' : 'rounded';
  final mp = shape == 'circle' ? <String, double>{} : <String, double>{'radius': 0.22};
  final rr = shape == 'circle' ? r : L / 2;
  final box = Rect.fromLTWH(0, 0, L, L);

  // 矩形 + 形状合成一条 evenodd 路径，填充出来就是"形状之外"的区域
  final outside = Path()
    ..fillType = PathFillType.evenOdd
    ..addRect(box);
  shapePathTo(outside, mt, cx, cy, rr, mp);
  c.fillPath(outside, color: const Color(0xFFFFFFFF));

  c.strokePath(
    shapePath(mt, cx, cy, rr, mp),
    color: const Color(0x14000000),
    width: math.max(1, L * 0.002),
    cap: StrokeCap.butt,
  );
}

/// 遮罩图模板：照片铺满 → 遮罩图 → overlay → 贴纸 → 文字
void _renderMask(Pc c, double L, Recipe rec, RenderOpts o) {
  final full = Rect.fromLTWH(0, 0, L, L);
  c.fillRect(full, color: const Color(0xFFFFFFFF));

  final photo = o.photo;
  if (photo != null) {
    _drawPhoto(c, L, rec, photo, L / 2, L / 2);
  }
  // 没照片就什么都不画，让遮罩图的透明区露出干净白底

  if (rec.photo.filters.style.isNotEmpty) {
    applyStyle(c, L, rec.photo.filters.style, rec.photo.filters.styleOpacity);
  }

  if (o.maskImg != null) c.drawImageCover(o.maskImg!, full);
  if (o.overlayImg != null) c.drawImageCover(o.overlayImg!, full);

  _drawStickers(c, L, rec);
  _drawTexts(c, L, rec, _bgLumaFor(rec, photo != null));

  if (o.guides) _drawGuideCircle(c, L);

  if (o.mask != 'none' && o.mask != 'square') {
    _drawShapeMask(
        c, L, o.mask == 'rounded' ? 'rounded' : 'circle', L / 2, const {});
  }
}

/// 主渲染入口。所有坐标由归一化数据换算，240 / 540 / 1080 结果一致。
void renderRecipe(Canvas canvas, double L, Recipe rec, RenderOpts o) {
  final pc = Pc(canvas, Rect.fromLTWH(0, 0, L, L));
  canvas.save();
  canvas.clipRect(Rect.fromLTWH(0, 0, L, L));

  // 遮罩图模板走完全独立的一条链路（不画 backdrop/边框/纹样）
  if (rec.isMask) {
    _renderMask(pc, L, rec, o);
    canvas.restore();
    return;
  }

  final cx = L / 2;
  final cy = L / 2;
  final r = _shapeRadius(L, rec);
  final shape = rec.shape.type;
  final sparams = rec.shape.params;

  drawBackdrop(pc, L, rec.backdrop);

  pc.save();
  pc.clipPath(shapePath(shape, cx, cy, r, sparams));

  final photo = o.photo;
  if (photo != null) {
    _drawPhoto(pc, L, rec, photo, cx, cy);
  } else {
    // 占位剪影要自己判断深浅：深底用白剪影，浅底用灰影子
    final st = rec.backdrop.stops;
    final bgLuma = st.isEmpty
        ? 1.0
        : (luma(st.first.$1) + luma(st.last.$1)) / 2;
    final pk = (shape == 'circle' || shape == 'square') ? 1.0 : 0.82;
    drawPlaceholder(pc, L, o.placeholder, bgLuma < 0.55, pk);
  }

  if (rec.photo.filters.style.isNotEmpty) {
    applyStyle(pc, L, rec.photo.filters.style, rec.photo.filters.styleOpacity);
  }

  if (rec.pattern.id.isNotEmpty) {
    drawPattern(
      pc,
      L,
      id: rec.pattern.id,
      color: rec.pattern.color,
      density: rec.pattern.density,
      alpha: rec.pattern.alpha,
      r: r,
    );
  }

  pc.restore();

  if (rec.frame.id.isNotEmpty) {
    // 边框永远不越出形状边界
    pc.save();
    pc.clipPath(shapePath(shape, cx, cy, r, sparams));
    drawFrame(
      pc,
      FrameState(
        id: rec.frame.id,
        shape: shape,
        cx: cx,
        cy: cy,
        r: r,
        color: rec.frame.color,
        width: rec.frame.width * (L / 540),
        gap: rec.frame.gap * (L / 540),
        alpha: rec.frame.alpha,
        params: sparams,
      ),
    );
    pc.restore();
  }

  _drawStickers(pc, L, rec);
  _drawTexts(pc, L, rec, _bgLumaFor(rec, photo != null));

  if (o.guides) _drawGuideCircle(pc, L);

  if (o.mask != 'none' && o.mask != 'square') {
    _drawShapeMask(pc, L, o.mask == 'rounded' ? 'rounded' : 'circle', r, sparams);
  }

  canvas.restore();
}

/// 素材格子预览：和成品走同一套绘制函数，卡片上看到什么出图就是什么
void renderSwatch(
  Canvas canvas,
  double L, {
  required String kind,
  required String id,
  Color color = const Color(0xFFFF6B6B),
  Color bg = const Color(0xFF3A3A44),
}) {
  final c = Pc(canvas, Rect.fromLTWH(0, 0, L, L));
  canvas.save();
  canvas.clipRect(Rect.fromLTWH(0, 0, L, L));

  final cx = L / 2;
  final cy = L / 2;
  final r = L * 0.33;

  switch (kind) {
    case 'frame':
      c.circle(cx, cy, r, color: const Color(0xFFF2F2F4));
      drawFrame(
        c,
        FrameState(
          id: id,
          shape: 'circle',
          cx: cx,
          cy: cy,
          r: r,
          color: color,
          width: math.max(1.4, L * 0.032),
          gap: math.max(1.6, L * 0.04),
          alpha: 1,
        ),
      );
      break;

    case 'shape':
      c.fillPath(shapePath(id, cx, cy, L * 0.38, const {}),
          color: color);
      break;

    case 'pattern':
      c.circle(cx, cy, L * 0.42, color: bg);
      c.save();
      c.clipPath(Path()
        ..addArc(Rect.fromCircle(center: Offset(cx, cy), radius: L * 0.42), 0,
            math.pi * 2));
      drawPattern(
        c,
        L,
        id: id,
        color: color,
        alpha: 0.85,
        density: 0.55,
        r: L * 0.42,
      );
      c.restore();
      break;

    case 'sticker':
      c.save();
      c.translate(cx, cy);
      drawSticker(
        c,
        id: id,
        kind: stickerById(id) != null ? 'vector' : 'emoji',
        size: L * 0.52,
        color: color,
      );
      c.restore();
      break;
  }

  canvas.restore();
}

import 'package:flutter/painting.dart';

import '../core/px.dart';
import 'palettes.dart';

/// 一份"装修配方"。整张图的全部信息都在这几百字节里，
/// 和排版无关 —— 240 缩略图 / 540 编辑画布 / 1080 导出共用同一份。
class Recipe {
  Recipe({
    this.id = '',
    this.name = '未命名',
    this.cat = 'style',
    this.paletteId = 'pure',
    this.canvas = 540,
    required this.backdrop,
    required this.shape,
    required this.photo,
    required this.frame,
    required this.pattern,
    List<StickerCfg>? stickers,
    List<TextCfg>? texts,
    this.mask,
    this.cover = '',
    this.remote = false,
  })  : stickers = stickers ?? <StickerCfg>[],
        texts = texts ?? <TextCfg>[];

  String id;
  String name;
  String cat;
  String paletteId;
  int canvas;
  Backdrop backdrop;
  ShapeCfg shape;
  PhotoCfg photo;
  FrameCfg frame;
  PatternCfg pattern;
  List<StickerCfg> stickers;
  List<TextCfg> texts;

  /// 遮罩图模板：一张带透明通道的 PNG 当顶层，照片铺满画布垫在下面
  MaskCfg? mask;

  /// 首页卡片封面（后台单独传的效果图），只有在线模板才有
  String cover;

  /// 来自后台下发的在线模板
  bool remote;

  bool get isMask => mask != null && mask!.url.isNotEmpty;

  Recipe clone() => Recipe.fromJson(toJson());

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'cat': cat,
        'paletteId': paletteId,
        'canvas': canvas,
        'backdrop': backdrop.toJson(),
        'shape': shape.toJson(),
        'photo': photo.toJson(),
        'frame': frame.toJson(),
        'pattern': pattern.toJson(),
        'stickers': stickers.map((e) => e.toJson()).toList(),
        'texts': texts.map((e) => e.toJson()).toList(),
        if (mask != null) 'mask': mask!.toJson(),
        'cover': cover,
        'remote': remote,
      };

  static Recipe fromJson(Map<String, dynamic> j) {
    final base = blankRecipe(j['paletteId'] as String?);
    final rec = Recipe(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? base.name).toString(),
      cat: (j['cat'] ?? base.cat).toString(),
      paletteId: (j['paletteId'] ?? base.paletteId).toString(),
      canvas: (j['canvas'] as num?)?.toInt() ?? 540,
      backdrop: Backdrop.fromJson(
          {...base.backdrop.toJson(), ..._asMap(j['backdrop'])}),
      shape: ShapeCfg.fromJson({...base.shape.toJson(), ..._asMap(j['shape'])}),
      photo: PhotoCfg.fromJson({...base.photo.toJson(), ..._asMap(j['photo'])}),
      frame: FrameCfg.fromJson({...base.frame.toJson(), ..._asMap(j['frame'])}),
      pattern: PatternCfg.fromJson(
          {...base.pattern.toJson(), ..._asMap(j['pattern'])}),
      stickers: ((j['stickers'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => StickerCfg.fromJson(e.cast<String, dynamic>()))
          .toList(),
      texts: ((j['texts'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => TextCfg.fromJson(e.cast<String, dynamic>()))
          .toList(),
      mask: (j['mask'] is Map)
          ? MaskCfg.fromJson(_asMap(j['mask']))
          : null,
      cover: (j['cover'] ?? '').toString(),
      remote: j['remote'] == true,
    );
    // 老配方兼容：照片滤镜缺字段时补默认值
    rec.photo.filters = FilterCfg.fromJson({
      ...base.photo.filters.toJson(),
      ...(j['photo'] is Map ? _asMap(_asMap(j['photo'])['filters']) : {}),
    });
    return rec;
  }

  static Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map) return v.cast<String, dynamic>();
    return <String, dynamic>{};
  }
}

class Backdrop {
  Backdrop({
    this.type = 'linear',
    List<(Color, double)>? stops,
    this.angle = 155,
    this.cx = 0,
    this.cy = 0,
    this.cells = 8,
  }) : stops = stops ??
            <(Color, double)>[
              (const Color(0xFFFFFFFF), 0),
              (const Color(0xFFF1F1F4), 1),
            ];

  String type;
  List<(Color, double)> stops;
  double angle;
  double cx;
  double cy;
  int cells;

  Map<String, dynamic> toJson() => {
        'type': type,
        'stops': stops
            .map((e) => [colorToHex(e.$1), e.$2])
            .toList(),
        'angle': angle,
        'cx': cx,
        'cy': cy,
        'cells': cells,
      };

  static Backdrop fromJson(Map<String, dynamic> j) {
    final rawStops = (j['stops'] as List?) ?? [];
    final stops = <(Color, double)>[];
    for (final s in rawStops) {
      if (s is List && s.length >= 2) {
        stops.add((hexColor(s[0].toString()), (s[1] as num).toDouble()));
      }
    }
    return Backdrop(
      type: (j['type'] ?? 'linear').toString(),
      stops: stops.isEmpty
          ? <(Color, double)>[
              (const Color(0xFFFFFFFF), 0),
              (const Color(0xFFF1F1F4), 1),
            ]
          : stops,
      angle: (j['angle'] as num?)?.toDouble() ?? 155,
      cx: (j['cx'] as num?)?.toDouble() ?? 0,
      cy: (j['cy'] as num?)?.toDouble() ?? 0,
      cells: (j['cells'] as num?)?.toInt() ?? 8,
    );
  }
}

class ShapeCfg {
  ShapeCfg({
    this.type = 'square',
    this.inset = 0,
    Map<String, double>? params,
  }) : params = params ?? <String, double>{};

  String type;
  double inset;
  Map<String, double> params;

  Map<String, dynamic> toJson() => {
        'type': type,
        'inset': inset,
        'params': params,
      };

  static ShapeCfg fromJson(Map<String, dynamic> j) => ShapeCfg(
        type: (j['type'] ?? 'square').toString(),
        inset: (j['inset'] as num?)?.toDouble() ?? 0,
        params: ((j['params'] as Map?) ?? {})
            .map((k, v) => MapEntry(k.toString(), (v as num).toDouble())),
      );
}

class FilterCfg {
  FilterCfg({
    this.brightness = 1,
    this.contrast = 1,
    this.saturate = 1,
    this.hue = 0,
    this.temperature = 0,
    this.style = '',
    this.styleOpacity = 1,
  });

  double brightness;
  double contrast;
  double saturate;
  double hue;
  double temperature;
  String style;
  double styleOpacity;

  bool get isNeutral =>
      (brightness - 1).abs() < 0.001 &&
      (contrast - 1).abs() < 0.001 &&
      (saturate - 1).abs() < 0.001 &&
      hue.abs() < 0.5 &&
      temperature.abs() < 0.5;

  Map<String, dynamic> toJson() => {
        'brightness': brightness,
        'contrast': contrast,
        'saturate': saturate,
        'hue': hue,
        'temperature': temperature,
        'style': style,
        'styleOpacity': styleOpacity,
      };

  static FilterCfg fromJson(Map<String, dynamic> j) => FilterCfg(
        brightness: (j['brightness'] as num?)?.toDouble() ?? 1,
        contrast: (j['contrast'] as num?)?.toDouble() ?? 1,
        saturate: (j['saturate'] as num?)?.toDouble() ?? 1,
        hue: (j['hue'] as num?)?.toDouble() ?? 0,
        temperature: (j['temperature'] as num?)?.toDouble() ?? 0,
        style: (j['style'] ?? '').toString(),
        styleOpacity: (j['styleOpacity'] as num?)?.toDouble() ?? 1,
      );
}

class PhotoCfg {
  PhotoCfg({
    this.src = '',
    this.scale = 1.14,
    this.x = 0,
    this.y = 0,
    this.rotate = 0,
    FilterCfg? filters,
  }) : filters = filters ?? FilterCfg();

  /// 图片本体：小程序里是本地临时路径，Flutter 里是 data URL 或内存字节
  String src;
  double scale;
  double x;
  double y;
  double rotate;
  FilterCfg filters;

  Map<String, dynamic> toJson() => {
        'src': src,
        'scale': scale,
        'x': x,
        'y': y,
        'rotate': rotate,
        'filters': filters.toJson(),
      };

  static PhotoCfg fromJson(Map<String, dynamic> j) => PhotoCfg(
        src: (j['src'] ?? '').toString(),
        scale: (j['scale'] as num?)?.toDouble() ?? 1.14,
        x: (j['x'] as num?)?.toDouble() ?? 0,
        y: (j['y'] as num?)?.toDouble() ?? 0,
        rotate: (j['rotate'] as num?)?.toDouble() ?? 0,
        filters: FilterCfg.fromJson(
            ((j['filters'] as Map?) ?? {}).cast<String, dynamic>()),
      );
}

class FrameCfg {
  FrameCfg({
    this.id = '',
    this.color = const Color(0xFF1A1A1A),
    this.width = 8,
    this.gap = 10,
    this.alpha = 1,
  });

  String id;
  Color color;
  double width;
  double gap;
  double alpha;

  Map<String, dynamic> toJson() => {
        'id': id,
        'color': colorToHex(color),
        'width': width,
        'gap': gap,
        'alpha': alpha,
      };

  static FrameCfg fromJson(Map<String, dynamic> j) => FrameCfg(
        id: (j['id'] ?? '').toString(),
        color: hexColor((j['color'] ?? '#1A1A1A').toString()),
        width: (j['width'] as num?)?.toDouble() ?? 8,
        gap: (j['gap'] as num?)?.toDouble() ?? 10,
        alpha: (j['alpha'] as num?)?.toDouble() ?? 1,
      );
}

class PatternCfg {
  PatternCfg({
    this.id = '',
    this.color = const Color(0xFFFFFFFF),
    this.density = 0.45,
    this.alpha = 0.7,
  });

  String id;
  Color color;
  double density;
  double alpha;

  Map<String, dynamic> toJson() => {
        'id': id,
        'color': colorToHex(color),
        'density': density,
        'alpha': alpha,
      };

  static PatternCfg fromJson(Map<String, dynamic> j) => PatternCfg(
        id: (j['id'] ?? '').toString(),
        color: hexColor((j['color'] ?? '#FFFFFF').toString()),
        density: (j['density'] as num?)?.toDouble() ?? 0.45,
        alpha: (j['alpha'] as num?)?.toDouble() ?? 0.7,
      );
}

class StickerCfg {
  StickerCfg({
    required this.id,
    this.kind = 'vector',
    this.x = 0.5,
    this.y = 0.3,
    this.scale = 1,
    this.rotate = 0,
    this.alpha = 1,
    this.color = const Color(0xFFFF6B6B),
  });

  String id;
  String kind;
  double x;
  double y;
  double scale;
  double rotate;
  double alpha;
  Color color;

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'x': x,
        'y': y,
        'scale': scale,
        'rotate': rotate,
        'alpha': alpha,
        'color': colorToHex(color),
      };

  static StickerCfg fromJson(Map<String, dynamic> j) => StickerCfg(
        id: (j['id'] ?? '').toString(),
        kind: (j['kind'] ?? 'vector').toString(),
        x: (j['x'] as num?)?.toDouble() ?? 0.5,
        y: (j['y'] as num?)?.toDouble() ?? 0.3,
        scale: (j['scale'] as num?)?.toDouble() ?? 1,
        rotate: (j['rotate'] as num?)?.toDouble() ?? 0,
        alpha: (j['alpha'] as num?)?.toDouble() ?? 1,
        color: hexColor((j['color'] ?? '#FF6B6B').toString()),
      );
}

class TextShadow {
  TextShadow({
    this.dx = 0,
    this.dy = 2,
    this.blur = 8,
    this.color = const Color(0x47000000),
  });

  double dx;
  double dy;
  double blur;
  Color color;

  Map<String, dynamic> toJson() => {
        'dx': dx,
        'dy': dy,
        'blur': blur,
        'color': colorToHex(color),
      };

  static TextShadow fromJson(Map<String, dynamic> j) => TextShadow(
        dx: (j['dx'] as num?)?.toDouble() ?? 0,
        dy: (j['dy'] as num?)?.toDouble() ?? 2,
        blur: (j['blur'] as num?)?.toDouble() ?? 8,
        color: hexColor((j['color'] ?? '#47000000').toString(),
            const Color(0x47000000)),
      );
}

class TextCfg {
  TextCfg({
    this.text = '输入文字',
    this.x = 0.5,
    this.y = 0.85,
    this.size = 46,
    this.color = const Color(0xFF1A1A1A),
    this.stroke = const Color(0xFF000000),
    this.strokeWidth = 0,
    TextShadow? shadow,
    this.weight = 'bold',
    this.arc = 0,
    this.gradient = false,
  }) : shadow = shadow ?? TextShadow();

  String text;
  double x;
  double y;
  double size;
  Color color;
  Color stroke;
  double strokeWidth;
  TextShadow shadow;
  String weight;
  double arc;
  bool gradient;

  Map<String, dynamic> toJson() => {
        'text': text,
        'x': x,
        'y': y,
        'size': size,
        'color': colorToHex(color),
        'stroke': colorToHex(stroke),
        'strokeWidth': strokeWidth,
        'shadow': shadow.toJson(),
        'weight': weight,
        'arc': arc,
        'gradient': gradient,
      };

  static TextCfg fromJson(Map<String, dynamic> j) => TextCfg(
        text: (j['text'] ?? '').toString(),
        x: (j['x'] as num?)?.toDouble() ?? 0.5,
        y: (j['y'] as num?)?.toDouble() ?? 0.85,
        size: (j['size'] as num?)?.toDouble() ?? 46,
        color: hexColor((j['color'] ?? '#1A1A1A').toString()),
        stroke: hexColor((j['stroke'] ?? '#000000').toString()),
        strokeWidth: (j['strokeWidth'] as num?)?.toDouble() ?? 0,
        shadow: j['shadow'] is Map
            ? TextShadow.fromJson((j['shadow'] as Map).cast<String, dynamic>())
            : TextShadow(),
        weight: (j['weight'] ?? 'bold').toString(),
        arc: (j['arc'] as num?)?.toDouble() ?? 0,
        gradient: j['gradient'] == true,
      );
}

class MaskCfg {
  MaskCfg({this.url = '', this.overlay = '', this.cover = ''});

  String url;
  String overlay;
  String cover;

  Map<String, dynamic> toJson() => {
        'url': url,
        'overlay': overlay,
        'cover': cover,
      };

  static MaskCfg fromJson(Map<String, dynamic> j) => MaskCfg(
        url: (j['url'] ?? '').toString(),
        overlay: (j['overlay'] ?? '').toString(),
        cover: (j['cover'] ?? '').toString(),
      );
}

// ---------------------------------------------------------------------------
// 配方工厂
// ---------------------------------------------------------------------------

Recipe blankRecipe([String? paletteId]) {
  final pal = paletteById(paletteId ?? 'pure');
  return Recipe(
    id: '',
    name: '未命名',
    cat: 'style',
    paletteId: pal.id,
    backdrop: Backdrop(
      type: 'linear',
      stops: [(pal.bg1, 0), (pal.bg2, 1)],
      angle: 155,
    ),
    shape: ShapeCfg(type: 'square', inset: 0),
    photo: PhotoCfg(),
    frame: FrameCfg(id: '', color: pal.frame, width: 8, gap: 10, alpha: 1),
    pattern: PatternCfg(id: '', color: pal.frame, density: 0.45, alpha: 0.7),
  );
}

TextCfg newTextCfg(Recipe rec) {
  final pal = paletteById(rec.paletteId);
  return TextCfg(
    text: '输入文字',
    x: 0.5,
    y: 0.85,
    size: 46,
    color: pal.text,
    stroke: const Color(0xFF000000),
    strokeWidth: 0,
    shadow: TextShadow(dx: 0, dy: 2, blur: 8, color: const Color(0x47000000)),
    weight: 'bold',
    arc: 0,
    gradient: false,
  );
}

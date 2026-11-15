import 'dart:convert';

import 'package:flutter/painting.dart';

import '../core/px.dart';
import 'models.dart';
import 'palettes.dart';

class PresetCat {
  const PresetCat(this.id, this.name);
  final String id;
  final String name;
}

const List<PresetCat> presetCats = [
  PresetCat('all', '推荐'),
  PresetCat('festival', '节日'),
  PresetCat('boost', '加油'),
  PresetCat('style', '风格'),
  PresetCat('career', '职业'),
];

/// 紧凑写法的模板定义（= 小程序 presets.js 里 RAW 的每一项）
class PresetSpec {
  const PresetSpec({
    required this.id,
    required this.name,
    required this.cat,
    required this.pal,
    this.bgType,
    this.bg1,
    this.bg2,
    this.angle,
    this.shape,
    this.inset,
    this.pscale,
    this.brightness,
    this.contrast,
    this.saturate,
    this.temperature,
    this.filter,
    this.frame,
    this.fcolor,
    this.fw,
    this.fg,
    this.pattern,
    this.pd,
    this.pa,
    this.sticker,
    this.stickerKind,
    this.stickerColor,
    this.text,
    this.ty,
    this.tsize,
    this.tcolor,
    this.arc,
    this.gradient,
  });

  final String id;
  final String name;
  final String cat;
  final String pal;
  final String? bgType;
  final Color? bg1;
  final Color? bg2;
  final double? angle;
  final String? shape;
  final double? inset;
  final double? pscale;
  final double? brightness;
  final double? contrast;
  final double? saturate;
  final double? temperature;
  final String? filter;
  final String? frame;
  final Color? fcolor;
  final double? fw;
  final double? fg;
  final String? pattern;
  final double? pd;
  final double? pa;
  final String? sticker;
  final String? stickerKind;
  final Color? stickerColor;
  final String? text;
  final double? ty;
  final double? tsize;
  final Color? tcolor;
  final double? arc;
  final bool? gradient;

  /// 后台下发的"紧凑配置"（小程序 presets.mk 的入参）→ 同一个构建器。
  /// 字段名与 mk 完全一致，缺项一律走默认值，脏数据不会炸。
  factory PresetSpec.fromMap(Map<String, dynamic> m) {
    String str(String k, [String d = '']) {
      final v = m[k];
      if (v == null) return d;
      final t = v.toString().trim();
      return t.isEmpty ? d : t;
    }

    double? num_(String k) {
      final v = m[k];
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    return PresetSpec(
      id: str('id'),
      name: str('name', '在线模板'),
      cat: str('cat', 'online'),
      pal: str('pal', 'pure'),
      bgType: m['bgType'] == null ? null : str('bgType'),
      bg1: colorFromCss(m['bg1']),
      bg2: colorFromCss(m['bg2']),
      angle: num_('angle'),
      shape: m['shape'] == null ? null : str('shape'),
      inset: num_('inset'),
      pscale: num_('pscale'),
      brightness: num_('brightness'),
      contrast: num_('contrast'),
      saturate: num_('saturate'),
      temperature: num_('temperature'),
      filter: m['filter'] == null ? null : str('filter'),
      frame: m['frame'] == null ? null : str('frame'),
      fcolor: colorFromCss(m['fcolor']),
      fw: num_('fw'),
      fg: num_('fg'),
      pattern: m['pattern'] == null ? null : str('pattern'),
      pd: num_('pd'),
      pa: num_('pa'),
      sticker: m['sticker'] == null ? null : str('sticker'),
      stickerKind: m['stickerKind'] == null ? null : str('stickerKind'),
      stickerColor: colorFromCss(m['stickerColor']),
      text: m['text'] == null ? null : str('text'),
      ty: num_('ty'),
      tsize: num_('tsize'),
      tcolor: colorFromCss(m['tcolor']),
      arc: num_('arc'),
      gradient: m['gradient'] == true,
    );
  }

  /// 模板就是一份装修配方，几百字节，扩容成本几乎为零
  Recipe build() {
    final p = paletteById(pal);

    // 纹样颜色不能一律取"边框色"。浅色模板的边框色是白的，
    // 白纹样画在浅底上等于没画，十几套模板会长得一模一样。
    // 所以按底色明暗分流：深底用白，浅底用强调色压深一档。
    final bgLuma = (luma(p.bg1) + luma(p.bg2)) / 2;
    final patternColor =
        bgLuma > 0.6 ? darken(p.accent, 0.06) : p.frame;

    return Recipe(
      id: id,
      name: name,
      cat: cat,
      paletteId: p.id,
      backdrop: Backdrop(
        type: bgType ?? 'linear',
        stops: [(bg1 ?? p.bg1, 0), (bg2 ?? p.bg2, 1)],
        angle: angle ?? 155,
      ),
      shape: ShapeCfg(type: shape ?? 'circle', inset: inset ?? 0),
      photo: PhotoCfg(
        scale: pscale ?? 1.14,
        filters: FilterCfg(
          brightness: brightness ?? 1,
          contrast: contrast ?? 1,
          saturate: saturate ?? 1,
          hue: 0,
          temperature: temperature ?? 0,
          style: filter ?? '',
          styleOpacity: 1,
        ),
      ),
      frame: frame == null
          ? FrameCfg(id: '')
          : FrameCfg(
              id: frame!,
              color: fcolor ?? p.frame,
              width: fw ?? 8,
              gap: fg ?? 10,
              alpha: 1,
            ),
      pattern: pattern == null
          ? PatternCfg(id: '')
          : PatternCfg(
              id: pattern!,
              color: patternColor,
              density: pd ?? 0.38,
              alpha: pa ?? 0.5,
            ),
      stickers: sticker == null
          ? <StickerCfg>[]
          : <StickerCfg>[
              StickerCfg(
                id: sticker!,
                kind: stickerKind ?? 'vector',
                x: 0.5,
                y: 0.16,
                scale: 0.9,
                rotate: 0,
                alpha: 1,
                color: stickerColor ?? p.frame,
              )
            ],
      texts: text == null
          ? <TextCfg>[]
          : <TextCfg>[
              TextCfg(
                text: text!,
                x: 0.5,
                y: ty ?? 0.85,
                size: tsize ?? 46,
                color: tcolor ?? p.text,
                stroke: const Color(0xFF000000),
                strokeWidth: 0,
                shadow: TextShadow(
                    dx: 0, dy: 2, blur: 8, color: const Color(0x47000000)),
                weight: 'bold',
                arc: arc ?? 0,
                gradient: gradient ?? false,
              )
            ],
    );
  }
}

const List<PresetSpec> presetSpecs = [
  PresetSpec(id: 'p1', name: '新年红', cat: 'festival', pal: 'festive', frame: 'ring2', pattern: 'sparkle', text: '新年快乐'),
  PresetSpec(id: 'p2', name: '中秋月', cat: 'festival', pal: 'moon', frame: 'moon', pattern: 'bokeh', text: '花好月圆'),
  PresetSpec(id: 'p3', name: '圣诞雪', cat: 'festival', pal: 'snow', frame: 'snow', pattern: 'snow', text: '圣诞快乐'),
  PresetSpec(id: 'p4', name: '万圣夜', cat: 'festival', pal: 'blood', frame: 'dash2', pattern: 'grain', text: 'HALLOWEEN', tsize: 34),
  PresetSpec(id: 'p5', name: '七夕', cat: 'festival', pal: 'rose', frame: 'sakura', pattern: 'hearts', text: '七夕快乐'),
  PresetSpec(id: 'p6', name: '端午', cat: 'festival', pal: 'forest', frame: 'laurel', pattern: 'dots', text: '端午安康'),
  PresetSpec(id: 'p7', name: '毕业季', cat: 'festival', pal: 'sky', frame: 'grad', pattern: 'sparkle', text: '毕业快乐'),
  PresetSpec(id: 'p8', name: '元宵', cat: 'festival', pal: 'festive', frame: 'glow', pattern: 'bokeh', text: '元宵节'),
  PresetSpec(id: 'p9', name: '重阳', cat: 'festival', pal: 'sand', frame: 'laurel'),
  PresetSpec(id: 'p10', name: '春节', cat: 'festival', pal: 'festive', frame: 'candy', pattern: 'sparkle', text: '恭贺新禧'),
  PresetSpec(id: 'p11', name: '生日', cat: 'festival', pal: 'peach', frame: 'sakura', pattern: 'petals', text: '生日快乐', filter: 'cream'),
  PresetSpec(id: 'p12', name: '欢度国庆', cat: 'festival', pal: 'festive', frame: 'crown', pattern: 'sparkle', text: '欢度国庆', fcolor: Color(0xFFF5D76E)),

  PresetSpec(id: 'p13', name: '上岸', cat: 'boost', pal: 'ocean', frame: 'ring2', pattern: 'sweep', text: '上岸'),
  PresetSpec(id: 'p14', name: '加油', cat: 'boost', pal: 'sky', frame: 'grad', text: '加油'),
  PresetSpec(id: 'p15', name: 'Offer 到', cat: 'boost', pal: 'mint', frame: 'halo', text: 'OFFER', tsize: 40),
  PresetSpec(id: 'p16', name: '上线', cat: 'boost', pal: 'cyber', frame: 'neon', pattern: 'grid', text: 'GO LIVE', tsize: 36),
  PresetSpec(id: 'p17', name: '暴富', cat: 'boost', pal: 'gold', frame: 'crown', pattern: 'sparkle', text: '暴富'),
  PresetSpec(id: 'p18', name: '拒绝内耗', cat: 'boost', pal: 'mono', frame: 'dash', text: '拒绝内耗', tsize: 38),
  PresetSpec(id: 'p19', name: '稳', cat: 'boost', pal: 'ink', frame: 'ring', text: '稳', tsize: 64),
  PresetSpec(id: 'p20', name: '搞钱', cat: 'boost', pal: 'gold', frame: 'film', pattern: 'sparkle', text: '搞钱'),
  PresetSpec(id: 'p21', name: '佛系', cat: 'boost', pal: 'sand', frame: 'wave', text: '佛系'),
  PresetSpec(id: 'p22', name: '躺平', cat: 'boost', pal: 'lavender', frame: 'dash2', text: '躺平'),

  PresetSpec(id: 'p23', name: '极简白', cat: 'style', pal: 'pure', frame: 'ring'),
  PresetSpec(id: 'p24', name: '黑白胶片', cat: 'style', pal: 'ink', frame: 'film', pattern: 'grain', filter: 'mono'),
  PresetSpec(id: 'p25', name: '莫兰迪', cat: 'style', pal: 'morandi', frame: 'ring2'),
  PresetSpec(id: 'p26', name: '赛博霓虹', cat: 'style', pal: 'cyber', frame: 'neon', filter: 'cyber', pattern: 'grid'),
  PresetSpec(id: 'p27', name: '日系手绘', cat: 'style', pal: 'cream', frame: 'daisy', filter: 'japan'),
  PresetSpec(id: 'p28', name: 'Y2K', cat: 'style', pal: 'neon', frame: 'pixel', pattern: 'grid'),
  PresetSpec(id: 'p29', name: '蒸汽波', cat: 'style', pal: 'lilac', frame: 'grad', pattern: 'bokeh'),
  PresetSpec(id: 'p30', name: '暗黑哥特', cat: 'style', pal: 'blood', frame: 'gear'),
  PresetSpec(id: 'p31', name: '国风华纹', cat: 'style', pal: 'clay', frame: 'vine'),
  PresetSpec(id: 'p32', name: '复古胶片', cat: 'style', pal: 'sand', frame: 'film', filter: 'vintage', pattern: 'grain'),

  PresetSpec(id: 'p33', name: '程序员', cat: 'career', pal: 'dusk', frame: 'gear', pattern: 'grid', text: '码', tsize: 52),
  PresetSpec(id: 'p34', name: '教师', cat: 'career', pal: 'forest', frame: 'laurel', text: '师', tsize: 52),
  PresetSpec(id: 'p35', name: '医生', cat: 'career', pal: 'mint', frame: 'ring2', text: '医', tsize: 52),
  PresetSpec(id: 'p36', name: '店主', cat: 'career', pal: 'clay', frame: 'ring', text: '掌柜', tsize: 40),

  PresetSpec(id: 'p37', name: '花冠', cat: 'style', pal: 'peach', frame: 'sakura', pattern: 'petals'),
  PresetSpec(id: 'p38', name: '星空', cat: 'style', pal: 'ocean', frame: 'sparkle', pattern: 'sparkle'),
  PresetSpec(id: 'p39', name: '奶咖', cat: 'style', pal: 'cream', frame: 'wave', filter: 'cream'),
  PresetSpec(id: 'p40', name: '心动', cat: 'style', pal: 'rose', frame: 'glow', pattern: 'hearts'),
  PresetSpec(id: 'p41', name: '春日', cat: 'style', pal: 'mint', frame: 'daisy', pattern: 'petals'),
  PresetSpec(id: 'p42', name: '秋叶', cat: 'style', pal: 'clay', frame: 'laurel', pattern: 'petals'),
  PresetSpec(id: 'p43', name: '雪夜', cat: 'festival', pal: 'snow', frame: 'snow', pattern: 'snow', filter: 'cool'),
  PresetSpec(id: 'p44', name: '深海', cat: 'style', pal: 'ocean', frame: 'wave', pattern: 'bubbles'),
  PresetSpec(id: 'p45', name: '玫瑰金', cat: 'style', pal: 'rose', frame: 'halo'),
  PresetSpec(id: 'p46', name: '赛博紫', cat: 'style', pal: 'cyber', frame: 'gear', pattern: 'grid', filter: 'cyber'),
  PresetSpec(id: 'p47', name: '加油鸭', cat: 'boost', pal: 'peach', frame: 'dash', text: '加油鸭', tsize: 42),
  PresetSpec(id: 'p48', name: '有钱', cat: 'boost', pal: 'gold', frame: 'film', pattern: 'sparkle', text: '有钱'),

  PresetSpec(id: 'p49', name: '清明', cat: 'festival', pal: 'mint', frame: 'wave', pattern: 'rain', text: '清明', tsize: 42),
  PresetSpec(id: 'p50', name: '母亲节', cat: 'festival', pal: 'rose', frame: 'sakura', pattern: 'petals', text: '母亲节', tsize: 40),
  PresetSpec(id: 'p51', name: '儿童节', cat: 'festival', pal: 'coral', frame: 'candy', pattern: 'bokeh', text: '儿童节', tsize: 40, sticker: 'smiley', stickerColor: Color(0xFFFFB020)),
  PresetSpec(id: 'p52', name: '520', cat: 'festival', pal: 'peach', frame: 'glow', pattern: 'hearts', text: '520', tsize: 44, ty: 0.8, shape: 'heart', inset: 0.16, filter: 'warm'),
  PresetSpec(id: 'p53', name: '自律', cat: 'boost', pal: 'pure', frame: 'inner', fcolor: Color(0xFFB6B6C0), text: '自律', tsize: 46),
  PresetSpec(id: 'p54', name: '准点下班', cat: 'boost', pal: 'sky', frame: 'duo', text: '准点下班', tsize: 34),

  PresetSpec(id: 'p55', name: '猫耳', cat: 'style', pal: 'cream', frame: 'catear', filter: 'cream'),
  PresetSpec(id: 'p56', name: '兔耳', cat: 'style', pal: 'lavender', frame: 'rabbit', fcolor: Color(0xFF7A66B8), pattern: 'bokeh'),
  PresetSpec(id: 'p57', name: '蝴蝶结', cat: 'style', pal: 'lilac', frame: 'bow', fcolor: Color(0xFF6C48C7), pattern: 'sparkle'),

  PresetSpec(id: 'p58', name: '律师', cat: 'career', pal: 'ink', frame: 'zigzag', text: '法', tsize: 56),
  PresetSpec(id: 'p59', name: '财务', cat: 'career', pal: 'sand', frame: 'ring2', text: '¥', tsize: 64),
  PresetSpec(id: 'p60', name: '主播', cat: 'career', pal: 'neon', frame: 'pixel', pattern: 'grid', text: 'LIVE', tsize: 32, filter: 'cyber'),
];

/// 内置模板（首次访问时构建一次）
final List<Recipe> presetList = presetSpecs.map((e) => e.build()).toList();

final Map<String, Recipe> presetById = {
  for (final r in presetList) r.id: r
};

/// 推荐的挑法：每类取最具代表性的，混排后视觉差异最大
const List<String> recommendIds = [
  'p1', 'p17', 'p55', 'p26', 'p13', 'p37', 'p52', 'p23',
  'p25', 'p57', 'p24', 'p40', 'p33', 'p56', 'p2', 'p54',
];

/// 在线模板一律排前面：运营刚配的模板要第一眼看到，不能被内置 60 套埋到底部
List<Recipe> _remoteFirst(List<Recipe> arr) =>
    arr.where((r) => r.remote).toList()..addAll(arr.where((r) => !r.remote));

List<Recipe> listBy(String cat) {
  if (cat.isEmpty || cat == 'all') {
    final picked = recommendIds
        .map((id) => presetById[id])
        .whereType<Recipe>()
        .toList();
    final rest = presetList.where((r) => !recommendIds.contains(r.id));
    return _remoteFirst([...picked, ...rest]);
  }
  if (cat == 'online') {
    return presetList.where((r) => r.remote).toList();
  }
  return _remoteFirst(presetList.where((r) => r.cat == cat).toList());
}

/* ------------------------------ 在线模板合并 ------------------------------ */

/// CSS 颜色 → Color。后台配方里的颜色是直接喂 canvas 的字符串，
/// 可能是 `#RGB` / `#RRGGBB` / `#AARRGGBB` / `rgb()` / `rgba()`，解析不了就返回 null。
Color? colorFromCss(dynamic v) {
  if (v == null) return null;
  if (v is Color) return v;
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  if (s.startsWith('#')) {
    var h = s.substring(1);
    if (h.length == 3) {
      h = h.split('').map((c) => '$c$c').join();
    }
    if (h.length == 6) return Color(int.parse('FF$h', radix: 16));
    if (h.length == 8) return Color(int.parse(h, radix: 16));
    return null;
  }
  final m = RegExp(r'rgba?\(([^)]+)\)').firstMatch(s);
  if (m != null) {
    final parts = m.group(1)!.split(',').map((e) => e.trim()).toList();
    if (parts.length < 3) return null;
    int ch(int i) => (int.tryParse(parts[i]) ?? 0).clamp(0, 255);
    final a = parts.length >= 4
        ? (double.tryParse(parts[3]) ?? 1).clamp(0.0, 1.0)
        : 1.0;
    return Color.from(
      alpha: a,
      red: ch(0) / 255,
      green: ch(1) / 255,
      blue: ch(2) / 255,
    );
  }
  return null;
}

/// 把后台下发的一批行合并进 [presetList] / [presetById]，返回**在线模板总数**。
///
/// 三种形态：
///   1. 遮罩图（templateType='mask'）—— 一张带透明通道的 PNG 当顶层，照片铺满垫在下面；
///   2. 完整 recipe（有 backdrop + shape）—— normalize 后直接用；
///   3. 紧凑配置（mk 的输入，如 `{pal:'festive', frame:'ring2', text:'新年快乐'}`）。
/// id 冲突（重复下发 / 与本地撞车）直接跳过，所以重复调用是安全的。
int mergeRemoteRows(List<Map<String, dynamic>> rows) {
  for (final it in rows) {
    final id = (it['id'] ?? '').toString();
    if (id.isEmpty || presetById.containsKey(id)) continue;

    final name = (it['name'] ?? '').toString().isEmpty
        ? '在线模板'
        : it['name'].toString();
    final cat = (it['category'] ?? '').toString().isEmpty
        ? ((it['cat'] ?? '').toString().isEmpty
            ? 'online'
            : it['cat'].toString())
        : it['category'].toString();
    final cover = (it['coverUrl'] ?? '').toString();
    final type = (it['templateType'] ?? 'recipe').toString();

    if (type == 'mask') {
      final maskUrl = (it['maskUrl'] ?? '').toString();
      if (maskUrl.isEmpty) continue;
      final rec = blankRecipe('pure');
      rec.id = id;
      rec.name = name;
      rec.cat = cat;
      rec.mask = MaskCfg(
        url: maskUrl,
        overlay: (it['overlayUrl'] ?? '').toString(),
        // 首页卡片优先用封面图（后台可单独传一张带示例人物的效果图）
        cover: cover.isEmpty ? maskUrl : cover,
      );
      rec.cover = cover;
      rec.remote = true;
      presetList.add(rec);
      presetById[id] = rec;
      continue;
    }

    Recipe? rec;
    try {
      final raw = it['recipe'];
      Map<String, dynamic>? m;
      if (raw is String) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) m = decoded.cast<String, dynamic>();
      } else if (raw is Map) {
        m = raw.cast<String, dynamic>();
      }
      if (m == null) continue;
      if (m['backdrop'] != null && m['shape'] != null) {
        rec = Recipe.fromJson(m)
          ..id = id
          ..name = name
          ..cat = cat;
      } else {
        rec = PresetSpec.fromMap({...m, 'id': id, 'name': name, 'cat': cat})
            .build();
      }
    } catch (_) {
      continue;
    }
    rec.cover = cover;
    rec.remote = true;
    presetList.add(rec);
    presetById[rec.id] = rec;
  }
  return presetList.where((r) => r.remote).length;
}

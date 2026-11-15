import 'package:flutter/material.dart';

import '../store/local_store.dart';
import '../widgets/recipe_view.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  int _count = 0;
  int _bytes = 0;

  @override
  void initState() {
    super.initState();
    _measure();
  }

  void _measure() {
    final list = LocalStore.getWorks();
    var bytes = 0;
    for (final w in list) {
      bytes += w.thumb.length;
    }
    setState(() {
      _count = list.length;
      _bytes = bytes;
    });
  }

  String get _sizeText {
    if (_bytes > 1024 * 1024) {
      return '${(_bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    if (_bytes > 0) return '${(_bytes / 1024).round().clamp(1, 99999)} KB';
    return '0 KB';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          Center(
            child: Column(
              children: [
                ClipOval(
                  child: Image.asset('assets/logo.png',
                      width: 74,
                      height: 74,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                            width: 74,
                            height: 74,
                            color: const Color(0xFFFFF7E6),
                            child: const Icon(Icons.face_retouching_natural,
                                color: AppColors.coral, size: 34),
                          )),
                ),
                const SizedBox(height: 10),
                const Text('头像装修',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                const Text('v1.0.0 · Flutter 版',
                    style: TextStyle(fontSize: 12, color: AppColors.grey)),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _card('这个程序不碰你的照片', [
            '你选的每一张照片，都只在这台设备的浏览器内存里被处理，用来生成头像。'
                '不上传、不保存、也不收集任何照片或个人信息。',
            '生成后的图片由浏览器直接下载到本地「下载」目录，'
                '服务器端没有任何一行代码接收过你的照片。',
            '作品与草稿只存在浏览器 localStorage 里，清理站点数据或换设备后就没了。',
          ]),
          _card('用了哪些能力', [
            '选择图片 —— 只读取你主动选中的那一张。',
            '保存图片 —— 通过浏览器下载，不写入相册、不读取其他文件。',
            '本地存储 —— 只保存装修配方和缩略图，用于「作品」列表。',
          ]),
          _card('本机数据', [
            '作品数量：$_count 个',
            '占用空间：$_sizeText（含缩略图）',
          ]),
          _card('素材', [
            '边框、贴纸、纹样、形状全部由程序代码绘制，没有使用任何第三方图片素材，'
                '也不含受版权保护的形象。唯一的位图是左上角的品牌标。',
          ]),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('反馈请加微信 zhongdaiqi'),
                          behavior: SnackBarBehavior.floating),
                    );
                  },
                  child: const Text('意见反馈'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('清空本地数据'),
                        content: const Text('会删除全部作品记录与草稿（已下载的图片不受影响）。确定吗？'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('取消')),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFFE24B4A)),
                            child: const Text('清空'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) {
                      LocalStore.clearWorks();
                      LocalStore.clearDraft();
                      LocalStore.setFlag('tip_preset', false);
                      LocalStore.setFlag('tip_editor', false);
                      _measure();
                    }
                  },
                  style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE24B4A)),
                  child: const Text('清空本地数据'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Center(
            child: Text('照片不出设备 · 不登录 · 不看广告',
                style: TextStyle(fontSize: 11.5, color: Color(0xFFC4C4C8))),
          ),
        ],
      ),
    );
  }

  Widget _card(String title, List<String> paras) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          for (final p in paras)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Text(p,
                  style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.6,
                      color: Color(0xFF5A5A60))),
            ),
        ],
      ),
    );
  }
}

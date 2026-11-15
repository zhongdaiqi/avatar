import 'package:flutter/material.dart';

import '../core/remote.dart';
import '../data/models.dart';
import '../data/presets.dart';
import '../store/local_store.dart';
import '../widgets/recipe_view.dart';
import 'editor_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _cat = 'all';
  DraftRecord? _draft;
  List<PresetCat> _cats = List<PresetCat>.of(presetCats);

  @override
  void initState() {
    super.initState();
    _draft = LocalStore.getLiveDraft();
    _loadRemote();
  }

  /// 在线模板：缓存秒开 + 超时后台刷新；失败静默回退内置 60 套。
  /// 拉到之后补一个「在线」分类（紧跟推荐），运营刚配的模板要第一眼看到。
  Future<void> _loadRemote() async {
    final count = await RemoteTemplates.load();
    if (!mounted || count <= 0) return;
    if (_cats.any((c) => c.id == 'online')) {
      setState(() {});
      return;
    }
    setState(() {
      _cats = [..._cats]..insert(1, const PresetCat('online', '在线'));
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 从编辑器返回后草稿可能已经有了
    final d = LocalStore.getLiveDraft();
    if (d?.at != _draft?.at && mounted) {
      setState(() => _draft = d);
    }
  }

  Future<void> _open(Recipe rec, {String workId = ''}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditorPage(initial: rec.clone(), workId: workId),
      ),
    );
    if (!mounted) return;
    setState(() => _draft = LocalStore.getLiveDraft());
  }

  @override
  Widget build(BuildContext context) {
    final items = listBy(_cat);
    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _hero()),
              if (_draft != null)
                SliverToBoxAdapter(child: _draftCard(_draft!)),
              SliverToBoxAdapter(child: _catBar()),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.86,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final rec = items[i];
                      return _card(rec);
                    },
                    childCount: items.length,
                  ),
                ),
              ),
            ],
          ),
          Positioned(right: 16, bottom: 20, child: _fab()),
        ],
      ),
    );
  }

  Widget _hero() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Row(
        children: [
          ClipOval(
            child: Image.asset(
              'assets/logo.png',
              width: 54,
              height: 54,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 54,
                height: 54,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFFFF7E6),
                ),
                child: const Icon(Icons.face_retouching_natural,
                    color: AppColors.coral),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('头像装修',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1)),
              SizedBox(height: 4),
              Text('不用登录 · 不看广告 · 照片不出设备',
                  style: TextStyle(fontSize: 12, color: AppColors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _draftCard(DraftRecord d) {
    final label = d.recipe.texts.isNotEmpty && d.recipe.texts.first.text.isNotEmpty
        ? d.recipe.texts.first.text
        : d.recipe.name;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F6),
        border: Border.all(color: const Color(0xFFFFE0DD), width: 1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('继续上次装修',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600, color: AppColors.ink)),
                const SizedBox(height: 3),
                Text(
                  '${label.length > 10 ? label.substring(0, 10) : label} · ${d.agoLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Color(0xFFA08080)),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _open(d.recipe, workId: d.workId),
            style: TextButton.styleFrom(
              backgroundColor: AppColors.coral,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              minimumSize: const Size(0, 32),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(99)),
            ),
            child: const Text('继续', style: TextStyle(fontSize: 12.5)),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () {
              LocalStore.clearDraft();
              setState(() => _draft = null);
            },
            icon: const Icon(Icons.close, size: 16, color: Color(0xFFC0A8A6)),
          ),
        ],
      ),
    );
  }

  Widget _catBar() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _cats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final c = _cats[i];
          final on = c.id == _cat;
          return GestureDetector(
            onTap: () => setState(() => _cat = c.id),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: on ? AppColors.coral : AppColors.soft,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                c.name,
                style: TextStyle(
                  fontSize: 13,
                  color: on ? Colors.white : const Color(0xFF6B6B70),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _card(Recipe rec) {
    return GestureDetector(
      onTap: () => _open(rec),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _thumb(rec),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text(rec.name,
                style: const TextStyle(fontSize: 13, color: AppColors.ink)),
          ),
        ],
      ),
    );
  }

  /// 卡片缩略图。
  ///
  /// 配方模板本地按配方绘制（一图三渲染，缩略图 = 成品）；
  /// 遮罩图模板直接用后台那张封面 —— 本地渲染出来只是照片铺满 + 装饰，
  /// 跟后台效果图重复，也看不出它到底长什么样。
  Widget _thumb(Recipe rec) {
    final cover = rec.isMask ? rec.mask!.cover : '';
    if (cover.isNotEmpty) {
      return Image.network(
        cover,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _painted(rec),
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          return Container(
            color: AppColors.soft,
            alignment: Alignment.center,
            child: const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(AppColors.coral),
              ),
            ),
          );
        },
      );
    }
    return _painted(rec);
  }

  Widget _painted(Recipe rec) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: RecipePainter(recipe: rec, mask: 'none'),
        size: Size.infinite,
      ),
    );
  }

  Widget _fab() {
    return GestureDetector(
      onTap: () => _open(blankRecipe()),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: AppColors.coral,
          borderRadius: BorderRadius.circular(99),
          boxShadow: [
            BoxShadow(
              color: AppColors.coral.withValues(alpha: 0.36),
              blurRadius: 16,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: Row(
          children: const [
            Text('＋', style: TextStyle(color: Colors.white, fontSize: 17)),
            SizedBox(width: 4),
            Text('自由装修',
                style: TextStyle(color: Colors.white, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

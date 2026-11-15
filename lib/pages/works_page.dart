import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../store/local_store.dart';
import '../widgets/recipe_view.dart';
import 'editor_page.dart';

class WorksPage extends StatefulWidget {
  const WorksPage({super.key});

  @override
  State<WorksPage> createState() => _WorksPageState();
}

class _WorksPageState extends State<WorksPage> {
  List<Work> _list = <Work>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() => _list = LocalStore.getWorks());
  }

  Future<void> _open(Work w) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditorPage(initial: w.recipe.clone(), workId: w.id),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _del(Work w) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删掉这个作品？'),
        content: const Text('只是从列表里移除，下载到本地的图片不受影响。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFE24B4A)),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      LocalStore.removeWork(w.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: _list.isEmpty ? _empty() : _grid(),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.soft,
              border: Border.all(color: AppColors.line),
            ),
            child: const Icon(Icons.face_retouching_natural,
                size: 42, color: Color(0xFFD6D6DB)),
          ),
          const SizedBox(height: 18),
          const Text('还没有作品',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('装修一张，会存在这里，下次还能接着改',
              style: TextStyle(fontSize: 12.5, color: AppColors.grey)),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EditorPage(initial: blankRecipe()),
                ),
              );
              if (mounted) _load();
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.coral,
              padding:
                  const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
            ),
            child: const Text('去装修一张'),
          ),
        ],
      ),
    );
  }

  Widget _grid() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
            child: Text(
              '共 ${_list.length} 个作品 · 全部存在本机',
              style: const TextStyle(fontSize: 12, color: AppColors.grey),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 12,
              childAspectRatio: 0.8,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) => _card(_list[i]),
              childCount: _list.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _card(Work w) {
    final bytes = decodeDataUrl(w.thumb);
    return GestureDetector(
      onTap: () => _open(w),
      onLongPress: () => _del(w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                color: AppColors.soft,
                child: bytes != null
                    ? Image.memory(bytes,
                        fit: BoxFit.cover, gaplessPlayback: true)
                    : const Icon(Icons.image_not_supported_outlined,
                        color: Color(0xFFC4C4C8)),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(w.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: AppColors.ink)),
          Text(w.timeLabel,
              style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAB0))),
        ],
      ),
    );
  }
}

/// 兼容：给别处用的 base64 工具
String encodePng(List<int> bytes) => base64Encode(bytes);

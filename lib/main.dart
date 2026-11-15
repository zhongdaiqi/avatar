import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'platform/host.dart';
import 'pages/about_page.dart';
import 'pages/home_page.dart';
import 'pages/works_page.dart';
import 'widgets/recipe_view.dart';

const String _kPrivacyKey = 'privacy_agreed_v1';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 非 Web 平台先把原生持久层灌进内存，保证隐私协议标记在重启后仍然生效
  await initLocalStore();
  runApp(const AvatarApp());
}

class AvatarApp extends StatelessWidget {
  const AvatarApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.coral,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: Colors.white,
      splashFactory: InkSparkle.splashFactory,
    );
    return MaterialApp(
      title: '头像装修',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        textTheme: base.textTheme.apply(
          bodyColor: AppColors.ink,
          displayColor: AppColors.ink,
        ),
      ),
      home: const RootPage(),
    );
  }
}

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  int _index = 0;
  int _worksVersion = 0;
  late bool _agreed;

  @override
  void initState() {
    super.initState();
    _agreed = isWebHost || readLocal(_kPrivacyKey) == '1';
  }

  @override
  Widget build(BuildContext context) {
    if (!_agreed) {
      return _PrivacyGate(
        onAgree: () {
          writeLocal(_kPrivacyKey, '1');
          setState(() => _agreed = true);
        },
        onDecline: () => exitApp(),
      );
    }
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          const HomePage(),
          WorksPage(key: ValueKey('works-$_worksVersion')),
          const AboutPage(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) => setState(() {
            _index = i;
            if (i == 1) _worksVersion++;
          }),
          backgroundColor: Colors.white,
          elevation: 0,
          selectedItemColor: AppColors.coral,
          unselectedItemColor: AppColors.grey,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.grid_view_rounded), label: '模板'),
            BottomNavigationBarItem(
                icon: Icon(Icons.photo_library_outlined), label: '作品'),
            BottomNavigationBarItem(
                icon: Icon(Icons.info_outline_rounded), label: '关于'),
          ],
        ),
      ),
    );
  }
}

/// 隐私协议门控页：不同意前不展示任何功能页。
class _PrivacyGate extends StatelessWidget {
  const _PrivacyGate({required this.onAgree, required this.onDecline});

  final VoidCallback onAgree;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 32),
              const Text(
                '欢迎使用「头像装修」',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          '在使用本应用前，请您仔细阅读并理解以下内容：',
                          style: TextStyle(fontSize: 14, height: 1.6, color: AppColors.ink),
                        ),
                        SizedBox(height: 12),
                        Text(
                          '1. 您创作的作品、草稿与应用设置仅保存在您的设备本地，不会上传到服务器；\n'
                          '2. 您在编辑中选择的照片仅用于本机渲染生成头像图片，不会上传；\n'
                          '3. 使用「在线模板」功能时，应用会向 avatar.zuime.com 请求模板列表数据，该请求不包含您的个人信息与图片；\n'
                          '4. 导出的图片保存在您的相册或您指定的位置，由您自行管理；\n'
                          '5. 客服联系邮箱：info@zuime.com。\n'
                          '6. 您可以随时卸载应用以彻底删除所有本地数据。\n\n'
                          '点击「同意并继续」即表示您已阅读并同意上述内容，并授权应用在上述范围内处理相关信息。',
                          style: TextStyle(fontSize: 14, height: 1.7, color: AppColors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onDecline,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.grey,
                          side: const BorderSide(color: AppColors.line),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('不同意并退出',
                            style: TextStyle(fontSize: 15)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: FilledButton(
                        onPressed: onAgree,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.coral,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('同意并继续',
                            style: TextStyle(fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

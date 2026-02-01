import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const AuroraHomePage(),
    );
  }
}

class AuroraHomePage extends StatefulWidget {
  const AuroraHomePage({super.key});

  @override
  State<AuroraHomePage> createState() => _AuroraHomePageState();
}

class _AuroraHomePageState extends State<AuroraHomePage> with TickerProviderStateMixin {
  late AnimationController _controller;

  // 极光动画相关
  late Animation<Offset> _blob1Anim;
  late Animation<Offset> _blob2Anim;
  late Animation<Offset> _blob3Anim;

  List<_Star> _stars = [];

  // 侧边栏控件
  List<SidebarItem> _sidebarItems = [];

  // --- 页面控制逻辑 ---
  int _currentIndex = 0;

  // --- InAppWebView 控制器 ---
  InAppWebViewController? _webViewController;

  late List<AppItem> myApps;

  @override
  void initState() {
    super.initState();
    
    // 初始化动画 (保持原样)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat(reverse: true);

    _blob1Anim = Tween<Offset>(
      begin: const Offset(-100, 0),
      end: const Offset(100, 50),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine));

    _blob2Anim = Tween<Offset>(
      begin: const Offset(50, 0),
      end: const Offset(-50, 100),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOutQuad));

    _blob3Anim = Tween<Offset>(
      begin: const Offset(0, -50),
      end: const Offset(50, 50),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    final random = math.Random();
    _stars = List.generate(1000, (index) {
      return _Star(
        x: random.nextDouble() * 3000,
        y: random.nextDouble() * 2000,
        size: random.nextDouble() * 2 + 0.5,
        opacitySpeed: random.nextDouble() * 0.5 + 0.5,
      );
    });

    // 初始化 App 列表
    myApps = [
      _buildAppItem("bilibili", "assets/icons/bilibili.png", "https://www.bilibili.com/"),
      _buildAppItem("Pixiv", "assets/icons/pixiv.png", "https://www.pixiv.net/"),
    ];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // --- 层1: 动态光晕背景 ---
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Stack(
                  children: [
                    Positioned(
                      bottom: -100 + _blob1Anim.value.dy,
                      left: -100 + _blob1Anim.value.dx,
                      child: _buildBlurBlob(
                        color: const Color.fromRGBO(255, 152, 0, 0.6),
                        size: size.width * 0.8,
                      ),
                    ),
                    Positioned(
                      bottom: -50 + _blob2Anim.value.dy,
                      right: -100 + _blob2Anim.value.dx,
                      child: _buildBlurBlob(
                        color: const Color.fromRGBO(233, 30, 99, 0.5),
                        size: size.width * 0.9,
                      ),
                    ),
                    Positioned(
                      top: -100 + _blob3Anim.value.dy,
                      right: 0,
                      left: 0,
                      child: _buildBlurBlob(
                        color: const Color.fromRGBO(63, 81, 181, 0.5),
                        size: size.width * 1.0,
                      ),
                    ),
                    BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 80.0, sigmaY: 80.0),
                      child: Container(color: Colors.transparent),
                    ),
                  ],
                );
              },
            ),
          ),

          // --- 层2: 星空粒子 ---
          Positioned.fill(
            child: CustomPaint(
              painter: StarFieldPainter(_controller, _stars),
            ),
          ),

          // --- 层3: 页面布局 (Sidebar + IndexedStack) ---
          Row(
            children: [
              // 侧边栏
              SizedBox(
                width: 100,
                child: _buildGlassSidebar(),
              ),
              // 右侧内容区域
              Expanded(
                flex: 1,
                child: IndexedStack(
                  index: _currentIndex,
                  children: [
                    // Index 0: 主页 GridView
                    Container(
                      padding: const EdgeInsets.all(40),
                      child: GridView.builder(
                        padding: const EdgeInsets.all(24),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 100,
                          mainAxisSpacing: 20,
                          crossAxisSpacing: 20,
                          childAspectRatio: 0.8,
                        ),
                        itemCount: myApps.length,
                        itemBuilder: (context, index) {
                          return _buildGridItem(myApps[index]);
                        },
                      ),
                    ),
                    
                    for (var item in _sidebarItems) ... [
                      _buildWebPage(item.url, ValueKey(item.url))
                    ]
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBlurBlob({required Color color, required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }

  // 构建玻璃拟态侧边栏
  Widget _buildGlassSidebar() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          decoration: const BoxDecoration(
            color: Color.fromRGBO(255, 255, 255, 0.05),
            border: Border(
              right: BorderSide(
                color: Color.fromRGBO(255, 255, 255, 0.1), 
                width: 1
              ),
            ),
          ),
          child: SlidableAutoCloseBehavior(
            child: Column(
              children: [
                const SizedBox(height: 30),
                _buildMenuItem(SidebarItem(label: "主页", url: "", icon: Icons.home_filled), 0),

                for (int i = 0; i < _sidebarItems.length; i++) ...[
                  const SizedBox(height: 20),
                  _buildMenuItem(_sidebarItems[i], i + 1),
                ],
              ],
            ),
          )
        ),
      ),
    );
  }

  Widget _buildWebPage(String url, Key key) {
    return ClipRRect(
        key: key,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20), 
          bottomLeft: Radius.circular(20)
        ),
        child: InAppWebView(
          initialUrlRequest: URLRequest(
            url: WebUri(url)
          ),
          initialSettings: InAppWebViewSettings(
            transparentBackground: true,
            javaScriptEnabled: true,
          ),
          onWebViewCreated: (controller) {
            _webViewController = controller;
          },
        ),
      );
  }

  // 侧边栏菜单项封装
  Widget _buildMenuItem(SidebarItem item, int index) {
    return Slidable(
      // key 是必须的，用于标识列表中的项
      key: ValueKey(item.hashCode), 
      enabled: index != 0, 

      // 右侧滑出的面板（从右往左划）
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.5, // 侧滑区域占比
        children: [
          CustomSlidableAction(
            onPressed: (context) {
              // 这里执行关闭逻辑
              _handleClose(index - 1);
            },
            backgroundColor: Colors.transparent,
            child: const Icon(
              Icons.close,
              size: 20,
              color: Colors.white70,
            ),
          ),
        ],
      ),

      // 原有的内容部分
      child: Builder(
        builder: (context) {
          return InkWell(
            onTap: () {
              setState(() {
                _currentIndex = index;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 12),
              width: double.infinity,
              decoration: _currentIndex == index
                  ? const BoxDecoration(
                      border: Border(left: BorderSide(color: Colors.orangeAccent, width: 3)),
                      gradient: LinearGradient(
                        colors: [Color.fromRGBO(255, 255, 255, 0.1), Colors.transparent],
                      ),
                    )
                  : null,
              child: Center(
                child: _buildSidebarIcon(item.icon, _currentIndex == index),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGridItem(AppItem appItem) {
    return InkWell(
      onTap: appItem.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(255, 255, 255, 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: _buildIcon(appItem.icon),
          ),
          const SizedBox(height: 10),
          Text(
            appItem.name,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildIcon(dynamic iconSource) {
    const double iconSize = 40.0;
    
    return SizedBox(
      width: iconSize,
      height: iconSize,
      child: Center(
        child: () {
          if (iconSource is IconData) {
            return Icon(iconSource, size: iconSize, color: Colors.white);
          } 
          if (iconSource is String) {
            return Image.asset(
              iconSource, 
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.white),
            );
          }
          return const Icon(Icons.help_outline, color: Colors.white);
        }(),
      ),
    );
  }

  Widget _buildSidebarIcon(dynamic iconSource, bool isActive) {
    const double iconSize = 26.0;
    
    // 情况 A：如果是系统图标 IconData
    if (iconSource is IconData) {
      return Icon(
        iconSource,
        size: iconSize,
        color: isActive ? Colors.white : Colors.white54,
      );
    } 
    
    // 情况 B：如果是图片路径 String
    if (iconSource is String) {
      return Opacity(
        // 对于彩色图片，我们通常用透明度来表示“未激活”状态
        opacity: isActive ? 1.0 : 0.5, 
        child: Image.asset(
          iconSource,
          width: iconSize,
          height: iconSize,
          fit: BoxFit.contain,
          // 防止图片路径写错导致程序崩溃
          errorBuilder: (context, error, stackTrace) => 
              const Icon(Icons.broken_image, size: iconSize, color: Colors.white24),
        ),
      );
    }

    // 兜底：如果什么都不是
    return const SizedBox(width: iconSize, height: iconSize);
  }

  AppItem _buildAppItem(String name, dynamic icon, String url) {
    return AppItem(
        name: name, 
        icon: icon, // 你的图片路径
        onTap: () {
          bool isFinded = false;
          for (var item in _sidebarItems) {
            if (item.label == name) {
              isFinded = true;
              setState(() {
                _currentIndex = _sidebarItems.indexOf(item) + 1; // 切换显示层级
              });
              break;
            }
          }
          if (!isFinded) {
            setState(() {
              _sidebarItems.add(
                SidebarItem(
                  label: name, 
                  url: url, 
                  icon: icon,
                )
              );
              _currentIndex = _sidebarItems.length; // 切换显示层级
            });
          }
        }
      );
  }
  void _handleClose(int indexInSidebar) {
    setState(() {
      int targetStackIndex = indexInSidebar + 1; // 在 Stack 中的实际索引

      if (_currentIndex == targetStackIndex) {
        // 1. 如果关闭的是当前正在看的页面 -> 回到主页
        _currentIndex = 0;
      } else if (_currentIndex > targetStackIndex) {
        // 2. 如果关闭的是当前页面“左侧/上方”的页面 -> 索引减 1 保持指向原页面
        _currentIndex--;
      }

      // 3. 移除数据
      _sidebarItems.removeAt(indexInSidebar);
    });
  }
  
}

class StarFieldPainter extends CustomPainter {
  final Animation<double> animation;
  final List<_Star> stars;

  StarFieldPainter(this.animation, this.stars) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;

    for (var star in stars) {
      double opacity = (math.sin(animation.value * 2 * math.pi * star.opacitySpeed) + 1) / 2; 
      opacity = 0.1 + (opacity * 0.5);
      paint.color = Color.fromRGBO(255, 255, 255, opacity);
      canvas.drawCircle(Offset(star.x, star.y), star.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _Star {
  double x, y, size, opacitySpeed;
  _Star({required this.x, required this.y, required this.size, required this.opacitySpeed});
}

class AppItem {
  final String name;
  final dynamic icon;
  final VoidCallback onTap;

  AppItem({required this.name, required this.icon, required this.onTap});
}

class SidebarItem {
  final String label;
  final String url;
  final dynamic icon;

  SidebarItem({required this.label, required this.url, required this.icon});
}
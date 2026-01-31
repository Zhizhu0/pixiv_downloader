import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

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
  late List<_Star> _stars = [];

  // --- 页面控制逻辑 ---
  int _currentIndex = 0; // 0: 主页, 1: Bilibili
  bool _isBilibiliRunning = false; // 标记 Bilibili 是否已激活（显示侧边栏图标）
  bool _hasLoadedWebView = false;  // 标记是否已经加载过 WebView (懒加载)

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
      AppItem(
        name: "浏览器", 
        icon: Icons.language, 
        onTap: () => print("打开浏览器"),
      ),
      AppItem(
        name: "设置", 
        icon: Icons.settings, 
        onTap: () => print("进入设置页面"),
      ),
      AppItem(
        name: "bilibili", 
        icon: "assets/icons/image.png", // 你的图片路径
        onTap: () {
          setState(() {
            _isBilibiliRunning = true; // 激活侧边栏图标
            _hasLoadedWebView = true;  // 开始加载 WebView（如果之前没加载过）
            _currentIndex = 1;         // 切换显示层级
          });
        }
      ),
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
                    
                    _hasLoadedWebView 
                        ? ClipRRect(
                            // 给左边加个圆角，视觉效果更好
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(20), 
                              bottomLeft: Radius.circular(20)
                            ),
                            child: InAppWebView(
                              initialUrlRequest: URLRequest(
                                url: WebUri("https://www.bilibili.com")
                              ),
                              initialSettings: InAppWebViewSettings(
                                transparentBackground: true,
                                javaScriptEnabled: true,
                              ),
                              onWebViewCreated: (controller) {
                                _webViewController = controller;
                              },
                            ),
                          )
                        : Container(), // 没点击过的时候放个空容器
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
          child: Column(
            children: [
              const SizedBox(height: 30),
              
              // 主页按钮
              InkWell(
                onTap: () {
                  setState(() {
                    _currentIndex = 0; // 切换显示层级为 0 (主页)
                    // 注意：这里没有销毁 WebView，它只是被 Stack 隐藏了，后台还在运行
                  });
                },
                child: _buildMenuItem(Icons.home_filled, _currentIndex == 0),
              ),

              const SizedBox(height: 20),

              // Bilibili 运行状态图标 (只有运行过才显示)
              if (_isBilibiliRunning)
                InkWell(
                  onTap: () {
                    setState(() {
                      _currentIndex = 1; // 切换显示层级为 1 (WebView)
                    });
                  },
                  // 使用 live_tv 图标代表 Bilibili，大小和样式与主页图标完全一致
                  child: _buildMenuItem(Icons.live_tv, _currentIndex == 1),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // 侧边栏菜单项封装，确保样式统一
  Widget _buildMenuItem(IconData icon, bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 12),
      width: double.infinity, // 占满宽度以便点击
      decoration: isActive
          ? const BoxDecoration(
              border: Border(left: BorderSide(color: Colors.orangeAccent, width: 3)),
              gradient: LinearGradient(
                colors: [Color.fromRGBO(255, 255, 255, 0.1), Colors.transparent],
              ),
            )
          : null,
      child: Center(
        child: Icon(
          icon,
          color: isActive ? Colors.white : Colors.white54,
          size: 26, // 统一大小
        ),
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
}

// ... StarFieldPainter 和 _Star 类保持不变 ...
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
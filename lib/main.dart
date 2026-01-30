import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: PixivWebView(),
    );
  }
}

class PixivWebView extends StatelessWidget {
  // Pixiv 域名到 IP 的映射（建议定期更新或使用 DoH 获取）
  final Map<String, String> hostIpMap = {
    'www.pixiv.net': '210.140.139.158',
    'i.pximg.net': '210.140.139.131',
    's.pximg.net': '210.140.139.131',
    'accounts.pixiv.net': '210.140.139.158',
  };

  Future<WebResourceResponse?> handleSniBypass(WebResourceRequest request) async {
    final url = request.url.toString();
    final host = request.url.host;

    // 只拦截 Pixiv 相关的域名
    if (!hostIpMap.containsKey(host)) return null;

    try {
      final client = HttpClient();
      // 忽略 IP 访问时的证书错误
      client.badCertificateCallback = (cert, host, port) => true;

      // 将域名替换为 IP 发起请求
      final ip = hostIpMap[host]!;
      final proxyUri = Uri.parse(url.replaceFirst(host, ip));
      
      final httpClientRequest = await client.openUrl(request.method ?? 'GET', proxyUri);

      // 复制原始请求头，并确保 Host 正确
      request.headers?.forEach((key, value) {
        httpClientRequest.headers.set(key, value);
      });
      httpClientRequest.headers.set('Host', host);
      httpClientRequest.headers.set('Referer', 'https://www.pixiv.net/');

      final response = await httpClientRequest.close();

      // 读取数据
      final bytes = await response.fold<List<int>>([], (p, e) => p..addAll(e));

      // 将结果封装回 WebView 能理解的响应格式
      return WebResourceResponse(
        contentType: response.headers.contentType?.toString() ?? 'text/html',
        statusCode: response.statusCode,
        reasonPhrase: response.reasonPhrase,
        data: Uint8List.fromList(bytes),
        headers: response.headers.toUnmodifiableMap().map((k, v) => MapEntry(k, v.join(','))),
      );
    } catch (e) {
      print("拦截请求出错 ($host): $e");
      return null; // 出错则交还给系统处理
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(title: const Text("Pixiv SNI Bypass")),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri("https://www.pixiv.net")),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          // 允许在 HTTPS 页面中加载我们拦截返回的数据
          mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
          // 必须开启此项，拦截器才会生效
          useShouldInterceptRequest: true,
        ),
        // 核心拦截器逻辑
        shouldInterceptRequest: (controller, request) async {
          return await handleSniBypass(request);
        },
        onLoadError: (controller, url, code, message) {
          print("加载错误: $message ($code)");
        },
      ),
    );
  }
}

// 辅助扩展：将 HttpClient 的 Headers 转为 Map
extension HeadersExt on HttpHeaders {
  Map<String, List<String>> toUnmodifiableMap() {
    final map = <String, List<String>>{};
    forEach((name, values) {
      map[name] = values;
    });
    return map;
  }
}
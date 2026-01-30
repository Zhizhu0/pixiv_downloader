import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pixiv SNI Bypass Downloader',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const DownloadPage(),
    );
  }
}

class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key});

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  final TextEditingController _urlController = TextEditingController();
  final LocalProxyServer _proxyServer = LocalProxyServer();
  
  String _statusLog = "等待操作...";
  bool _isDownloading = false;
  String _localProxyUrlPrefix = "";

  @override
  void initState() {
    super.initState();
    // 1. 启动本地代理
    _startProxy();
  }

  Future<void> _startProxy() async {
    try {
      int port = await _proxyServer.start();
      setState(() {
        _localProxyUrlPrefix = "http://127.0.0.1:$port/proxy?url=";
        _statusLog = "本地代理已启动，监听端口: $port";
      });
    } catch (e) {
      setState(() {
        _statusLog = "代理启动失败: $e";
      });
    }
  }

  // 2. 核心下载逻辑
  Future<void> _downloadFile() async {
    if (_urlController.text.isEmpty) return;
    
    // 如果代理没启动成功，不执行
    if (_localProxyUrlPrefix.isEmpty) {
      setState(() => _statusLog = "错误：代理未启动");
      return;
    }

    setState(() {
      _isDownloading = true;
      _statusLog = "正在通过本地代理请求...";
    });

    final targetUrl = _urlController.text.trim();
    // 构建请求地址：http://127.0.0.1:随机端口/proxy?url=目标地址
    final proxyRequestUrl = "$_localProxyUrlPrefix${Uri.encodeComponent(targetUrl)}";

    final httpClient = HttpClient();
    
    try {
      // 连接本地代理
      final request = await httpClient.getUrl(Uri.parse(proxyRequestUrl));
      final response = await request.close();

      if (response.statusCode != 200) {
        throw Exception("HTTP Error: ${response.statusCode}");
      }

      // 获取保存路径
      final directory = await getApplicationDocumentsDirectory();
      // 简单地从 URL 提取文件名，实际情况可能需要解析 Content-Disposition
      String fileName = targetUrl.split('/').last.split('?').first;
      if (fileName.isEmpty) fileName = "downloaded_file";
      
      final filePath = "${directory.path}/$fileName";
      final file = File(filePath);

      // 流式写入文件
      final fileSink = file.openWrite();
      await response.pipe(fileSink);
      await fileSink.flush();
      await fileSink.close();

      setState(() {
        _statusLog = "下载成功！\n保存路径: $filePath";
      });
      
    } catch (e) {
      setState(() {
        _statusLog = "下载失败: $e";
      });
    } finally {
      httpClient.close();
      setState(() => _isDownloading = false);
    }
  }

  @override
  void dispose() {
    _proxyServer.stop();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pixiv SNI Bypass")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: "输入 Pixiv 图片链接",
                border: OutlineInputBorder(),
                hintText: "https://i.pximg.net/...",
              ),
            ),
            const SizedBox(height: 20),
            _isDownloading
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
                    onPressed: _downloadFile,
                    icon: const Icon(Icons.download),
                    label: const Text("通过代理下载"),
                  ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              color: Colors.grey[200],
              child: Text(_statusLog),
            ),
          ],
        ),
      ),
    );
  }
}

/// =========================================================
/// 核心类：本地代理服务器
/// 负责接收 App 的请求，并执行“绕过 SNI”的逻辑转发给目标服务器
/// =========================================================
class LocalProxyServer {
  HttpServer? _server;

  // Pixiv 的可用 IP 列表（实际使用中最好通过 DoH 动态获取，这里作为演示写死）
  static const Map<String, String> _hostMap = {
    'www.pixiv.net': '210.140.139.155',
    'i.pximg.net': '210.140.139.133', // 图片服务器
    's.pximg.net': '210.140.139.133',
  };

  /// 启动代理，返回监听的端口号
  Future<int> start() async {
    // 监听 loopbackIPv4，port: 0 表示让系统随机分配空闲端口
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    
    _server!.listen((HttpRequest request) {
      _handleRequest(request);
    });

    return _server!.port;
  }

  void stop() {
    _server?.close();
  }

  /// 处理进入代理的请求
  Future<void> _handleRequest(HttpRequest incomingRequest) async {
    final client = HttpClient();
    
    try {
      // 1. 解析目标 URL
      // 格式: /proxy?url=https://...
      String? urlStr = incomingRequest.uri.queryParameters['url'];
      
      if (urlStr == null || urlStr.isEmpty) {
        incomingRequest.response.statusCode = HttpStatus.badRequest;
        incomingRequest.response.write("Missing 'url' parameter");
        await incomingRequest.response.close();
        return;
      }

      Uri targetUri = Uri.parse(urlStr);
      String originalHost = targetUri.host;
      
      // 2. SNI 绕过核心逻辑：DNS 映射与 IP 替换
      String connectHost = originalHost;
      
      // 检查是否在我们的映射表中（如果是 pixiv 相关域名）
      if (_hostMap.containsKey(originalHost)) {
        connectHost = _hostMap[originalHost]!; // 使用 IP 地址
        // 这里 targetUri 里的 host 被替换成了 IP
        // 这样 HttpClient connect 时，SNI 字段发送的是 IP，而不是域名
        // 从而绕过防火墙对域名的 RST 阻断
        targetUri = targetUri.replace(host: connectHost);
      }

      // 3. 配置 HttpClient
      // 因为我们用 IP 连接 https，证书里的域名是 pixiv.net，而我们访问的是 IP，
      // 所以必须忽略证书校验错误
      client.badCertificateCallback = (X509Certificate cert, String host, int port) {
        return true; 
      };

      // 4. 发起请求
      final outgoingRequest = await client.openUrl(incomingRequest.method, targetUri);

      // 5. 关键：手动设置 Host 头
      // 虽然连接的是 IP，但告诉服务器我们要访问的是原域名
      outgoingRequest.headers.set('Host', originalHost);
      
      // 伪造 User-Agent 防止被反爬
      outgoingRequest.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
      
      // 必须加上 Referer，否则 Pixiv 图片服务器会返回 403 Forbidden
      outgoingRequest.headers.set('Referer', 'https://www.pixiv.net/');

      // 6. 等待响应
      final outgoingResponse = await outgoingRequest.close();

      // 7. 将响应转发回 App (WebView 或 下载器)
      incomingRequest.response.statusCode = outgoingResponse.statusCode;
      
      // 转发 Headers (除了几个特定的)
      outgoingResponse.headers.forEach((name, values) {
        if (name.toLowerCase() != 'transfer-encoding') { // 避免 chunked 冲突
           incomingRequest.response.headers.set(name, values);
        }
      });
      
      // 设置内容类型
      incomingRequest.response.headers.contentType = outgoingResponse.headers.contentType;

      // 8. 管道传输数据流 (Stream)
      await incomingRequest.response.addStream(outgoingResponse);
      await incomingRequest.response.close();

    } catch (e) {
      print("Proxy Error: $e");
      if(!isResponseClosed(incomingRequest.response)) {
         incomingRequest.response.statusCode = HttpStatus.internalServerError;
         incomingRequest.response.write("Proxy Error: $e");
         await incomingRequest.response.close();
      }
    } finally {
      client.close();
    }
  }
  
  bool isResponseClosed(HttpResponse response) {
    try {
      return response.connectionInfo == null; // 简易判断
    } catch(e) {
      return true;
    }
  }
}
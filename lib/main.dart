import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart'; // <-- Yeh package zaroori hai whatsapp kholne ke liye
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AmanSweetWebView(),
    );
  }
}

class AmanSweetWebView extends StatefulWidget {
  const AmanSweetWebView({super.key});

  @override
  State<AmanSweetWebView> createState() => _AmanSweetWebViewState();
}

class _AmanSweetWebViewState extends State<AmanSweetWebView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          // 👇 Yahan WhatsApp ya external links ko handle karne ka code hai 👇
          onNavigationRequest: (NavigationRequest request) async {
            if (request.url.startsWith('whatsapp://') || 
                request.url.contains('api.whatsapp.com')) {
              final Uri uri = Uri.parse(request.url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
              return NavigationDecision.prevent; // WebView mein khulne se rokein
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse('https://5aman.netlify.app/'));

    // Android par file/photo upload enable karne ke liye
    if (Platform.isAndroid) {
      final androidController = _controller.platform as AndroidWebViewController;
      androidController.setOnShowFileSelector((FileSelectorParams params) async {
        final ImagePicker picker = ImagePicker();
        final XFile? photo = await picker.pickImage(source: ImageSource.gallery);

        if (photo != null) {
          return [Uri.file(photo.path).toString()];
        }
        return [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: WebViewWidget(controller: _controller),
      ),
    );
  }
}

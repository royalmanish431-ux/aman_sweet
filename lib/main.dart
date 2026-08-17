import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MaterialApp(
    home: AmanSweetApp(),
    debugShowCheckedModeBanner: false,
  ));
}

class AmanSweetApp extends StatefulWidget {
  const AmanSweetApp({super.key});

  @override
  State<AmanSweetApp> createState() => _AmanSweetAppState();
}

class _AmanSweetAppState extends State<AmanSweetApp> {
  late final WebViewController controller;
  bool isOffline = false;
  bool isLoading = true;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  
  final String targetUrl = 'https://5aman.netlify.app/';

  @override
  void initState() {
    super.initState();
    _requestPermissions();

    final WebViewController webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFFFFFF))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              isLoading = false;
              if (url.startsWith('http')) {
                isOffline = false;
              }
            });
          },
          onWebResourceError: (WebResourceError error) {
            if (error.isForMainFrame ?? true) {
              setState(() {
                isOffline = true;
                isLoading = false;
              });
            }
          },
          onNavigationRequest: (NavigationRequest request) async {
            final String url = request.url;

            if (url.startsWith('whatsapp://') ||
                url.startsWith('intent://') ||
                url.startsWith('https://wa.me/') ||
                url.startsWith('https://api.whatsapp.com/') ||
                url.startsWith('tel:') ||
                url.startsWith('mailto:') ||
                url.startsWith('sms:')) {
              
              final Uri uri = Uri.parse(url);
              try {
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
                }
              } catch (e) {
                try {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } catch (_) {}
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );

    if (webController.platform is AndroidWebViewController) {
      (webController.platform as AndroidWebViewController)
          .setOnPlatformPermissionRequest((request) {
        request.grant();
      });
    }

    controller = webController;
    _checkInitialConnectivity();

    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final bool hasNoConnection = results.contains(ConnectivityResult.none);
      if (hasNoConnection) {
        setState(() {
          isOffline = true;
        });
      } else if (isOffline) {
        setState(() {
          isOffline = false;
        });
        controller.loadRequest(Uri.parse(targetUrl));
      }
    });
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.camera,
      Permission.photos,
      Permission.storage,
      Permission.microphone,
    ].request();
  }

  Future<void> _checkInitialConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    if (results.contains(ConnectivityResult.none)) {
      setState(() {
        isOffline = true;
      });
    } else {
      controller.loadRequest(Uri.parse(targetUrl));
    }
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(controller: controller),

            if (isLoading && !isOffline)
              Container(
                color: Colors.white,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.storefront_rounded, size: 80, color: Color(0xFFD97706)),
                      SizedBox(height: 16),
                      Text(
                        'Aman SweetApp',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFD97706),
                        ),
                      ),
                      SizedBox(height: 24),
                      CircularProgressIndicator(color: Color(0xFFD97706)),
                    ],
                  ),
                ),
              ),

            if (isOffline)
              Container(
                color: Colors.white,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off_rounded, size: 50, color: Colors.grey),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() => isOffline = false);
                          _checkInitialConnectivity();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

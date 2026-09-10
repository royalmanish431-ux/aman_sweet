import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
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
  
  // Selected image ka local path store karne ke liye
  String? _selectedImagePath;

  final String targetUrl = 'https://aman-restaurant.vercel.app/';

  @override
  void initState() {
    super.initState();
    _requestPermissions();

    final WebViewController webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFFFFFF))
      // JavaScript se Flutter ko call receive karne ke liye Channel
      ..addJavaScriptChannel(
        'FlutterShareChannel',
        onMessageReceived: (JavaScriptMessage message) async {
          final text = message.message;
          if (_selectedImagePath != null) {
            await Share.shareXFiles(
              [XFile(_selectedImagePath!)],
              text: text,
            );
          } else {
            await Share.share(text);
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) => setState(() => isLoading = true),
          onPageFinished: (String url) {
            setState(() {
              isLoading = false;
              if (url.startsWith('http')) isOffline = false;
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

            // Agar photo attach hai aur whatsapp link trigger hua, toh native share se bhejenge
            if (url.startsWith('whatsapp://') ||
                url.startsWith('https://wa.me/') ||
                url.contains('api.whatsapp.com')) {
              
              if (_selectedImagePath != null) {
                // URL se text nikal kar native share sheet open karega (image + text)
                final uri = Uri.parse(url);
                final text = uri.queryParameters['text'] ?? '';
                await Share.shareXFiles(
                  [XFile(_selectedImagePath!)],
                  text: text,
                );
                return NavigationDecision.prevent;
              }

              // Agar photo select nahi ki hai, toh normal whatsapp kholega
              final Uri uri = Uri.parse(url);
              try {
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
                }
              } catch (_) {}
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      );

    if (webController.platform is AndroidWebViewController) {
      final androidController = webController.platform as AndroidWebViewController;
      
      androidController.setOnPlatformPermissionRequest((request) {
        request.grant();
      });

      // Photo pick hone par path save karega
      androidController.setOnShowFileSelector((FileSelectorParams params) async {
        final ImagePicker picker = ImagePicker();
        final XFile? photo = await picker.pickImage(source: ImageSource.gallery);
        if (photo != null) {
          _selectedImagePath = photo.path;
          return [Uri.file(photo.path).toString()];
        }
        return [];
      });
    }

    controller = webController;
    _checkInitialConnectivity();

    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final bool hasNoConnection = results.contains(ConnectivityResult.none);
      if (hasNoConnection) {
        setState(() => isOffline = true);
      } else if (isOffline) {
        setState(() => isOffline = false);
        controller.loadRequest(Uri.parse(targetUrl));
      }
    });
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.camera,
      Permission.photos,
      Permission.storage,
    ].request();
  }

  Future<void> _checkInitialConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    if (results.contains(ConnectivityResult.none)) {
      setState(() => isOffline = true);
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
                child: const Center(
                  child: CircularProgressIndicator(color: Color(0xFFD97706)),
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

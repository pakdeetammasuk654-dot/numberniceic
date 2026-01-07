
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../utils/social_auth_config.dart';

class LineDirectLoginPage extends StatefulWidget {
  const LineDirectLoginPage({super.key});

  @override
  State<LineDirectLoginPage> createState() => _LineDirectLoginPageState();
}

class _LineDirectLoginPageState extends State<LineDirectLoginPage> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    
    // Manual URL Construction (The Safe Way)
    const String redirectUri = 'https://www.xn--b3cu8e7ah6h.com/auth/line/callback';
    final String encodedRedirectUri = Uri.encodeComponent(redirectUri);
    const String clientId = SocialAuthConfig.lineChannelId;
    const String state = '12345abcde';
    // Restore full scopes (URL Encoded space is + or %20)
    const String scope = 'profile+openid+email'; 
    
    final String fullUrl = 'https://access.line.me/oauth2/v2.1/authorize'
        '?response_type=code'
        '&client_id=$clientId'
        '&redirect_uri=$encodedRedirectUri'
        '&state=$state'
        '&scope=$scope'
        '&bot_prompt=normal';

    print('🔥 Loading FULL URL: $fullUrl'); 

    // Initialize WebView
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            print('WebView loading: $url');
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            print('WebView error: ${error.description}');
          },
          onNavigationRequest: (NavigationRequest request) {
            print('Navigating to: ${request.url}');
            
            // Intercept the HTTPS URL
            if (request.url.startsWith(redirectUri)) { 
              
              final uri = Uri.parse(request.url);
              final code = uri.queryParameters['code'];
              final error = uri.queryParameters['error'];
              
              if (code != null) {
                print('✅ Got Authorization Code: $code');
                Navigator.of(context).pop({'code': code}); 
                return NavigationDecision.prevent;
              }
              
              if (error != null) {
                print('❌ LINE Login Error: $error');
                Navigator.of(context).pop({'error': error}); 
                return NavigationDecision.prevent;
              }
            }
            
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(fullUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LINE Login', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 1,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF00B900)),
            ),
        ],
      ),
    );
  }
}

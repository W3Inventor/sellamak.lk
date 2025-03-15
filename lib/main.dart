import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Optional: enable debugging if you need to inspect the WebView.
  await InAppWebViewController.setWebContentsDebuggingEnabled(true);
  runApp(const MyApp());
}

// ---------------------------------------------------------------------------
// 1. MyApp
// ---------------------------------------------------------------------------
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Persistent Login WebView',
      theme: ThemeData.dark(),
      home: const SplashScreen(),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. SplashScreen
// ---------------------------------------------------------------------------
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _checkLoginState();
  }

  Future<void> _checkLoginState() async {
    // Simulate loading delay for splash screen
    await Future.delayed(const Duration(seconds: 3));
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isLoggedIn = prefs.getBool("isLoggedIn") ?? false;
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => WebViewScreen(isLoggedIn: isLoggedIn),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: RotationTransition(
          turns: _animationController,
          child: Image.asset("assets/icon/icon.png", width: 100, height: 100),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. WebViewScreen
// ---------------------------------------------------------------------------
class WebViewScreen extends StatefulWidget {
  final bool isLoggedIn;

  const WebViewScreen({super.key, required this.isLoggedIn});

  @override
  WebViewScreenState createState() => WebViewScreenState();
}

class WebViewScreenState extends State<WebViewScreen> {
  InAppWebViewController? webViewController;

  bool _isLoading = true;
  bool _isLoggedIn = false;
  // Flag to show the loading overlay only on the first load.
  bool _firstLoad = true;

  // Adjust these URLs to match your WooCommerce site.
  final String loginUrl = "https://sellamak.lk/login/";
  final String homeUrl = "https://sellamak.lk";

  @override
  void initState() {
    super.initState();
    _isLoggedIn = widget.isLoggedIn;
    // Load persisted cookies, then rebuild.
    _loadPersistedCookies().then((_) {
      setState(() {});
    });
  }

  // -------------------------------------------------------------------------
  // Save cookies (e.g. "woocommerce_logged_in") to SharedPreferences.
  // -------------------------------------------------------------------------
  Future<void> _saveCookies() async {
    List<dynamic> cookies = await CookieManager.instance().getCookies(
      url: WebUri("https://sellamak.lk"),
    );

    List<Map<String, dynamic>> cookieList =
        cookies.map((cookie) {
          // Access properties as dynamic to avoid private type exposure.
          return {
            "name": cookie.name,
            "value": cookie.value,
            "domain": cookie.domain,
            "path": cookie.path,
            "expires":
                (cookie.expiresDate != null)
                    ? DateTime.fromMillisecondsSinceEpoch(
                      cookie.expiresDate,
                    ).toIso8601String()
                    : "",
          };
        }).toList();

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString("cookies", jsonEncode(cookieList));
  }

  // -------------------------------------------------------------------------
  // Load cookies from SharedPreferences into the native cookie store.
  // -------------------------------------------------------------------------
  Future<void> _loadPersistedCookies() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? cookieString = prefs.getString("cookies");
    if (cookieString != null) {
      List<dynamic> cookieList = jsonDecode(cookieString);
      for (var cookieMap in cookieList) {
        if (cookieMap["expires"] != "") {
          await CookieManager.instance().setCookie(
            url: WebUri("https://sellamak.lk"),
            name: cookieMap["name"],
            value: cookieMap["value"],
            domain: cookieMap["domain"],
            path: cookieMap["path"],
            expiresDate:
                DateTime.parse(cookieMap["expires"]).millisecondsSinceEpoch,
          );
        } else {
          await CookieManager.instance().setCookie(
            url: WebUri("https://sellamak.lk"),
            name: cookieMap["name"],
            value: cookieMap["value"],
            domain: cookieMap["domain"],
            path: cookieMap["path"],
          );
        }
      }
    }
  }

  // -------------------------------------------------------------------------
  // Check if the WooCommerce login cookie is present.
  // -------------------------------------------------------------------------
  Future<void> _checkLogin() async {
    List<dynamic> cookies = await CookieManager.instance().getCookies(
      url: WebUri("https://sellamak.lk"),
    );

    bool loginFound = cookies.any(
      (cookie) =>
          cookie.name == "woocommerce_logged_in" &&
          (cookie.value as String).isNotEmpty,
    );

    if (loginFound) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.setBool("isLoggedIn", true);
      _isLoggedIn = true;
      // Persist cookies so we can reload them on next launch.
      await _saveCookies();

      // Redirect to the home page.
      if (webViewController != null) {
        webViewController!.loadUrl(
          urlRequest: URLRequest(
            url: WebUri(homeUrl),
            headers: {
              "User-Agent":
                  "Mozilla/5.0 (Linux; Android 9; SM-S908E; wv) AppleWebKit/537.36 "
                  "(KHTML, like Gecko) Version/4.0 Chrome/70.0.3538.80 Mobile Safari/537.36",
            },
          ),
        );
      }
    }
  }

  // -------------------------------------------------------------------------
  // Build the UI.
  // -------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(
              url: WebUri(_isLoggedIn ? homeUrl : loginUrl),
              headers: {
                "User-Agent":
                    "Mozilla/5.0 (Linux; Android 9; SM-S908E; wv) AppleWebKit/537.36 "
                    "(KHTML, like Gecko) Version/4.0 Chrome/70.0.3538.80 Mobile Safari/537.36",
              },
            ),
            onWebViewCreated: (controller) {
              webViewController = controller;
            },
            onLoadStart: (controller, url) {
              // Only show loading overlay on the first page load.
              if (_firstLoad) {
                setState(() {
                  _isLoading = true;
                });
              }
            },
            onLoadStop: (controller, url) async {
              // If this is the first load, hide the loading overlay and mark first load complete.
              if (_firstLoad) {
                setState(() {
                  _isLoading = false;
                  _firstLoad = false;
                });
              }
              // Optionally, hide elements not intended for in-app display.
              await controller.evaluateJavascript(
                source: '''
                if (navigator.userAgent.includes("wv")) {
                  document.querySelectorAll(".hide-in-app").forEach(function(el) {
                    el.style.display = "none";
                  });
                }
              ''',
              );

              // Check for login success on the login page.
              if (url != null && url.toString().contains("/login/")) {
                Future.delayed(const Duration(seconds: 2), _checkLogin);
              }
            },
          ),

          // Loading indicator shown only on the first load.
          if (_isLoading)
            Container(
              color: const Color(0xFF015DB9),
              child: Center(
                child: Image.asset(
                  "assets/icon/icon.png",
                  width: 100,
                  height: 100,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

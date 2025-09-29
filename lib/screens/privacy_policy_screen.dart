import 'dart:io' show InternetAddress, SocketException;

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  static const _remoteUrl = 'https://privacytouchnotebook.netlify.app/';
  static const _localAssetPath = 'assets/policies/privacy_policy.html';

  late final WebViewController _controller;
  double _progress = 0;
  bool _hasError = false;
  String? _errorDescription;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (!mounted) {
              return;
            }
            setState(() {
              _progress = progress / 100;
            });
          },
          onWebResourceError: (error) {
            if (!mounted) {
              return;
            }
            setState(() {
              _hasError = true;
              _errorDescription = error.description;
              _progress = 1;
            });
            _controller.loadFlutterAsset(_localAssetPath);
          },
        ),
      );

    _loadInitialContent();
  }

  Future<void> _loadInitialContent() async {
    await _controller.loadFlutterAsset(_localAssetPath);
    if (!mounted) {
      return;
    }
    setState(() {
      _progress = 1;
    });
    await _loadRemoteContent();
  }

  Future<void> _loadRemoteContent() async {
    setState(() {
      _hasError = false;
      _errorDescription = null;
      _progress = 0;
    });

    final hasConnection = await _hasNetworkConnection();
    if (!mounted) {
      return;
    }

    if (!hasConnection) {
      setState(() {
        _hasError = true;
        _errorDescription =
            'Не удалось подключиться к интернету. Отображается офлайн-версия.';
        _progress = 1;
      });
      return;
    }

    await _controller.loadRequest(Uri.parse(_remoteUrl));
  }

  Future<bool> _hasNetworkConnection() async {
    try {
      final result = await InternetAddress.lookup('example.com');
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    }
  }

  Future<void> _retryLoadRemote() async {
    await _loadRemoteContent();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Политика конфиденциальности')),
      body: Column(
        children: [
          if (_progress < 1)
            LinearProgressIndicator(
              value: _progress,
            ),
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_hasError)
                  Positioned.fill(
                    child: Container(
                      color: Theme.of(context).colorScheme.background.withOpacity(0.95),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.wifi_off, size: 48),
                            const SizedBox(height: 16),
                            Text(
                              _errorDescription ??
                                  'Не удалось загрузить онлайн-версию документа.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: _retryLoadRemote,
                              child: const Text('Повторить'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

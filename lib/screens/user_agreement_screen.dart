import 'dart:io' show InternetAddress, SocketException;

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class UserAgreementScreen extends StatefulWidget {
  const UserAgreementScreen({super.key});

  @override
  State<UserAgreementScreen> createState() => _UserAgreementScreenState();
}

class _UserAgreementScreenState extends State<UserAgreementScreen> {
  static const _remoteUrl = 'https://eulatouchnotebook.netlify.app/';
  static const _localAssetPath = 'assets/policies/user_agreement.html';

  late final WebViewController _controller;
  double _progress = 0;
  bool _hasError = false;
  String? _errorDescription;
  String? _statusMessage;

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
              _statusMessage = null;
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
      _statusMessage = null;
    });

    final hasConnection = await _hasNetworkConnection();
    if (!mounted) {
      return;
    }

    if (!hasConnection) {
      setState(() {
        _statusMessage =
            'Не удалось подключиться к интернету. Показана офлайн-версия документа.';
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

  void _dismissStatusMessage() {
    if (!mounted) {
      return;
    }
    setState(() {
      _statusMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Пользовательское соглашение')),
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
                if (_statusMessage != null)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 24,
                    child: SafeArea(
                      child: Material(
                        elevation: 2,
                        borderRadius: BorderRadius.circular(12),
                        color: Theme.of(context).colorScheme.surface,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.info_outline, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _statusMessage!,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                              IconButton(
                                onPressed: _dismissStatusMessage,
                                icon: const Icon(Icons.close),
                                tooltip: 'Закрыть уведомление',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
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

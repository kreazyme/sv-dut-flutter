import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class NewsDetailPage extends StatefulWidget {
  const NewsDetailPage({super.key, required this.url});

  final String url;

  @override
  State<NewsDetailPage> createState() => _NewsDetailPageState();
}

class _NewsDetailPageState extends State<NewsDetailPage> {
  final ValueNotifier<double> _progress = ValueNotifier(0);

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('News Detail')),
      body: Column(
        children: [
          ValueListenableBuilder<double>(
            valueListenable: _progress,
            builder: (context, value, _) {
              if (value >= 1) {
                return const SizedBox.shrink();
              }
              return LinearProgressIndicator(value: value);
            },
          ),
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(widget.url)),
              initialSettings: InAppWebViewSettings(javaScriptEnabled: true),
              onProgressChanged: (_, progress) {
                _progress.value = progress / 100;
              },
              onReceivedError: (_, __, error) {
                log('Detail webview error', error: error);
              },
            ),
          ),
        ],
      ),
    );
  }
}

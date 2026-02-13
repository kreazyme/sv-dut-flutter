import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:go_router/go_router.dart';

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  static const _baseUrl = 'https://sv.dut.udn.vn/Default.aspx';

  final ValueNotifier<List<NewsItem>> _items = ValueNotifier(<NewsItem>[]);
  final ValueNotifier<bool> _isLoading = ValueNotifier(true);
  final ValueNotifier<String?> _errorMessage = ValueNotifier(null);
  InAppWebViewController? _webViewController;

  @override
  void dispose() {
    _items.dispose();
    _isLoading.dispose();
    _errorMessage.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    _errorMessage.value = null;
    _isLoading.value = true;
    final controller = _webViewController;
    if (controller == null) {
      return;
    }
    await controller.loadUrl(urlRequest: URLRequest(url: WebUri(_baseUrl)));
  }

  Future<void> _injectAndParse(InAppWebViewController controller) async {
    try {
      await controller.evaluateJavascript(source: _newsExtractionScript);
    } catch (error, stackTrace) {
      log('Failed to inject JS', error: error, stackTrace: stackTrace);
      _errorMessage.value = 'Unable to load news content.';
      _isLoading.value = false;
    }
  }

  void _handleNewsPayload(dynamic payload) {
    if (payload is! Map) {
      _errorMessage.value = 'Unexpected data from the website.';
      _isLoading.value = false;
      return;
    }

    final rawItems = payload['items'];
    if (rawItems is! List) {
      _errorMessage.value = 'No news items found.';
      _isLoading.value = false;
      return;
    }

    final items = <NewsItem>[];
    for (final entry in rawItems) {
      if (entry is Map) {
        final item = NewsItem.fromMap(entry);
        if (item != null) {
          items.add(item);
        }
      }
    }

    if (items.isEmpty) {
      _errorMessage.value = 'No news items found.';
    } else {
      _errorMessage.value = null;
    }
    _items.value = items;
    _isLoading.value = false;
  }

  void _openItem(BuildContext context, NewsItem item) {
    final encodedUrl = Uri.encodeComponent(item.url);
    context.push('/detail?url=$encodedUrl');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DUT Student News'),
        actions: [
          IconButton(
            tooltip: 'Reload news',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: _NewsContent(
              items: _items,
              isLoading: _isLoading,
              errorMessage: _errorMessage,
              onTap: _openItem,
              onRefresh: _reload,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SizedBox(
              height: 1,
              child: Opacity(
                opacity: 0,
                child: IgnorePointer(
                  child: InAppWebView(
                    initialUrlRequest: URLRequest(url: WebUri(_baseUrl)),
                    initialSettings: InAppWebViewSettings(
                      javaScriptEnabled: true,
                      transparentBackground: true,
                      disableContextMenu: true,
                    ),
                    onWebViewCreated: (controller) {
                      _webViewController = controller;
                      controller.addJavaScriptHandler(
                        handlerName: 'news',
                        callback: (args) {
                          if (args.isNotEmpty) {
                            _handleNewsPayload(args.first);
                          } else {
                            _handleNewsPayload(null);
                          }
                        },
                      );
                    },
                    onLoadStop: (controller, _) async {
                      await _injectAndParse(controller);
                    },
                    onReceivedError: (_, __, error) {
                      log('WebView error', error: error);
                      _errorMessage.value = 'Unable to load news content.';
                      _isLoading.value = false;
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewsContent extends StatelessWidget {
  const _NewsContent({
    required ValueNotifier<List<NewsItem>> items,
    required ValueNotifier<bool> isLoading,
    required ValueNotifier<String?> errorMessage,
    required this.onTap,
    required this.onRefresh,
  }) : _items = items,
       _isLoading = isLoading,
       _errorMessage = errorMessage;

  final ValueNotifier<List<NewsItem>> _items;
  final ValueNotifier<bool> _isLoading;
  final ValueNotifier<String?> _errorMessage;
  final void Function(BuildContext context, NewsItem item) onTap;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isLoading,
      builder: (context, loading, _) {
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: ValueListenableBuilder<String?>(
                  valueListenable: _errorMessage,
                  builder: (context, error, _) {
                    if (error == null) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: _InfoCard(
                        title: 'Unable to load news',
                        subtitle: error,
                        icon: Icons.warning_amber_rounded,
                      ),
                    );
                  },
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: _HeaderRow(loading: loading),
                ),
              ),
              ValueListenableBuilder<List<NewsItem>>(
                valueListenable: _items,
                builder: (context, items, _) {
                  if (items.isEmpty && loading) {
                    return const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (items.isEmpty) {
                    return const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _InfoCard(
                        title: 'No news yet',
                        subtitle: 'Pull down to refresh or try again later.',
                        icon: Icons.newspaper,
                      ),
                    );
                  }

                  final itemCount = items.length * 2 - 1;
                  return SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      if (index.isOdd) {
                        return const SizedBox(height: 12);
                      }
                      final item = items[index ~/ 2];
                      return _NewsTile(
                        item: item,
                        onTap: () => onTap(context, item),
                      );
                    }, childCount: itemCount),
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        );
      },
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            'Latest updates from DUT',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (loading)
          const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
  }
}

class _NewsTile extends StatelessWidget {
  const _NewsTile({required this.item, required this.onTap});

  final NewsItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.date != null && item.date?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_month,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          item.date ?? '',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                Text(
                  item.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.content != null && item.content?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      item.content ?? '',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NewsItem {
  const NewsItem({
    required this.title,
    required this.url,
    this.content,
    this.date,
  });

  final String title;
  final String url;
  final String? content;
  final String? date;

  static NewsItem? fromMap(Map<dynamic, dynamic> map) {
    final title = map['title'];
    final url = map['url'];
    if (title is! String || url is! String) {
      return null;
    }
    final content = map['content'] ?? map['summary'];
    final date = map['date'];
    return NewsItem(
      title: title.trim(),
      url: url.trim(),
      content: content is String ? content.trim() : null,
      date: date is String ? date.trim() : null,
    );
  }
}

const String _newsExtractionScript = r'''
(() => {
  const sanitize = (value) => (value || '').replace(/\s+/g, ' ').trim();
  const dateRegex = /\b\d{1,2}\/\d{1,2}\/\d{4}\b/;
  const anchors = Array.from(document.querySelectorAll('a'));
  const items = [];
  const seen = new Set();

  anchors.forEach((anchor) => {
    if (!anchor || !anchor.href) {
      return;
    }
    const title = sanitize(anchor.textContent);
    if (!title || title.length < 6) {
      return;
    }
    const href = anchor.href;
    if (!href.includes('sv.dut.udn.vn')) {
      return;
    }
    const key = `${title}|${href}`;
    if (seen.has(key)) {
      return;
    }
    seen.add(key);

    let date = '';
    let content = '';
    const container = anchor.closest('li, tr, div');
    if (container) {
      const dateEl = container.querySelector('.date, .time, .news-date, .datetime');
      if (dateEl) {
        date = sanitize(dateEl.textContent);
      }
      const contentEl = container.querySelector('.sapo, .summary, .news-summary, .content, p, ul');
      if (contentEl) {
        content = sanitize(contentEl.textContent);
      }
      const containerText = sanitize(container.textContent);
      if (!date) {
        const match = containerText.match(dateRegex);
        if (match) {
          date = match[0];
        }
      }
      if (!content) {
        content = containerText
          .replace(title, '')
          .replace(date, '')
          .replace(/^[:\-\s]+/, '')
          .trim();
      }
    }

    items.push({
      title,
      url: href,
      date,
      content,
    });
  });

  window.flutter_inappwebview.callHandler('news', {
    items,
    sourceUrl: window.location.href,
  });
})();
''';

// lib/presentation/screens/home/category_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../widgets/common.dart';
import '../../widgets/service_card.dart';
import '../cart/cart_bar.dart';

class CategoryScreen extends StatefulWidget {
  final int? categoryId;
  final String title;
  final bool searchMode;

  const CategoryScreen({
    super.key,
    required this.categoryId,
    required this.title,
  }) : searchMode = false;

  const CategoryScreen.search({super.key})
      : categoryId = null,
        title = 'Search',
        searchMode = true;

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final _repo = CatalogRepository.instance;
  final _search = TextEditingController();

  List<Service> _services = [];
  bool _loading = true;
  String? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.services(
        categoryId: widget.categoryId,
        search: _search.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _services = list;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: widget.searchMode ? null : Text(widget.title),
        titleSpacing: widget.searchMode ? 0 : null,
        flexibleSpace: widget.searchMode ? null : null,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _search,
              autofocus: widget.searchMode,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(
                hintText: widget.searchMode
                    ? 'AC service, fridge repair, gas refill…'
                    : 'Search in ${widget.title}',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 19),
                        onPressed: () {
                          _search.clear();
                          _load();
                        },
                      ),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),
        ),
      ),
      body: _body(),
      bottomNavigationBar: const CartBar(),
    );
  }

  Widget _body() {
    if (_loading) {
      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) => const Shim(height: 108, radius: 14),
      );
    }

    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _load);
    }

    if (_services.isEmpty) {
      return EmptyState(
        icon: _search.text.isEmpty
            ? Icons.handyman_rounded
            : Icons.search_off_rounded,
        title: _search.text.isEmpty
            ? 'Nothing here yet'
            : 'No match for "${_search.text.trim()}"',
        message: _search.text.isEmpty
            ? 'Services in this category will show up here.'
            : 'Try a shorter word, like "gas" or "repair".',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _services.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          if (i == _services.length) {
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${_services.length} ${_services.length == 1 ? 'service' : 'services'}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12.5, color: AppTheme.muted),
              ),
            );
          }
          return ServiceCard(service: _services[i]);
        },
      ),
    );
  }
}

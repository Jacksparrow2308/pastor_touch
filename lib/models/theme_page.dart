import 'package:flutter/material.dart';
import '../models/app_theme_model.dart';
import '../models/theme_manager.dart';

class ThemePage extends StatefulWidget {
  const ThemePage({super.key});

  @override
  State<ThemePage> createState() => _ThemePageState();
}

class _ThemePageState extends State<ThemePage> {
  final _manager = ThemeManager();
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = _manager.activeTheme?.id;
    _manager.addListener(_onThemeChanged);

    // Refresh on every open so newly uploaded backend themes appear
    // without requiring a full app restart.
    _manager.refresh();
  }

  @override
  void dispose() {
    _manager.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() => _selectedId = _manager.activeTheme?.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Choose Theme'), elevation: 0),
      body: _manager.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _manager.error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    'Failed to load themes',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _manager.error!,
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _manager.refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _manager.allThemes.isEmpty
          ? const Center(child: Text('No themes found'))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
              itemCount: _manager.allThemes.length,
              itemBuilder: (context, index) {
                final theme = _manager.allThemes[index];
                final isSelected = theme.id == _selectedId;
                return _ThemeCard(
                  theme: theme,
                  isSelected: isSelected,
                  onTap: () => _manager.selectTheme(theme),
                );
              },
            ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final AppThemeModel theme;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.theme,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? primary : Colors.transparent,
            width: 3,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.35),
                    blurRadius: 14,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Theme preview image
              if (theme.imageUrl.isEmpty)
                ColoredBox(color: theme.colors.background)
              else
                Image.network(
                  theme.imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : ColoredBox(
                          color: theme.colors.background,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                  errorBuilder: (_, error, stackTrace) => ColoredBox(
                    color: theme.colors.background,
                    child: const Icon(
                      Icons.broken_image,
                      color: Colors.white54,
                    ),
                  ),
                ),

              // Bottom gradient + name
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 24, 10, 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.75),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Text(
                    theme.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),

              // Selected checkmark badge
              if (isSelected)
                Positioned(
                  top: 8,
                  right: 8,
                  child: CircleAvatar(
                    radius: 13,
                    backgroundColor: primary,
                    child: const Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

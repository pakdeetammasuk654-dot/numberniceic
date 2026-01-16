import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class ThemeToggleButton extends StatelessWidget {
  final bool showLabel;
  final double iconSize;

  const ThemeToggleButton({
    Key? key,
    this.showLabel = true,
    this.iconSize = 24,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    if (showLabel) {
      return _buildWithLabel(context, themeProvider, isDark);
    } else {
      return _buildIconOnly(context, themeProvider, isDark);
    }
  }

  Widget _buildWithLabel(BuildContext context, ThemeProvider themeProvider, bool isDark) {
    return InkWell(
      onTap: () => themeProvider.toggleTheme(),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).dividerColor.withOpacity(0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return RotationTransition(
                  turns: animation,
                  child: FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                );
              },
              child: Icon(
                isDark ? Icons.dark_mode : Icons.light_mode,
                key: ValueKey(isDark),
                color: isDark ? Colors.amber : Colors.orange,
                size: iconSize,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              isDark ? 'โหมดมืด' : 'โหมดสว่าง',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconOnly(BuildContext context, ThemeProvider themeProvider, bool isDark) {
    return IconButton(
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) {
          return RotationTransition(
            turns: animation,
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
        child: Icon(
          isDark ? Icons.dark_mode : Icons.light_mode,
          key: ValueKey(isDark),
          color: isDark ? Colors.amber : Colors.orange,
          size: iconSize,
        ),
      ),
      onPressed: () => themeProvider.toggleTheme(),
      tooltip: isDark ? 'เปลี่ยนเป็นโหมดสว่าง' : 'เปลี่ยนเป็นโหมดมืด',
    );
  }
}

// Widget แบบ Switch สำหรับใช้ใน Settings
class ThemeToggleSwitch extends StatelessWidget {
  const ThemeToggleSwitch({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return ListTile(
      leading: Icon(
        isDark ? Icons.dark_mode : Icons.light_mode,
        color: isDark ? Colors.amber : Colors.orange,
      ),
      title: const Text('โหมดมืด'),
      subtitle: Text(isDark ? 'เปิดใช้งาน' : 'ปิดใช้งาน'),
      trailing: Switch(
        value: isDark,
        onChanged: (value) => themeProvider.toggleTheme(),
        activeColor: Colors.teal,
      ),
    );
  }
}

import 'package:flutter/material.dart';

class AppSheetItem<T> {
  final T value;
  final String title;
  final String? subtitle;
  final Widget? leading;

  const AppSheetItem({
    required this.value,
    required this.title,
    this.subtitle,
    this.leading,
  });
}

class AppDeviceDetailsResult {
  final String name;
  final String category;
  final String notes;

  const AppDeviceDetailsResult({
    required this.name,
    required this.category,
    required this.notes,
  });
}

class AppMultiSelectItem {
  final String id;
  final String title;
  final String? subtitle;
  final Widget? leading;

  const AppMultiSelectItem({
    required this.id,
    required this.title,
    this.subtitle,
    this.leading,
  });
}

Widget _dialogHeader(
  BuildContext context, {
  required IconData icon,
  required String title,
  String? subtitle,
  bool destructive = false,
}) {
  final t = Theme.of(context);
  final cs = t.colorScheme;
  final tone = destructive ? cs.error : cs.primary;

  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: tone),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: t.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: t.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

Future<T?> showAppSelectionBottomSheet<T>({
  required BuildContext context,
  required String title,
  String? subtitle,
  required List<AppSheetItem<T>> items,
}) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;

  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final t = Theme.of(ctx);
      final colors = t.colorScheme;

      return SafeArea(
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          itemCount: items.length + 1 + (subtitle == null ? 0 : 1),
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            var i = index;
            if (i == 0) {
              return Text(title, style: t.textTheme.titleMedium);
            }
            i -= 1;

            if (subtitle != null) {
              if (i == 0) {
                return Text(
                  subtitle,
                  style: t.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                );
              }
              i -= 1;
            }

            final item = items[i];
            return Material(
              color: colors.surface,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => Navigator.pop(ctx, item.value),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colors.outlineVariant.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (item.leading != null) ...[
                        item.leading!,
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: t.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (item.subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                item.subtitle!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: t.textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
  );
}

Future<Set<String>?> showAppMultiSelectBottomSheet({
  required BuildContext context,
  required String title,
  String? subtitle,
  required List<AppMultiSelectItem> items,
  Set<String>? initialSelected,
  required String confirmText,
}) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;

  return showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final t = Theme.of(ctx);
      final colors = t.colorScheme;
      final selected = <String>{...?(initialSelected)};

      return StatefulBuilder(
        builder: (ctx, setState) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: t.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: t.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final isSelected = selected.contains(item.id);
                        return Material(
                          color: colors.surface,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  selected.remove(item.id);
                                } else {
                                  selected.add(item.id);
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? colors.primary.withValues(alpha: 0.55)
                                      : colors.outlineVariant.withValues(
                                          alpha: 0.6,
                                        ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  if (item.leading != null) ...[
                                    item.leading!,
                                    const SizedBox(width: 12),
                                  ],
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.title,
                                          style: t.textTheme.titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        if (item.subtitle != null) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            item.subtitle!,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: t.textTheme.bodySmall
                                                ?.copyWith(
                                                  color:
                                                      colors.onSurfaceVariant,
                                                ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Checkbox.adaptive(
                                    value: isSelected,
                                    onChanged: (_) {
                                      setState(() {
                                        if (isSelected) {
                                          selected.remove(item.id);
                                        } else {
                                          selected.add(item.id);
                                        }
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: selected.isEmpty
                              ? null
                              : () => Navigator.pop(ctx, selected),
                          child: Text(confirmText),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Future<String?> showAppTextInputDialog({
  required BuildContext context,
  required String title,
  required String confirmText,
  String? initialValue,
  String? hintText,
  String? fieldLabel,
  String? helperText,
  IconData icon = Icons.edit_outlined,
  int maxLines = 1,
  TextInputType? keyboardType,
}) {
  final controller = TextEditingController(text: initialValue ?? '');
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      final t = Theme.of(ctx);

      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dialogHeader(
                ctx,
                icon: icon,
                title: title,
                subtitle: helperText,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                maxLines: maxLines,
                keyboardType: keyboardType,
                decoration: InputDecoration(
                  labelText: fieldLabel,
                  hintText: hintText,
                ),
                autofocus: true,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.pop(ctx, controller.text.trim()),
                      child: Text(confirmText),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<Map<String, int>?> showAppTwoNumberDialog({
  required BuildContext context,
  required String title,
  required String firstLabel,
  required String secondLabel,
  required int initialFirst,
  required int initialSecond,
  required String confirmText,
}) {
  final firstController = TextEditingController(text: initialFirst.toString());
  final secondController = TextEditingController(
    text: initialSecond.toString(),
  );

  return showDialog<Map<String, int>>(
    context: context,
    builder: (ctx) {
      final t = Theme.of(ctx);

      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dialogHeader(ctx, icon: Icons.grid_view_outlined, title: title),
              const SizedBox(height: 14),
              TextField(
                controller: firstController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: firstLabel),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: secondController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: secondLabel),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final first = int.tryParse(firstController.text.trim());
                        final second = int.tryParse(
                          secondController.text.trim(),
                        );
                        if (first == null ||
                            second == null ||
                            first <= 0 ||
                            second <= 0) {
                          Navigator.pop(ctx);
                          return;
                        }
                        Navigator.pop(ctx, {'first': first, 'second': second});
                      },
                      child: Text(confirmText),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<bool?> showAppConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmText,
  bool destructive = false,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) {
      final t = Theme.of(ctx);
      final cs = t.colorScheme;

      final confirmStyle = destructive
          ? ElevatedButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
            )
          : null;

      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dialogHeader(
                ctx,
                icon: destructive ? Icons.delete_outline : Icons.help_outline,
                title: title,
                destructive: destructive,
              ),
              const SizedBox(height: 12),
              Text(message, style: t.textTheme.bodyMedium),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: confirmStyle,
                      child: Text(confirmText),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<AppDeviceDetailsResult?> showAppDeviceDetailsDialog({
  required BuildContext context,
  required String title,
  required String confirmText,
  required String initialName,
  required String initialCategory,
  required String initialNotes,
}) {
  final nameController = TextEditingController(text: initialName);
  final categoryController = TextEditingController(text: initialCategory);
  final notesController = TextEditingController(text: initialNotes);

  return showDialog<AppDeviceDetailsResult>(
    context: context,
    builder: (ctx) {
      final t = Theme.of(ctx);
      final cs = t.colorScheme;

      String? nameError;
      String? categoryError;

      void validate() {
        final name = nameController.text.trim();
        final category = categoryController.text.trim();
        nameError = name.isEmpty ? 'Required' : null;
        categoryError = category.isEmpty ? 'Required' : null;
      }

      return StatefulBuilder(
        builder: (ctx, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _dialogHeader(
                    ctx,
                    icon: Icons.settings_outlined,
                    title: title,
                    subtitle: 'Update device information.',
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Device name',
                      errorText: nameError,
                    ),
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) => setState(validate),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: categoryController,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      errorText: categoryError,
                    ),
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) => setState(validate),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notesController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Notes',
                      hintText: 'Maintenance info, serial number, etc.',
                      helperText: 'Optional',
                      helperStyle: t.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(validate);
                            if (nameError != null || categoryError != null) {
                              return;
                            }
                            Navigator.pop(
                              ctx,
                              AppDeviceDetailsResult(
                                name: nameController.text.trim(),
                                category: categoryController.text.trim(),
                                notes: notesController.text.trim(),
                              ),
                            );
                          },
                          child: Text(confirmText),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

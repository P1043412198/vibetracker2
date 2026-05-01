import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/category.dart';
import '../models/transaction.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/formatters.dart';

class AddTransactionScreen extends StatefulWidget {
  final AppState state;
  final TxRecord? edit;
  final bool? presetExpense;

  const AddTransactionScreen({
    super.key,
    required this.state,
    this.edit,
    this.presetExpense,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  late TxType _type;
  late String _categoryId;
  late TextEditingController _amountCtrl;
  late TextEditingController _storeCtrl;
  late TextEditingController _commentCtrl;
  late DateTime _date;
  String _account = 'Картой';

  @override
  void initState() {
    super.initState();
    final edit = widget.edit;
    if (edit != null) {
      _type = edit.type;
      _categoryId = edit.categoryId;
      _amountCtrl =
          TextEditingController(text: edit.amount.toStringAsFixed(0));
      _storeCtrl = TextEditingController(text: edit.store ?? '');
      _commentCtrl = TextEditingController(text: edit.comment ?? '');
      _date = edit.date;
      _account = edit.account ?? 'Картой';
    } else {
      _type = (widget.presetExpense ?? true) ? TxType.expense : TxType.income;
      _categoryId = _categoriesForType().first.id;
      _amountCtrl = TextEditingController();
      _storeCtrl = TextEditingController();
      _commentCtrl = TextEditingController();
      _date = DateTime.now();
    }
  }

  List<TxCategory> _categoriesForType() => _type == TxType.expense
      ? DefaultCategories.expenses
      : DefaultCategories.incomes;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _storeCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final cleaned = _amountCtrl.text
        .replaceAll(RegExp(r'[^0-9.,]'), '')
        .replaceAll(',', '.');
    final amount = double.tryParse(cleaned) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введи сумму больше нуля')),
      );
      return;
    }

    if (widget.edit != null) {
      await widget.state.updateTransaction(
        widget.edit!.copyWith(
          type: _type,
          amount: amount,
          categoryId: _categoryId,
          date: _date,
          account: _account,
          store: _storeCtrl.text.trim().isEmpty ? null : _storeCtrl.text.trim(),
          comment: _commentCtrl.text.trim().isEmpty
              ? null
              : _commentCtrl.text.trim(),
        ),
      );
    } else {
      await widget.state.addTransaction(
        type: _type,
        amount: amount,
        categoryId: _categoryId,
        date: _date,
        account: _account,
        store: _storeCtrl.text.trim().isEmpty ? null : _storeCtrl.text.trim(),
        comment: _commentCtrl.text.trim().isEmpty
            ? null
            : _commentCtrl.text.trim(),
      );
    }
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _pickDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('ru'),
    );
    if (result != null) {
      setState(() => _date = DateTime(
            result.year,
            result.month,
            result.day,
            _date.hour,
            _date.minute,
          ));
    }
  }

  Future<void> _pickCategory() async {
    final cats = _categoriesForType();
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Категория',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 8),
                Flexible(
                  child: GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 3,
                    childAspectRatio: 0.95,
                    children: [
                      for (final c in cats)
                        InkWell(
                          onTap: () => Navigator.pop(ctx, c.id),
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: c.color.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(c.icon,
                                      color: c.color, size: 22),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  c.name,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (picked != null) setState(() => _categoryId = picked);
  }

  Future<void> _pickAccount() async {
    final accounts = ['Картой', 'Наличные', 'Перевод'];
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final a in accounts)
              ListTile(
                leading: Icon(
                  a == 'Картой'
                      ? Icons.credit_card_rounded
                      : a == 'Наличные'
                          ? Icons.payments_rounded
                          : Icons.swap_horiz_rounded,
                ),
                title: Text(a),
                onTap: () => Navigator.pop(ctx, a),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _account = picked);
  }

  @override
  Widget build(BuildContext context) {
    final cat = DefaultCategories.byId(_categoryId);
    final amountColor =
        _type == TxType.expense ? AppColors.textPrimary : AppColors.primary;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.edit == null ? 'Новая запись' : 'Редактировать'),
        centerTitle: true,
        actions: [
          if (widget.edit != null)
            IconButton(
              icon:
                  const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
              onPressed: () async {
                final navigator = Navigator.of(context);
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Удалить операцию?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Отмена')),
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Удалить',
                              style:
                                  TextStyle(color: AppColors.danger))),
                    ],
                  ),
                );
                if (ok == true) {
                  await widget.state
                      .deleteTransaction(widget.edit!.id);
                  if (!mounted) return;
                  navigator.pop();
                }
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _TypeSwitcher(
            value: _type,
            onChanged: (t) {
              setState(() {
                _type = t;
                _categoryId = _categoriesForType().first.id;
              });
            },
          ),
          const SizedBox(height: 24),
          Center(
            child: IntrinsicWidth(
              child: TextField(
                controller: _amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  color: amountColor,
                ),
                decoration: const InputDecoration(
                  hintText: '0',
                  suffixText: '₽',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _Tile(
            icon: cat?.icon ?? Icons.category_rounded,
            iconColor: cat?.color ?? AppColors.primary,
            label: cat?.name ?? 'Выбрать категорию',
            onTap: _pickCategory,
            trailing: const Icon(Icons.expand_more_rounded,
                color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          _Tile(
            icon: Icons.calendar_today_rounded,
            iconColor: AppColors.primary,
            label: formatDateLong(_date),
            onTap: _pickDate,
            trailing: const Icon(Icons.expand_more_rounded,
                color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          _Tile(
            icon: _account == 'Картой'
                ? Icons.credit_card_rounded
                : _account == 'Наличные'
                    ? Icons.payments_rounded
                    : Icons.swap_horiz_rounded,
            iconColor: AppColors.primary,
            label: _account,
            onTap: _pickAccount,
            trailing: const Icon(Icons.expand_more_rounded,
                color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _storeCtrl,
            decoration: const InputDecoration(
              hintText: 'Магазин (необязательно)',
              prefixIcon: Icon(Icons.storefront_rounded),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _commentCtrl,
            decoration: const InputDecoration(
              hintText: 'Комментарий (необязательно)',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _save,
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }
}

class _TypeSwitcher extends StatelessWidget {
  final TxType value;
  final ValueChanged<TxType> onChanged;

  const _TypeSwitcher({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, TxType type) {
      final selected = value == type;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.all(2),
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          tab('Расход', TxType.expense),
          tab('Доход', TxType.income),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  const _Tile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F6F4),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

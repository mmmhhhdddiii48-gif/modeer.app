part of 'owner_billing_page.dart';

final class _TariffInput {
  const _TariffInput({required this.pricePerAmpIqd, required this.fixedFeeIqd});
  final int pricePerAmpIqd;
  final int fixedFeeIqd;
}

final class _TariffDialog extends StatefulWidget {
  const _TariffDialog({required this.generator});
  final BillingGeneratorTariff generator;

  @override
  State<_TariffDialog> createState() => _TariffDialogState();
}

final class _TariffDialogState extends State<_TariffDialog> {
  late final TextEditingController _price;
  late final TextEditingController _fee;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _price = TextEditingController(text: widget.generator.tariff?.pricePerAmpIqd.toString() ?? '');
    _fee = TextEditingController(text: widget.generator.tariff?.fixedFeeIqd.toString() ?? '0');
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('تسعيرة ${widget.generator.generatorName}'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'سعر الأمبير بالدينار'),
                validator: _moneyValidator,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _fee,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'رسم ثابت اختياري'),
                validator: _moneyValidator,
              ),
              const SizedBox(height: 12),
              const Text(
                'الحساب: الأمبير المتعاقد × سعر الأمبير + الرسم الثابت.',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              if (!_formKey.currentState!.validate()) return;
              Navigator.pop(
                context,
                _TariffInput(
                  pricePerAmpIqd: int.parse(_price.text.trim()),
                  fixedFeeIqd: int.parse(_fee.text.trim()),
                ),
              );
            },
            child: const Text('حفظ التسعيرة'),
          ),
        ],
      );

  String? _moneyValidator(String? value) {
    final number = int.tryParse(value?.trim() ?? '');
    if (number == null || number < 0 || number > 1000000000) return 'أدخل مبلغًا صحيحًا غير سالب';
    return null;
  }

  @override
  void dispose() {
    _price.dispose();
    _fee.dispose();
    super.dispose();
  }
}

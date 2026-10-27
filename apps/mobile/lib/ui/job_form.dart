import 'package:flutter/material.dart';

import '../data/repo.dart';
import '../l10n/app_localizations.dart';
import 'format.dart';

Future<void> openJobForm(BuildContext context, Repo repo, String shiftId, Map<String, dynamic>? job) =>
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => JobFormPage(repo: repo, shiftId: shiftId, job: job),
    ));

class JobFormPage extends StatefulWidget {
  const JobFormPage({super.key, required this.repo, required this.shiftId, this.job});
  final Repo repo;
  final String shiftId;
  final Map<String, dynamic>? job;

  @override
  State<JobFormPage> createState() => _JobFormPageState();
}

class _JobFormPageState extends State<JobFormPage> {
  final _form = GlobalKey<FormState>();
  late final _opp = TextEditingController(text: widget.job?['opportunity_id'] as String? ?? '');
  late final _preTax = TextEditingController(text: _fmt(widget.job?['revenue_pre_tax']));
  late final _total = TextEditingController(text: _fmt(widget.job?['revenue_total_incl_tax']));
  late final _tip = TextEditingController(text: _fmt(widget.job?['tip_amount']));
  late final _discount = TextEditingController(text: _fmt(widget.job?['discount_amount']));
  late bool _completed = (widget.job?['outcome'] as String?) != 'cancelled_pending';
  late String? _method = widget.job?['payment_method_code'] as String?;

  static String _fmt(Object? v) => v == null || v == 0 || v == 0.0 ? '' : (v as num).toStringAsFixed(2);

  Future<void> _addTax() async {
    final pre = parseAmount(_preTax.text);
    if (pre == null) return;
    final rate = await widget.repo.salesTaxRate();
    setState(() => _total.text = (pre * (1 + rate)).toStringAsFixed(2));
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    await widget.repo.saveJob(JobDraft(
      id: widget.job?['id'] as String?,
      shiftId: widget.shiftId,
      opportunityId: _opp.text.trim(),
      outcome: _completed ? 'completed' : 'cancelled_pending',
      paymentMethod: _completed ? _method : null,
      preTax: _completed ? parseAmount(_preTax.text) : null,
      total: _completed ? parseAmount(_total.text) : null,
      tip: _completed ? (parseAmount(_tip.text) ?? 0) : 0,
      discount: _completed ? (parseAmount(_discount.text) ?? 0) : 0,
    ));
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    await widget.repo.deleteJob(widget.job!['id'] as String);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    String? requiredText(String? v) => (v == null || v.trim().isEmpty) ? t.required : null;
    String? amount(String? v, {bool required = false}) {
      if (v == null || v.trim().isEmpty) return required ? t.required : null;
      final n = parseAmount(v);
      return n == null || n < 0 ? t.invalidAmount : null;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.job == null ? t.addJob : '${widget.job!['opportunity_id']}'),
        actions: [
          if (widget.job != null) IconButton(icon: const Icon(Icons.delete_outline), tooltip: t.delete, onPressed: _delete),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            TextFormField(
              controller: _opp,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(labelText: t.opportunityId, border: const OutlineInputBorder()),
              validator: requiredText,
            ),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: true, label: Text(t.completed), icon: const Icon(Icons.check)),
                ButtonSegment(value: false, label: Text(t.cancelled), icon: const Icon(Icons.close)),
              ],
              selected: {_completed},
              onSelectionChanged: (s) => setState(() => _completed = s.first),
            ),
            const SizedBox(height: 16),
            if (!_completed)
              Card(child: Padding(padding: const EdgeInsets.all(12), child: Text(t.callDispatchFirst))),
            if (_completed) ...[
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: widget.repo.paymentMethods(),
                builder: (context, snap) {
                  final methods = snap.data ?? [];
                  final en = Localizations.localeOf(context).languageCode == 'en';
                  return DropdownButtonFormField<String>(
                    initialValue: methods.any((m) => m['id'] == _method) ? _method : null,
                    decoration: InputDecoration(labelText: t.paymentMethod, border: const OutlineInputBorder()),
                    items: [
                      for (final m in methods)
                        DropdownMenuItem(value: m['id'] as String, child: Text('${en ? m['name_en'] : m['name_fr']}')),
                    ],
                    onChanged: (v) => setState(() => _method = v),
                    validator: (v) => v == null ? t.required : null,
                  );
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _preTax,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: t.preTax, border: const OutlineInputBorder(), prefixText: r'$ '),
                validator: (v) => amount(v, required: true),
              ),
              const SizedBox(height: 16),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: TextFormField(
                    controller: _total,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: t.totalWithTax, border: const OutlineInputBorder(), prefixText: r'$ '),
                    validator: (v) {
                      final base = amount(v, required: true);
                      if (base != null) return base;
                      final pre = parseAmount(_preTax.text);
                      return pre != null && parseAmount(v!)! < pre ? t.totalBelowPreTax : null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton(onPressed: _addTax, child: Text(t.addTax)),
                ),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _tip,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: t.tip, border: const OutlineInputBorder(), prefixText: r'$ '),
                    validator: amount,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _discount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: t.discount, border: const OutlineInputBorder(), prefixText: r'$ '),
                    validator: amount,
                  ),
                ),
              ]),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: Text(t.save),
            ),
          ]),
        ),
      ),
    );
  }
}

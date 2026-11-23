import 'package:flutter/material.dart';

/// Formularios reutilizables del panel móvil. Cada botón de guardar entrega
/// datos reales para la API; las reglas críticas se vuelven a validar en PHP.
class AdminMobileField {
  final String keyName;
  final String label;
  final bool requiredValue;
  final bool numeric;
  final List<DropdownMenuItem<String>>? choices;

  const AdminMobileField(this.keyName, this.label, {
    this.requiredValue = false,
    this.numeric = false,
    this.choices,
  });
}

class AdminMobileForm extends StatefulWidget {
  final String title;
  final List<AdminMobileField> fields;
  final Map<String, dynamic> initial;

  const AdminMobileForm({
    super.key,
    required this.title,
    required this.fields,
    this.initial = const {},
  });

  static Future<Map<String, dynamic>?> open(BuildContext context, {
    required String title,
    required List<AdminMobileField> fields,
    Map<String, dynamic> initial = const {},
  }) => showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => AdminMobileForm(
        title: title, fields: fields, initial: initial),
  );

  @override
  State<AdminMobileForm> createState() => _AdminMobileFormState();
}

class _AdminMobileFormState extends State<AdminMobileForm> {
  final _form = GlobalKey<FormState>();
  late final Map<String, dynamic> _values;

  @override
  void initState() {
    super.initState();
    _values = Map<String, dynamic>.from(widget.initial);
    for (final field in widget.fields) {
      if (field.choices != null && !_values.containsKey(field.keyName) &&
          field.choices!.isNotEmpty) {
        _values[field.keyName] = field.choices!.first.value;
      }
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520, maxHeight: 650),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(key: _form, child: Column(children: [
          Row(children: [
            Expanded(child: Text(widget.title,
                style: const TextStyle(fontSize: 19,
                    fontWeight: FontWeight.w800))),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Cancelar',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ]),
          const SizedBox(height: 10),
          Expanded(child: SingleChildScrollView(
            child: Column(children: [
              for (final field in widget.fields) Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: field.choices == null ? TextFormField(
                  initialValue: field.keyName.contains('contrasena') ? ''
                      : _values[field.keyName]?.toString() ?? '',
                  obscureText: field.keyName.contains('contrasena'),
                  maxLines: field.keyName.contains('respuesta') ? 4 : 1,
                  keyboardType: field.numeric
                      ? const TextInputType.numberWithOptions(decimal: true)
                      : TextInputType.text,
                  decoration: InputDecoration(
                      labelText: field.label,
                      border: const OutlineInputBorder()),
                  onChanged: (value) => _values[field.keyName] = value,
                  validator: (value) {
                    final v = (value ?? '').trim();
                    if (field.requiredValue && v.isEmpty) {
                      return 'Campo obligatorio';
                    }
                    if (field.numeric && v.isNotEmpty &&
                        (double.tryParse(v) == null ||
                         double.parse(v) < 0)) {
                      return 'Escribe un número válido';
                    }
                    return null;
                  },
                ) : DropdownButtonFormField<String>(
                  initialValue: _values[field.keyName]?.toString(),
                  isExpanded: true,
                  decoration: InputDecoration(
                      labelText: field.label,
                      border: const OutlineInputBorder()),
                  items: field.choices,
                  onChanged: (value) {
                    if (value != null) _values[field.keyName] = value;
                  },
                  validator: (v) => field.requiredValue && (v == null || v.isEmpty)
                      ? 'Selecciona una opción' : null,
                ),
              ),
            ]),
          )),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar cambios'),
              onPressed: () {
                if (_form.currentState?.validate() ?? false) {
                  Navigator.of(context).pop(_values);
                }
              },
            ),
          ),
        ])),
      ),
    ),
  );
}

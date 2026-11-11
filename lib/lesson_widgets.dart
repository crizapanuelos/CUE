import 'package:flutter/material.dart';

// All composed controls use widgets explicitly shown in the two lesson PDFs.
// FloatingActionButton is in Lesson 1 p.36; Card is in Lesson 2 pp.13,15.
class LessonButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool secondary;
  const LessonButton(
    this.label, {
    super.key,
    this.onPressed,
    this.icon,
    this.secondary = false,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 46,
    child: FloatingActionButton.extended(
      heroTag: null,
      elevation: 0,
      extendedPadding: const EdgeInsets.symmetric(horizontal: 10),
      backgroundColor: secondary
          ? const Color(0xFFE8E3CD)
          : const Color(0xFF075139),
      foregroundColor: secondary ? const Color(0xFF263F31) : Colors.white,
      onPressed: onPressed,
      icon: icon == null ? null : Icon(icon, size: 19),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    ),
  );
}

class LessonPanel extends StatelessWidget {
  final Widget child;
  const LessonPanel({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    margin: const EdgeInsets.symmetric(vertical: 7),
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );
}

class FieldSpec {
  final String label;
  final String initial;
  final String? Function(String?)? validator;
  final TextInputType keyboard;
  final bool password;
  final int lines;
  const FieldSpec(
    this.label, {
    this.initial = '',
    this.validator,
    this.keyboard = TextInputType.text,
    this.password = false,
    this.lines = 1,
  });
}

// Lesson 1: ordinary StatefulWidget, createState, initState and setState.
// Lesson 2: Form, GlobalKey<FormState>, TextFormField, validator and keyboardType.
class LessonForm extends StatefulWidget {
  final List<FieldSpec> fields;
  final String submit;
  final Future<void> Function(Map<String, String>) onSubmit;
  final String description;
  const LessonForm({
    super.key,
    required this.fields,
    required this.submit,
    required this.onSubmit,
    this.description = '',
  });
  @override
  State<LessonForm> createState() => _LessonFormState();
}

class _LessonFormState extends State<LessonForm> {
  final formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> controllers;
  bool busy = false, showPassword = false;
  String message = '';
  @override
  void initState() {
    super.initState();
    controllers = {
      for (final f in widget.fields)
        f.label: TextEditingController(text: f.initial),
    };
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.description.isNotEmpty) ...[
          Text(widget.description),
          const SizedBox(height: 16),
        ],
        for (final f in widget.fields)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: TextFormField(
              key: ValueKey(f.label),
              controller: controllers[f.label],
              validator: f.validator,
              keyboardType: f.keyboard,
              obscureText: f.password && !showPassword,
              maxLines: f.password ? 1 : f.lines,
              decoration: InputDecoration(labelText: f.label),
            ),
          ),
        if (widget.fields.any((f) => f.password)) ...[
          LessonButton(
            showPassword ? 'Hide passwords' : 'Show passwords',
            secondary: true,
            onPressed: () => setState(() => showPassword = !showPassword),
          ),
          const SizedBox(height: 14),
        ],
        if (message.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(message),
          ),
        LessonButton(
          busy ? 'Please wait...' : widget.submit,
          onPressed: busy
              ? null
              : () async {
                  if (!formKey.currentState!.validate()) {
                    return;
                  }
                  setState(() {
                    busy = true;
                    message = '';
                  });
                  try {
                    await widget.onSubmit({
                      for (final e in controllers.entries) e.key: e.value.text,
                    });
                  } catch (e) {
                    if (mounted) {
                      setState(
                        () => message = e.toString().replaceFirst(
                          'Bad state: ',
                          '',
                        ),
                      );
                    }
                  } finally {
                    if (mounted) {
                      setState(() => busy = false);
                    }
                  }
                },
        ),
      ],
    ),
  );
}

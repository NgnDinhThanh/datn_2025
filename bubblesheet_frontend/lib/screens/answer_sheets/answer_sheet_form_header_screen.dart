import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/answer_sheet_form_provider.dart';
import 'package:go_router/go_router.dart';

class AnswerSheetFormHeaderScreen extends StatefulWidget {
  const AnswerSheetFormHeaderScreen({Key? key}) : super(key: key);

  @override
  State<AnswerSheetFormHeaderScreen> createState() => _AnswerSheetFormHeaderScreenState();
}

class _AnswerSheetFormHeaderScreenState extends State<AnswerSheetFormHeaderScreen> {
  final _formKey = GlobalKey<FormState>();
  final List<String> _widthOptions = ['Large', 'Medium', 'Small'];

  @override
  Widget build(BuildContext context) {
    final formProvider = Provider.of<AnswerSheetFormProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Step 2 of 5: Header Boxes'),
        centerTitle: true,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 700),
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Sheet Name: ${formProvider.name}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 16),
                Table(
                  border: TableBorder.all(color: Colors.grey.shade300),
                  columnWidths: const {
                    0: FixedColumnWidth(80),
                    1: FixedColumnWidth(80),
                    2: FlexColumnWidth(),
                    3: FixedColumnWidth(100),
                  },
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: Colors.grey.shade200),
                      children: const [
                        TableCell(child: Center(child: Text('Usage'))),
                        TableCell(child: Center(child: Text('Enabled?'))),
                        TableCell(child: Center(child: Text('Displayed Label On Answer Sheet'))),
                        TableCell(child: Center(child: Text('Width'))),
                      ],
                    ),
                    ...List.generate(formProvider.headers.length, (i) {
                      final header = formProvider.headers[i];
                      return TableRow(
                        children: [
                          TableCell(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Center(child: Text('Header ${i + 1}')),
                            ),
                          ),
                          TableCell(
                            child: Center(
                              child: Checkbox(
                                value: header.enabled,
                                onChanged: (val) {
                                  formProvider.setHeader(i, HeaderField(
                                    enabled: val ?? false,
                                    label: header.label,
                                    width: header.width,
                                  ));
                                },
                              ),
                            ),
                          ),
                          TableCell(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: TextFormField(
                                initialValue: header.label,
                                enabled: header.enabled,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (header.enabled && (value == null || value.trim().isEmpty)) {
                                    return 'Required';
                                  }
                                  if (value != null && value.length > 20) {
                                    return 'Max 20 chars';
                                  }
                                  return null;
                                },
                                onChanged: (val) {
                                  formProvider.setHeader(i, HeaderField(
                                    enabled: header.enabled,
                                    label: val,
                                    width: header.width,
                                  ));
                                },
                              ),
                            ),
                          ),
                          TableCell(
                            child: Center(
                              child: DropdownButton<String>(
                                value: header.width,
                                items: _widthOptions.map((w) => DropdownMenuItem(
                                  value: w,
                                  child: Text(w),
                                )).toList(),
                                onChanged: header.enabled
                                    ? (val) {
                                        if (val != null) {
                                          formProvider.setHeader(i, HeaderField(
                                            enabled: header.enabled,
                                            label: header.label,
                                            width: val,
                                          ));
                                        }
                                      }
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        context.go('/answer-sheets/create/name/');
                      },
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          context.go('/answer-sheets/create/count/');
                        }
                      },
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Next'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 
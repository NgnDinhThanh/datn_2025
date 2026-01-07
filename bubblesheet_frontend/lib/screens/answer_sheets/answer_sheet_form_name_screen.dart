import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/answer_sheet_form_provider.dart';
import 'package:go_router/go_router.dart';

class AnswerSheetFormNameScreen extends StatefulWidget {
  const AnswerSheetFormNameScreen({Key? key}) : super(key: key);

  @override
  State<AnswerSheetFormNameScreen> createState() => _AnswerSheetFormNameScreenState();
}

class _AnswerSheetFormNameScreenState extends State<AnswerSheetFormNameScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    // Set initial value
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final formProvider = Provider.of<AnswerSheetFormProvider>(context, listen: false);
      _nameController.text = formProvider.name;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formProvider = Provider.of<AnswerSheetFormProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Step 1 of 5: Custom Answer Sheet Name'),
        centerTitle: true,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Name',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    hintText: 'Enter Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a name';
                    }
                    if (value.length > 50) {
                      return 'Name should be less than 50 characters';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    formProvider.setName(value);
                  },
                ),
                const SizedBox(height: 8),
                const Text(
                  'The name of the answer sheet should be unique and descriptive',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          formProvider.setName(_nameController.text.trim());
                          context.go('/answer-sheets/create/header/');
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
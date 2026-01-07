// import 'dart:html' as html; // Web-only import
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import '../../providers/auth_provider.dart';
import '../../providers/student_provider.dart';
import '../../providers/class_provider.dart';
import '../../services/api_service.dart';
import 'package:go_router/go_router.dart';

class StudentImportScreen extends StatefulWidget {
  const StudentImportScreen({Key? key}) : super(key: key);

  @override
  State<StudentImportScreen> createState() => _StudentImportScreenState();
}

class _StudentImportScreenState extends State<StudentImportScreen> {
  int _step = 0;
  Uint8List? _fileBytes;
  String? _fileName;
  bool _hasHeader = false;
  List<List<String>> _csvData = [];
  List<String> _headers = [];
  Map<String, int> _fieldMapping = {'id': -1, 'first_name': -1, 'last_name': -1};
  String _classOption = 'none';
  String? _selectedClassId;
  String? _result;
  bool _isUploading = false;
  // html.File? _pendingFile; // Web-only

  void _pickFile() async{
    // Web-only file picker logic
    if (!kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File import functionality is only available on web')),
      );
      return;
    }
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt']
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() {
          _fileBytes = result.files.single.bytes;
          _fileName = result.files.single.name;
        });
        final content = utf8.decode(_fileBytes!);
        _parseCsv(content);

        if (_csvData.isNotEmpty) {
          setState(() {
            _step = 1;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error picking file: $e")),
      );
    }
  }

  void _parseCsv(String content) {
    final lines = LineSplitter.split(content).toList();
    _csvData = lines.map((l) => l.split(',')).toList();
    if (_csvData.isNotEmpty && _hasHeader) {
      _headers = _csvData.first;
      _csvData = _csvData.sublist(1);
    } else if (_csvData.isNotEmpty) {
      _headers = List.generate(_csvData.first.length, (i) => 'Column ${i + 1}');
    }
    // Reset mapping
    _fieldMapping = {'id': -1, 'first_name': -1, 'last_name': -1};
  }

  Future<void> _importStudents() async {
    setState(() { _isUploading = true; _result = null; });
    // Chuẩn bị dữ liệu mapping
    List<Map<String, String>> students = [];
    for (var row in _csvData) {
      final idIdx = _fieldMapping['id']!;
      final fnIdx = _fieldMapping['first_name']!;
      final lnIdx = _fieldMapping['last_name']!;
      if (idIdx < 0 || fnIdx < 0 || lnIdx < 0) continue;
      students.add({
        'student_id': row.length > idIdx ? row[idIdx].trim() : '',
        'first_name': row.length > fnIdx ? row[fnIdx].trim() : '',
        'last_name': row.length > lnIdx ? row[lnIdx].trim() : '',
      });
    }
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    var request = http.MultipartRequest('POST', Uri.parse('${ApiService.baseUrl}/students/import/'));
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['has_header'] = 'false';
    request.fields['students'] = jsonEncode(students);
    if (_classOption == 'class' && _selectedClassId != null) {
      request.fields['class_id'] = _selectedClassId!;
    }
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    setState(() { _isUploading = false; _result = response.body; _step = 2; });
    if (response.statusCode == 200) {
      await context.read<StudentProvider>().fetchStudents(context);
      await context.read<ClassProvider>().fetchClasses(context);
    }
  }

  Future<void> _handleUpload() async {
    // Web-only upload logic
    if (!kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("File upload functionality is only available on web"))
      );
      return;
    }

    if (_fileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a file first")),
      );
      return;
    }

    final content = utf8.decode(_fileBytes!);
    _parseCsv(content);

    if (_csvData.isNotEmpty) {
      setState(() {
        _step = 1;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File is empty or invalid'))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final allClasses = context.watch<ClassProvider>().classes;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Center(
        child: Container(
          width: 900,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: _step == 0 ? _buildStep1() : _step == 1 ? _buildStep2(allClasses) : _buildStep3(),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('File requirements:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              const SizedBox(height: 8),
              const Text("Must have 'csv' extension\nFields should be separated by commas.\nFields:", style: TextStyle(fontSize: 16)),
              const SizedBox(height: 4),
              const Text("  - Student ID (required)\n  - First Name (required)\n  - Last Name (required)", style: TextStyle(fontSize: 15)),
              const SizedBox(height: 8),
              const Text("If your file has a header row, please check 'Has header row' so first row will be ignored on import.", style: TextStyle(fontSize: 15)),
            ],
          ),
        ),
        const SizedBox(width: 32),
        Container(
          width: 320,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Browse CSV file:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isUploading ? null : _pickFile,
                child: Text(_fileName == null ? 'Choose File' : _fileName!),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(
                    value: _hasHeader,
                    onChanged: _isUploading ? null : (v) => setState(() => _hasHeader = v ?? false),
                  ),
                  const Text('Has a Header Row (Skip first row)?'),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: (_fileName != null && !_isUploading) ? _handleUpload : null,
                child: _isUploading ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Upload'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep2(List allClasses) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('SELECT FIELD MAPPING', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 16),
              _buildMappingDropdown('Student ID', 'id'),
              _buildMappingDropdown('First Name', 'first_name'),
              _buildMappingDropdown('Last Name', 'last_name'),
              const SizedBox(height: 16),
              const Text('Class Options:'),
              DropdownButton<String>(
                value: _classOption,
                items: const [
                  DropdownMenuItem(value: 'none', child: Text('Do not load students into class')),
                  DropdownMenuItem(value: 'class', child: Text('Place students into existing class')),
                ],
                onChanged: (v) => setState(() { _classOption = v!; _selectedClassId = null; }),
              ),
              if (_classOption == 'class') ...[
                const SizedBox(height: 8),
                DropdownButton<String>(
                  value: _selectedClassId,
                  hint: const Text('Existing Class'),
                  items: allClasses.map<DropdownMenuItem<String>>((c) => DropdownMenuItem(value: c.id, child: Text(c.class_name))).toList(),
                  onChanged: (v) => setState(() => _selectedClassId = v),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isUploading || !_mappingValid() ? null : _importStudents,
                child: _isUploading ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Next'),
              ),
            ],
          ),
        ),
        const SizedBox(width: 32),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('DATA READ FROM FILE:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
              const SizedBox(height: 8),
              _buildPreviewTable(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep3() {
    Map<String, dynamic>? resultMap;
    String? errorMessage;
    try {
      resultMap = _result != null ? jsonDecode(_result!) : null;
    } catch (e) {
      errorMessage = 'An error occurred while parsing the import result.';
    }

    final successCount = resultMap?['success_count'] ?? 0;
    final errorCount = resultMap?['error_count'] ?? 0;
    
    // Parse errors đúng cấu trúc (List<Map> từ backend)
    final errorsList = (resultMap?['errors'] as List?) ?? [];
    final errors = errorsList.map((errorMap) {
      if (errorMap is Map<String, dynamic>) {
        final row = errorMap['row'] ?? '?';
        final error = errorMap['error'] ?? 'Unknown error';
        return 'Row $row: $error';
      }
      return errorMap.toString();
    }).toList();

    void goToStudents() {
      context.go('/students');
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(
              errorMessage,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: goToStudents,
              child: const Text('Return to Students'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 24),
        Icon(
          errorCount == 0 ? Icons.check_circle : Icons.error,
          color: errorCount == 0 ? Colors.green : Colors.red,
          size: 64,
        ),
        const SizedBox(height: 16),
        Text(
          errorCount == 0 ? 'Import successful!' : 'Some errors occurred during import.',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        const SizedBox(height: 16),
        Text('Number of students added: $successCount'),
        Text('Number of errors: $errorCount'),
        if (errors.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('Error list:', style: TextStyle(fontWeight: FontWeight.bold)),
          ...errors.map((e) => Text('- $e')).toList(),
        ],
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: goToStudents,
          child: const Text('Return to Students'),
        ),
      ],
    );
  }

  Widget _buildMappingDropdown(String label, String field) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label + (field != 'id' ? '' : '*'), style: const TextStyle(fontWeight: FontWeight.bold))),
          const SizedBox(width: 12),
          DropdownButton<int>(
            value: _fieldMapping[field] != -1 ? _fieldMapping[field] : null,
            hint: const Text('Select column'),
            items: _headers.asMap().entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (v) => setState(() => _fieldMapping[field] = v!),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewTable() {
    if (_headers.isEmpty || _csvData.isEmpty) return const Text('No data');
    return Table(
      border: TableBorder.all(color: Colors.grey, width: 0.7),
      columnWidths: {for (var i = 0; i < _headers.length; i++) i: const IntrinsicColumnWidth()},
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade200),
          children: _headers.map((h) => Padding(padding: const EdgeInsets.all(8), child: Text(h, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
        ),
        ..._csvData.take(10).map((row) => TableRow(
          children: List.generate(_headers.length, (i) => Padding(
            padding: const EdgeInsets.all(8),
            child: Text(i < row.length ? row[i] : ''),
          )),
        )),
      ],
    );
  }

  bool _mappingValid() {
    return _fieldMapping['id'] != -1 && _fieldMapping['first_name'] != -1 && _fieldMapping['last_name'] != -1 && (_classOption != 'class' || _selectedClassId != null);
  }
} 
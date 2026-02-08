import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../services/gradebook_service.dart';
import 'dart:typed_data';
import 'package:excel/excel.dart';

// For web download
import 'package:universal_html/html.dart' as html;

class ClassGradeBookScreen extends StatefulWidget {
  final String classCode;

  const ClassGradeBookScreen({Key? key, required this.classCode})
    : super(key: key);

  @override
  State<ClassGradeBookScreen> createState() => _ClassGradeBookScreenState();
}

class _ClassGradeBookScreenState extends State<ClassGradeBookScreen> {
  bool _isLoading = true;
  String? _error;
  GradeBookData? _gradebookData;
  bool _showPercentage = false;

  final ScrollController _horizontalController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchGradeBook();
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  Future<void> _fetchGradeBook() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final gradebook = await GradeBookService.getGradeBook(
        widget.classCode,
        token,
      );
      setState(() {
        _gradebookData = gradebook;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _toggleView() {
    setState(() {
      _showPercentage = !_showPercentage;
    });
  }

  void _exportToCSV() {
    if (_gradebookData == null) return;

    try {
      final csvContent = _generateCSV();
      _downloadFile(
        csvContent,
        '${_gradebookData!.classCode}_gradebook.csv',
        'text/csv',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV file downloaded successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error exporting CSV: $e')));
    }
  }

  void _exportToExcel() {
    if (_gradebookData == null) return;

    try {
      // Generate real Excel file bytes
      final excelBytes = _generateExcelBytes();
      _downloadExcelBytes(
        excelBytes,
        '${_gradebookData!.classCode}_gradebook.xlsx',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Excel file downloaded successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error exporting Excel: $e')));
    }
  }

  String _generateCSV() {
    if (_gradebookData == null) return '';

    final students = _gradebookData!.students;
    final exams = _gradebookData!.exams;
    final buffer = StringBuffer();

    // Escape CSV field (handle commas, quotes, newlines)
    String escapeCsvField(String field) {
      if (field.contains(',') || field.contains('"') || field.contains('\n')) {
        return '"${field.replaceAll('"', '""')}"';
      }
      return field;
    }

    // Header row
    buffer.write('Student ID,Student Name');
    for (final exam in exams) {
      final columnName = _showPercentage
          ? '${exam.name} (%)'
          : '${exam.name} (Score)';
      buffer.write(',${escapeCsvField(columnName)}');
    }
    buffer.write('\n');

    // Data rows
    for (final student in students) {
      buffer.write(
        '${escapeCsvField(student.studentId)},${escapeCsvField(student.name)}',
      );

      for (final exam in exams) {
        final grade = _gradebookData!.getGrade(student.studentId, exam.id);
        String value = '-';

        if (grade != null) {
          if (_showPercentage) {
            value = grade.percentage != null
                ? '${grade.percentage!.toStringAsFixed(1)}%'
                : '-';
          } else {
            value = grade.score != null ? grade.score!.toStringAsFixed(1) : '-';
          }
        }

        buffer.write(',${escapeCsvField(value)}');
      }
      buffer.write('\n');
    }

    return buffer.toString();
  }

  /// Generate Excel file bytes from GradeBookData
  Uint8List _generateExcelBytes() {
    if (_gradebookData == null) {
      throw Exception('No gradebook data available');
    }

    final students = _gradebookData!.students;
    final exams = _gradebookData!.exams;

    // Create Excel workbook
    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];

    // Write header row (row 0)
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value =
        TextCellValue('Student ID');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0)).value =
        TextCellValue('Student Name');

    int colIndex = 2;
    for (final exam in exams) {
      final columnName = _showPercentage
          ? '${exam.name} (%)'
          : '${exam.name} (Score)';
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: 0))
          .value = TextCellValue(
        columnName,
      );
      colIndex++;
    }

    // Write data rows
    int rowIndex = 1;
    for (final student in students) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
          .value = TextCellValue(
        student.studentId,
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
          .value = TextCellValue(
        student.name,
      );

      colIndex = 2;
      for (final exam in exams) {
        final grade = _gradebookData!.getGrade(student.studentId, exam.id);
        CellValue cellValue;

        if (grade != null) {
          if (_showPercentage) {
            if (grade.percentage != null) {
              // Use double value for percentage (Excel will format it)
              cellValue = DoubleCellValue(grade.percentage!);
            } else {
              cellValue = TextCellValue('-');
            }
          } else {
            if (grade.score != null) {
              // Use double value for score
              cellValue = DoubleCellValue(grade.score!);
            } else {
              cellValue = TextCellValue('-');
            }
          }
        } else {
          cellValue = TextCellValue('-');
        }

        sheet
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: colIndex,
                    rowIndex: rowIndex,
                  ),
                )
                .value =
            cellValue;
        colIndex++;
      }
      rowIndex++;
    }

    // Save Excel file and get bytes (convert List<int> to Uint8List)
    final bytes = excel.save();
    if (bytes == null) {
      throw Exception('Failed to generate Excel file');
    }
    return Uint8List.fromList(bytes);
  }

  void _downloadFile(String content, String filename, String mimeType) {
    if (kIsWeb) {
      // Web download using universal_html
      final blob = html.Blob([content], mimeType);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      // Mobile/Desktop: Could use share_plus or file_picker
      // For now, just show a message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File export is currently only available on web'),
        ),
      );
    }
  }

  /// Download Excel file bytes on web
  void _downloadExcelBytes(Uint8List bytes, String filename) {
    if (kIsWeb) {
      // Web download using universal_html
      final blob = html.Blob([
        bytes,
      ], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      // Mobile/Desktop: Could use share_plus or file_picker
      // For now, just show a message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Excel export is currently only available on web'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Error loading gradebook',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchGradeBook,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_gradebookData == null) {
      return const Center(child: Text('No data available'));
    }

    return _buildGradeBookTable();
  }

  Widget _buildGradeBookTable() {
    if (_gradebookData == null) return const SizedBox.shrink();

    final students = _gradebookData!.students;
    final exams = _gradebookData!.exams;

    if (students.isEmpty || exams.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              students.isEmpty
                  ? 'No students in this class'
                  : 'No exams assigned to this class',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header info
        // Header info với actions
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _gradebookData!.className,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${students.length} students • ${exams.length} exams',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              // Actions (chuyển từ AppBar xuống đây)
              IconButton(
                icon: Icon(_showPercentage ? Icons.numbers : Icons.percent),
                tooltip: _showPercentage ? 'Show Scores' : 'Show Percentages',
                onPressed: _toggleView,
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'csv')
                    _exportToCSV();
                  else if (value == 'excel')
                    _exportToExcel();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'csv',
                    child: Row(
                      children: [
                        Icon(Icons.file_download),
                        SizedBox(width: 8),
                        Text('Export CSV'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'excel',
                    child: Row(
                      children: [
                        Icon(Icons.file_download),
                        SizedBox(width: 8),
                        Text('Export Excel'),
                      ],
                    ),
                  ),
                ],
                icon: const Icon(Icons.download),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Table
        Scrollbar(
          controller: _horizontalController,
          child: SingleChildScrollView(
            controller: _horizontalController,
            scrollDirection: Axis.horizontal,
            child: _buildTable(students, exams),
          ),
        ),
      ],
    );
  }

  Widget _buildTable(List<StudentInfo> students, List<ExamInfo> exams) {
    return Table(
      border: TableBorder.all(color: Colors.grey[300]!),
      columnWidths: {
        0: const FixedColumnWidth(120), // Student ID column
        1: const FixedColumnWidth(200), // Student Name column
        ...Map.fromIterable(
          List.generate(exams.length, (index) => index + 2),
          key: (index) => index,
          value: (index) => const FixedColumnWidth(100), // Exam columns
        ),
      },
      children: [
        // Header row
        TableRow(
          decoration: BoxDecoration(color: Colors.grey[200]),
          children: [
            _buildHeaderCell('Student ID'),
            _buildHeaderCell('Student Name'),
            ...exams.map(
              (exam) =>
                  _buildHeaderCell(exam.name, tooltip: 'Date: ${exam.date}'),
            ),
          ],
        ),
        // Data rows
        ...students.map((student) {
          return TableRow(
            children: [
              _buildCell(student.studentId, isFixed: true),
              _buildCell(student.name, isFixed: true),
              ...exams.map((exam) {
                final grade = _gradebookData!.getGrade(
                  student.studentId,
                  exam.id,
                );
                return _buildGradeCell(grade);
              }),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildHeaderCell(String text, {String? tooltip}) {
    return Tooltip(
      message: tooltip ?? text,
      child: Container(
        padding: const EdgeInsets.all(12),
        alignment: Alignment.center,
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildCell(String text, {bool isFixed = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      alignment: isFixed ? Alignment.centerLeft : Alignment.center,
      color: Colors.white,
      child: Text(
        text,
        style: const TextStyle(fontSize: 13),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildGradeCell(GradeEntry? grade) {
    if (grade == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        alignment: Alignment.center,
        color: Colors.grey[50],
        child: const Text(
          '-',
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
      );
    }

    final value = _showPercentage
        ? (grade.percentage != null
              ? '${grade.percentage!.toStringAsFixed(1)}%'
              : '-')
        : (grade.score != null ? grade.score!.toStringAsFixed(1) : '-');

    // Color coding based on percentage (if showing percentage)
    Color? backgroundColor;
    Color? textColor;
    if (_showPercentage && grade.percentage != null) {
      if (grade.percentage! >= 90) {
        backgroundColor = Colors.green[50];
        textColor = Colors.green[700];
      } else if (grade.percentage! >= 70) {
        backgroundColor = Colors.blue[50];
        textColor = Colors.blue[700];
      } else if (grade.percentage! >= 50) {
        backgroundColor = Colors.orange[50];
        textColor = Colors.orange[700];
      } else {
        backgroundColor = Colors.red[50];
        textColor = Colors.red[700];
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      alignment: Alignment.center,
      color: backgroundColor ?? Colors.white,
      child: Text(
        value,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }
}

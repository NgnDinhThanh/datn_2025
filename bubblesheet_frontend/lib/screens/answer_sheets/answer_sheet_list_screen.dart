import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/answer_sheet_model.dart';
import '../../providers/answer_sheet_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/answer_sheet_service.dart';
import 'package:universal_html/html.dart' as html;
import 'package:intl/intl.dart';

class AnswerSheetListScreen extends StatefulWidget {
  const AnswerSheetListScreen({Key? key}) : super(key: key);

  @override
  State<AnswerSheetListScreen> createState() => _AnswerSheetListScreenState();
}

class _AnswerSheetListScreenState extends State<AnswerSheetListScreen> {
  final Set<String> _selectedAnswerSheetIds = {};
  int _pageSize = 10;
  int _currentPage = 1;
  String _searchText = '';
  String _sortField = 'name';
  bool _sortAsc = true;
  Timer? _debounce;
  List<AnswerSheet> _filteredSheets = [];

  // Helper function to sanitize filename
  String _sanitizeFilename(String name) {
    // Replace invalid characters with underscore
    return name.replaceAll(RegExp(r'[^\w\s-]'), '_').trim();
  }

  // Helper function to download file on web
  Future<void> _downloadFile(Uint8List bytes, String filename) async {
    if (!kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download functionality is only available on web')),
      );
      return;
    }

    try {
      // Create blob from response bytes
      final blob = html.Blob([bytes]);
      final blobUrl = html.Url.createObjectUrlFromBlob(blob);
      
      // Create anchor element and trigger download
      final anchor = html.AnchorElement(href: blobUrl)
        ..setAttribute('download', filename)
        ..click();
      
      // Clean up
      html.Url.revokeObjectUrl(blobUrl);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download started: $filename')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    }
  }

  final List<int> _pageSizeOptions = [10, 25, 50, 100];
  final TextEditingController _searchController = TextEditingController();

  // ScrollController cho cuộn ngang bảng
  final ScrollController _horizontalController = ScrollController();
  // ScrollController cho cuộn dọc toàn trang
  final ScrollController _verticalController = ScrollController();

  final dateFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    // Gọi lại API mỗi khi vào màn hình này
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AnswerSheetProvider>().fetchAnswerSheets(context);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _horizontalController.dispose();
    _verticalController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _filterSheets(List<AnswerSheet> sheets) {
    final search = _searchText.toLowerCase();
    final filtered = sheets.where((s) {
      final combined = [
        s.name,
        s.numQuestions.toString(),
        s.studentIdDigits.toString(),
        s.createdAt.toString(),
      ].join(' ').toLowerCase();
      return combined.contains(search);
    }).toList();
    _sortSheets(filtered);
    setState(() {
      _filteredSheets = filtered;
      _currentPage = 1;
    });
  }

  void _sortSheets(List<AnswerSheet> sheets) {
    sheets.sort((a, b) {
      int cmp = 0;
      switch (_sortField) {
        case 'name':
          cmp = a.name.compareTo(b.name);
          break;
        case 'createdAt':
          cmp = a.createdAt.compareTo(b.createdAt);
          break;
        case 'numQuestions':
          cmp = a.numQuestions.compareTo(b.numQuestions);
          break;
        case 'studentIdDigits':
          cmp = a.studentIdDigits.compareTo(b.studentIdDigits);
          break;
      }
      return _sortAsc ? cmp : -cmp;
    });
  }

  void _onSort(String field) {
    setState(() {
      if (_sortField == field) {
        _sortAsc = !_sortAsc;
      } else {
        _sortField = field;
        _sortAsc = true;
      }
      _sortSheets(_filteredSheets);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _verticalController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _verticalController,
        child: Consumer<AnswerSheetProvider>(
          builder: (context, answerSheetProvider, child) {
            if (answerSheetProvider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (answerSheetProvider.error != null) {
              return Center(child: Text('Error: ${answerSheetProvider.error}'));
            }
            final sheets = answerSheetProvider.answerSheets;
            if (sheets.isEmpty) {
              return const Center(child: Text('No answer sheets found.'));
            }

            if (_filteredSheets.isEmpty && _searchText.isEmpty) {
              _filteredSheets = List<AnswerSheet>.from(sheets);
            }

            // Lọc và phân trang
            final int total = _filteredSheets.length;
            final int totalPages = (total / _pageSize).ceil();
            final int start = total == 0
                ? 0
                : (_currentPage - 1) * _pageSize + 1;
            final int end = total == 0
                ? 0
                : ((_currentPage * _pageSize) > total
                      ? total
                      : (_currentPage * _pageSize));
            final List<AnswerSheet> pageData = _filteredSheets
                .skip((_currentPage - 1) * _pageSize)
                .take(_pageSize)
                .toList();

            return Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 32),
                    const Text(
                      'All Answer Sheets',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            context.go('/answer-sheets/create/name');
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('New Answer Sheet'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Row(
                        children: [
                          // Show entries
                          Row(
                            children: [
                              const Text('Show '),
                              DropdownButton<int>(
                                value: _pageSize,
                                items: _pageSizeOptions
                                    .map(
                                      (size) => DropdownMenuItem(
                                        value: size,
                                        child: Text('$size'),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _pageSize = value;
                                      _currentPage = 1;
                                    });
                                  }
                                },
                              ),
                              const Text(' entries'),
                            ],
                          ),
                          const Spacer(),
                          // Search
                          Row(
                            children: [
                              const Text('Search: '),
                              SizedBox(
                                width: 180,
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: (value) {
                                    if (_debounce?.isActive ?? false)
                                      _debounce!.cancel();
                                    _searchText = value;
                                    _debounce = Timer(
                                      const Duration(microseconds: 300),
                                      () {
                                        _filterSheets(
                                          answerSheetProvider.answerSheets,
                                        );
                                      },
                                    );
                                  },
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: 8,
                                      horizontal: 8,
                                    ),
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 24),
                      padding: const EdgeInsets.all(0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Table(
                        border: TableBorder.all(color: Colors.grey, width: 0.7),
                        columnWidths: const {
                          0: FixedColumnWidth(80),
                          1: FixedColumnWidth(100),
                          2: FixedColumnWidth(80),
                          3: FixedColumnWidth(120),
                          4: FixedColumnWidth(80),
                          5: FixedColumnWidth(40),
                          6: FixedColumnWidth(20),
                        },
                        children: [
                          // Header row
                          TableRow(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                            ),
                            children: [
                              TableCell(
                                verticalAlignment:
                                    TableCellVerticalAlignment.middle,
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      if (_sortField == 'name') {
                                        _sortAsc = !_sortAsc;
                                      } else {
                                        _sortField = 'name';
                                        _sortAsc = true;
                                      }
                                    });
                                    _filterSheets(
                                      answerSheetProvider.answerSheets,
                                    );
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text('Name'),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.arrow_upward,
                                        size: 16,
                                        color: _sortField == 'name'
                                            ? (_sortAsc
                                                  ? Colors.blue
                                                  : Colors.grey)
                                            : Colors.grey.shade400,
                                      ),
                                      Icon(
                                        Icons.arrow_downward,
                                        size: 16,
                                        color: _sortField == 'name'
                                            ? (!_sortAsc
                                                  ? Colors.blue
                                                  : Colors.grey)
                                            : Colors.grey.shade400,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              TableCell(
                                verticalAlignment:
                                    TableCellVerticalAlignment.middle,
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      if (_sortField == 'createdAt') {
                                        _sortAsc = !_sortAsc;
                                      } else {
                                        _sortField = 'createdAt';
                                        _sortAsc = true;
                                      }
                                    });
                                    _filterSheets(
                                      answerSheetProvider.answerSheets,
                                    );
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text('Created'),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.arrow_upward,
                                        size: 16,
                                        color: _sortField == 'createdAt'
                                            ? (_sortAsc
                                                  ? Colors.blue
                                                  : Colors.grey)
                                            : Colors.grey.shade400,
                                      ),
                                      Icon(
                                        Icons.arrow_downward,
                                        size: 16,
                                        color: _sortField == 'createdAt'
                                            ? (!_sortAsc
                                                  ? Colors.blue
                                                  : Colors.grey)
                                            : Colors.grey.shade400,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              TableCell(
                                verticalAlignment:
                                    TableCellVerticalAlignment.middle,
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      if (_sortField == 'numQuestions') {
                                        _sortAsc = !_sortAsc;
                                      } else {
                                        _sortField = 'numQuestions';
                                        _sortAsc = true;
                                      }
                                    });
                                    _filterSheets(
                                      answerSheetProvider.answerSheets,
                                    );
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text('Num. Questions'),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.arrow_upward,
                                        size: 16,
                                        color: _sortField == 'numQuestions'
                                            ? (_sortAsc
                                                  ? Colors.blue
                                                  : Colors.grey)
                                            : Colors.grey.shade400,
                                      ),
                                      Icon(
                                        Icons.arrow_downward,
                                        size: 16,
                                        color: _sortField == 'numQuestions'
                                            ? (!_sortAsc
                                                  ? Colors.blue
                                                  : Colors.grey)
                                            : Colors.grey.shade400,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              TableCell(
                                verticalAlignment:
                                    TableCellVerticalAlignment.middle,
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      if (_sortField == 'studentIdDigits') {
                                        _sortAsc = !_sortAsc;
                                      } else {
                                        _sortField = 'studentIdDigits';
                                        _sortAsc = true;
                                      }
                                    });
                                    _filterSheets(
                                      answerSheetProvider.answerSheets,
                                    );
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text('Num. Digits ZipGrade ID'),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.arrow_upward,
                                        size: 16,
                                        color: _sortField == 'studentIdDigits'
                                            ? (_sortAsc
                                                  ? Colors.blue
                                                  : Colors.grey)
                                            : Colors.grey.shade400,
                                      ),
                                      Icon(
                                        Icons.arrow_downward,
                                        size: 16,
                                        color: _sortField == 'studentIdDigits'
                                            ? (!_sortAsc
                                                  ? Colors.blue
                                                  : Colors.grey)
                                            : Colors.grey.shade400,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              TableCell(
                                verticalAlignment:
                                    TableCellVerticalAlignment.middle,
                                child: Center(
                                  child: Column(
                                    children: [
                                      Text("For Printing", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                      Text("PDF")
                                    ],
                                  )
                                ),
                              ),
                              TableCell(
                                verticalAlignment:
                                    TableCellVerticalAlignment.middle,
                                child: Center(
                                    child: Column(
                                      children: [
                                        Text("For", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                        Text("Embedding", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                        Text("PNG")
                                      ],
                                    )
                                ),
                              ),
                              TableCell(
                                verticalAlignment:
                                    TableCellVerticalAlignment.middle,
                                child: Center(
                                  child: Icon(
                                    Icons.delete,
                                    color: Colors.transparent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          ...pageData.map(
                            (sheetItem) => TableRow(
                              children: [
                                TableCell(
                                  verticalAlignment:
                                      TableCellVerticalAlignment.middle,
                                  child: Center(
                                    child: Text('${sheetItem.name}'),
                                  ),
                                ),
                                TableCell(
                                  verticalAlignment:
                                      TableCellVerticalAlignment.middle,
                                  child: Center(
                                    child: Text(dateFormat.format(sheetItem.createdAt)),
                                  ),
                                ),
                                TableCell(
                                  verticalAlignment:
                                      TableCellVerticalAlignment.middle,
                                  child: Center(
                                    child: Text('${sheetItem.numQuestions}'),
                                  ),
                                ),
                                TableCell(
                                  verticalAlignment:
                                      TableCellVerticalAlignment.middle,
                                  child: Center(
                                    child: Text('${sheetItem.studentIdDigits}'),
                                  ),
                                ),
                                TableCell(
                                  verticalAlignment:
                                      TableCellVerticalAlignment.middle,
                                  child: Center(
                                    child: IconButton(
                                      onPressed: () async {
                                        final token = Provider.of<AuthProvider>(context, listen: false).token;
                                        try {
                                          final bytes = await AnswerSheetService.downloadAnswerSheetPdf(sheetItem.id, token);
                                          final filename = '${_sanitizeFilename(sheetItem.name)}.pdf';
                                          await _downloadFile(bytes, filename);
                                        } catch (e) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Download failed: $e')),
                                          );
                                        }
                                      },
                                      icon: const Icon(
                                        Icons.picture_as_pdf_rounded,
                                      ),
                                    ),
                                  ),
                                ),
                                TableCell(
                                  verticalAlignment:
                                      TableCellVerticalAlignment.middle,
                                  child: Center(
                                    child: IconButton(
                                      onPressed: () async {
                                        final token = Provider.of<AuthProvider>(context, listen: false).token;
                                        try {
                                          final bytes = await AnswerSheetService.downloadAnswerSheetPng(sheetItem.id, token);
                                          final filename = '${_sanitizeFilename(sheetItem.name)}_preview.png';
                                          await _downloadFile(bytes, filename);
                                        } catch (e) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Download failed: $e')),
                                          );
                                        }
                                      },
                                      icon: const Icon(Icons.image_rounded),
                                    ),
                                  ),
                                ),
                                TableCell(
                                  verticalAlignment:
                                      TableCellVerticalAlignment.middle,
                                  child: Center(
                                    child: IconButton(
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Delete Answer Sheet'),
                                            content: const Text(
                                              'Are you sure you want to delete this custom answer sheet? This will remove the sheet from the mobile app so that it may not be selected for use in a quiz.',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(context).pop(false),
                                                child: const Text('Cancel'),
                                              ),
                                              ElevatedButton(
                                                onPressed: () => Navigator.of(context).pop(true),
                                                child: Text('Delete answer sheet: ${sheetItem.name}'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          try {
                                            await Provider.of<AnswerSheetProvider>(context, listen: false)
                                                .deleteAnswerSheet(context, sheetItem.id);
                                            // Reset filter/search state
                                            setState(() {
                                              _searchText = '';
                                              _searchController.text = '';
                                              _filteredSheets = [];
                                            });
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Answer sheet deleted successfully!')),
                                            );
                                          } catch (e) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Delete failed: $e')),
                                            );
                                          }
                                        }
                                      },
                                      icon: const Icon(Icons.delete),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Text('Showing $start to $end of $total entries'),
                          const Spacer(),
                          Row(
                            children: [
                              TextButton(
                                onPressed: _currentPage > 1
                                    ? () => setState(() => _currentPage = 1)
                                    : null,
                                child: const Text('First'),
                              ),
                              TextButton(
                                onPressed: _currentPage > 1
                                    ? () => setState(() => _currentPage--)
                                    : null,
                                child: const Text('Previous'),
                              ),
                              Text('$_currentPage'),
                              TextButton(
                                onPressed: _currentPage < totalPages
                                    ? () => setState(() => _currentPage++)
                                    : null,
                                child: const Text('Next'),
                              ),
                              TextButton(
                                onPressed: _currentPage < totalPages
                                    ? () => setState(
                                        () => _currentPage = totalPages,
                                      )
                                    : null,
                                child: const Text('Last'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import '../../providers/auth_provider.dart';
import '../../services/student_service.dart';
import 'package:intl/intl.dart';

class StudentDetailScreen extends StatefulWidget {
  final String studentId;
  const StudentDetailScreen({Key? key, required this.studentId}) : super(key: key);

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  bool _isLoading = true;
  String? _error;
  StudentDetailData? _studentDetailData;
  
  // Search and filter
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  Timer? _debounce;
  
  // Sorting
  String _sortField = 'scanned_at';
  bool _sortAsc = false; // Default: newest first
  
  // Pagination
  int _pageSize = 10;
  int _currentPage = 1;
  final List<int> _pageSizeOptions = [10, 25, 50, 100];

  @override
  void initState() {
    super.initState();
    _fetchStudentDetail();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchText = _searchController.text.toLowerCase();
        _currentPage = 1; // Reset to first page when searching
      });
    });
  }

  Future<void> _fetchStudentDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final studentDetail = await StudentService.getStudentDetail(widget.studentId, token);
      setState(() {
        _studentDetailData = studentDetail;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<GradedPaper> get _filteredAndSortedPapers {
    if (_studentDetailData == null) return [];

    var papers = _studentDetailData!.gradedPapers;

    // Apply search filter
    if (_searchText.isNotEmpty) {
      papers = papers.where((paper) {
        final className = paper.className?.toLowerCase() ?? '';
        final examName = paper.examName?.toLowerCase() ?? '';
        final examDate = paper.examDate?.toLowerCase() ?? '';
        final versionCode = paper.versionCode?.toLowerCase() ?? '';
        return className.contains(_searchText) ||
            examName.contains(_searchText) ||
            examDate.contains(_searchText) ||
            versionCode.contains(_searchText);
      }).toList();
    }

    // Apply sorting
    papers.sort((a, b) {
      int comparison = 0;
      switch (_sortField) {
        case 'class':
          comparison = (a.className ?? a.classCode).compareTo(b.className ?? b.classCode);
          break;
        case 'quiz_date':
          comparison = (a.examDate ?? '').compareTo(b.examDate ?? '');
          break;
        case 'quiz':
          comparison = (a.examName ?? a.examId).compareTo(b.examName ?? b.examId);
          break;
        case 'score':
          comparison = (a.score ?? 0).compareTo(b.score ?? 0);
          break;
        case 'percentage':
          comparison = (a.percentage ?? 0).compareTo(b.percentage ?? 0);
          break;
        case 'key':
          comparison = (a.versionCode ?? '').compareTo(b.versionCode ?? '');
          break;
        case 'scanned_at':
        default:
          final aTime = a.scannedAt ?? '';
          final bTime = b.scannedAt ?? '';
          comparison = bTime.compareTo(aTime); // Newest first by default
          break;
      }
      return _sortAsc ? comparison : -comparison;
    });

    return papers;
  }

  List<GradedPaper> get _paginatedPapers {
    final filtered = _filteredAndSortedPapers;
    final start = (_currentPage - 1) * _pageSize;
    final end = start + _pageSize;
    return filtered.sublist(
      start.clamp(0, filtered.length),
      end.clamp(0, filtered.length),
    );
  }

  int get _totalPapers => _filteredAndSortedPapers.length;
  int get _totalPages => (_totalPapers / _pageSize).ceil();
  int get _startIndex => _totalPapers == 0 ? 0 : (_currentPage - 1) * _pageSize + 1;
  int get _endIndex => (_startIndex + _pageSize - 1).clamp(0, _totalPapers);

  void _sortBy(String field) {
    setState(() {
      if (_sortField == field) {
        _sortAsc = !_sortAsc;
      } else {
        _sortField = field;
        _sortAsc = true;
      }
      _currentPage = 1;
    });
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      // Try parsing different date formats
      final date = DateTime.tryParse(dateStr);
      if (date != null) {
        return DateFormat('MMMM d, yyyy').format(date);
      }
      return dateStr; // Return as-is if can't parse
    } catch (e) {
      return dateStr;
    }
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return '-';
    try {
      final date = DateTime.tryParse(timestamp);
      if (date != null) {
        return DateFormat('yyyy/MM/dd hh:mm a').format(date);
      }
      return timestamp;
    } catch (e) {
      return timestamp;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading student detail',
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
                        onPressed: _fetchStudentDetail,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _studentDetailData == null
                  ? const Center(child: Text('No data available'))
                  : _buildContent(),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      child: Container(
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Student Name
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _studentDetailData!.fullName,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            
            // Student Information Section
            _buildStudentInfoSection(),
            
            const Divider(height: 1),
            
            // Graded Papers Section
            _buildGradedPapersSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentInfoSection() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Student ID', _studentDetailData!.studentId),
          _buildInfoRow('External Ref.', ''), // Empty for now
          _buildInfoRow('First Name', _studentDetailData!.firstName),
          _buildInfoRow('Last Name', _studentDetailData!.lastName),
          _buildInfoRow(
            'Classes',
            _studentDetailData!.classes.isEmpty
                ? ''
                : _studentDetailData!.classes.map((c) => c.className).join(', '),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradedPapersSection() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title and Search
          Row(
            children: [
              Text(
                'Graded Papers',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              Row(
                children: [
                  const Text('Search: '),
                  SizedBox(
                    width: 200,
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Table
          _buildPapersTable(),
          
          const SizedBox(height: 16),
          
          // Pagination
          _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildPapersTable() {
    final papers = _paginatedPapers;
    
    if (_totalPapers == 0) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            _searchText.isNotEmpty
                ? 'No graded papers found matching your search'
                : 'No graded papers found',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Table(
        border: TableBorder.all(color: Colors.grey[300]!),
        columnWidths: const {
          0: FlexColumnWidth(1.5), // Class
          1: FlexColumnWidth(1.5), // Quiz Date
          2: FlexColumnWidth(2),   // Quiz
          3: FlexColumnWidth(1),   // Score
          4: FlexColumnWidth(1),   // %
          5: FlexColumnWidth(1),   // Key
          6: FlexColumnWidth(2),   // Timestamp
        },
        children: [
          // Header row
          TableRow(
            decoration: BoxDecoration(color: Colors.grey[200]),
            children: [
              _buildSortableHeader('Class', 'class'),
              _buildSortableHeader('Quiz Date', 'quiz_date'),
              _buildSortableHeader('Quiz', 'quiz'),
              _buildSortableHeader('Score', 'score'),
              _buildSortableHeader('%', 'percentage'),
              _buildSortableHeader('Key', 'key'),
              _buildSortableHeader('Timestamp', 'scanned_at'),
            ],
          ),
          // Data rows
          ...papers.map((paper) => TableRow(
                children: [
                  _buildCell(paper.className ?? paper.classCode),
                  _buildCell(_formatDate(paper.examDate)),
                  _buildCell(
                    paper.examName ?? paper.examId,
                    isClickable: true,
                    onTap: () {
                      // Navigate to quiz detail
                      // context.go('/quizzes/${paper.examId}');
                    },
                  ),
                  _buildCell(paper.score?.toStringAsFixed(1) ?? '-'),
                  _buildCell(paper.percentage != null
                      ? '${paper.percentage!.toStringAsFixed(1)}%'
                      : '-'),
                  _buildCell(paper.versionCode ?? '-'),
                  _buildCell(_formatTimestamp(paper.scannedAt)),
                ],
              )),
        ],
      ),
    );
  }

  Widget _buildSortableHeader(String label, String field) {
    final isActive = _sortField == field;
    return InkWell(
      onTap: () => _sortBy(field),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isActive ? Colors.blue : Colors.black87,
              ),
            ),
            const SizedBox(width: 4),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_upward,
                  size: 14,
                  color: isActive && _sortAsc
                      ? Colors.blue
                      : Colors.grey[400],
                ),
                Icon(
                  Icons.arrow_downward,
                  size: 14,
                  color: isActive && !_sortAsc
                      ? Colors.blue
                      : Colors.grey[400],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCell(String text, {bool isClickable = false, VoidCallback? onTap}) {
    return Container(
      padding: const EdgeInsets.all(12),
      alignment: Alignment.center,
      color: Colors.white,
      child: isClickable && onTap != null
          ? InkWell(
              onTap: onTap,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.description, size: 16, color: Colors.blue),
                  const SizedBox(width: 4),
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            )
          : Text(
              text,
              style: const TextStyle(fontSize: 13),
              textAlign: TextAlign.center,
            ),
    );
  }

  Widget _buildPagination() {
    return Row(
      children: [
        Text('Showing $_startIndex to $_endIndex of $_totalPapers entries'),
        const Spacer(),
        // Page size selector
        Row(
          children: [
            const Text('Show: '),
            DropdownButton<int>(
              value: _pageSize,
              items: _pageSizeOptions.map((size) {
                return DropdownMenuItem(
                  value: size,
                  child: Text('$size'),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _pageSize = value;
                    _currentPage = 1;
                  });
                }
              },
            ),
          ],
        ),
        const SizedBox(width: 16),
        // Page navigation
        TextButton(
          onPressed: _currentPage > 1
              ? () => setState(() => _currentPage--)
              : null,
          child: const Text('Previous'),
        ),
        Text('Page $_currentPage of $_totalPages'),
        TextButton(
          onPressed: _currentPage < _totalPages
              ? () => setState(() => _currentPage++)
              : null,
          child: const Text('Next'),
        ),
      ],
    );
  }
}

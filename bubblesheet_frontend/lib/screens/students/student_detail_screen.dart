import 'package:flutter/material.dart';
import '../../models/class_model.dart';
import '../../services/api_service.dart';

class ClassListScreen extends StatefulWidget {
  const ClassListScreen({super.key});

  @override
  State<ClassListScreen> createState() => _ClassListScreenState();
}

class _ClassListScreenState extends State<ClassListScreen> {
  late Future<List<ClassModel>> _classesFuture;

  @override
  void initState() {
    super.initState();
    // _classesFuture = _fetchClasses();
  }

  // Future<List<ClassModel>> _fetchClasses() async {
  //   final data = await ApiService.getClasses();
  //   return data.map((json) => ClassModel.fromJson(json)).toList();
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Class List')),
      body: FutureBuilder<List<ClassModel>>(
        future: _classesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final classes = snapshot.data ?? [];
          return ListView.builder(
            itemCount: classes.length,
            itemBuilder: (context, index) {
              final classModel = classes[index];
              return ListTile(
                title: Text(classModel.name),
                // onTap: () => ... (xem chi tiết, sửa, xóa)
              );
            },
          );
        },
      ),
    );
  }
}
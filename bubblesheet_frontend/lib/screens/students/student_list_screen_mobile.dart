import 'package:flutter/material.dart';

class StudentListScreenMobile extends StatelessWidget {
  const StudentListScreenMobile({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Students')),
      body: ListView(
        children: const [
          ListTile(title: Text('Student 1')),
          ListTile(title: Text('Student 2')),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
        tooltip: 'Add Student',
      ),
    );
  }
} 
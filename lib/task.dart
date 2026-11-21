import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

const green = Color(0xFF0B5D3B);

/// The single Firestore collection used by the app.
final tasksRef = FirebaseFirestore.instance.collection('tasks');

enum Priority {
  low('Low', Color(0xFF2DA44E)),
  medium('Medium', Color(0xFFF5A524)),
  high('High', Color(0xFFE5484D));

  const Priority(this.label, this.color);
  final String label;
  final Color color;
}

class Task {
  const Task(this.id, this.title, this.note, this.done, this.priority);

  final String id, title, note;
  final bool done;
  final Priority priority;

  factory Task.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data();
    return Task(
      d.id,
      m['title'] ?? '',
      m['note'] ?? '',
      m['done'] ?? false,
      Priority.values[(m['priority'] ?? 1).clamp(0, 2) as int],
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'note': note,
        'done': done,
        'priority': priority.index,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      };
}

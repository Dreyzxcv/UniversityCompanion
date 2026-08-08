import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Task/assignment/exam types shown as filter chips and type badges.
enum TaskType { assignment, exam, project }

extension TaskTypeX on TaskType {
  String get label {
    switch (this) {
      case TaskType.assignment:
        return 'Assignment';
      case TaskType.exam:
        return 'Exam';
      case TaskType.project:
        return 'Project';
    }
  }

  IconData get icon {
    switch (this) {
      case TaskType.assignment:
        return Icons.assignment_outlined;
      case TaskType.exam:
        return Icons.edit_note_rounded;
      case TaskType.project:
        return Icons.folder_open_rounded;
    }
  }

  static TaskType fromName(String name) {
    return TaskType.values.firstWhere(
      (t) => t.name == name,
      orElse: () => TaskType.assignment,
    );
  }
}

class TaskItem {
  final String id;
  final String title;
  final TaskType type;
  final DateTime dueDate;
  final String? classId; // links to a ClassSession, drives color-coding
  final String notes;
  final bool isCompleted;

  TaskItem({
    required this.id,
    required this.title,
    required this.type,
    required this.dueDate,
    this.classId,
    this.notes = '',
    this.isCompleted = false,
  });

  factory TaskItem.fromMap(String id, Map<String, dynamic> map) {
    final ts = map['dueDate'];
    final due = ts is Timestamp ? ts.toDate() : DateTime.now();
    return TaskItem(
      id: id,
      title: map['title'] ?? '',
      type: TaskTypeX.fromName(map['type'] ?? 'assignment'),
      dueDate: due,
      classId: map['classId'] as String?,
      notes: map['notes'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'type': type.name,
      'dueDate': Timestamp.fromDate(dueDate),
      'classId': classId,
      'notes': notes,
      'isCompleted': isCompleted,
    };
  }

  TaskItem copyWith({
    String? title,
    TaskType? type,
    DateTime? dueDate,
    String? classId,
    bool clearClassId = false,
    String? notes,
    bool? isCompleted,
  }) {
    return TaskItem(
      id: id,
      title: title ?? this.title,
      type: type ?? this.type,
      dueDate: dueDate ?? this.dueDate,
      classId: clearClassId ? null : (classId ?? this.classId),
      notes: notes ?? this.notes,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  bool get isOverdue {
    if (isCompleted) return false;
    final now = DateTime.now();
    final dueOnly = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final todayOnly = DateTime(now.year, now.month, now.day);
    return dueOnly.isBefore(todayOnly);
  }

  bool get isDueToday {
    final now = DateTime.now();
    return dueDate.year == now.year &&
        dueDate.month == now.month &&
        dueDate.day == now.day;
  }
}
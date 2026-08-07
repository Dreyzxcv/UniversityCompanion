import 'package:flutter/material.dart';

/// Days are stored as short uppercase codes to match the Firestore schema.
const List<String> kWeekDays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

class ClassSession {
  final String id;
  final String subjectCode;
  final String subjectName;
  final String section;
  final num units;
  final String professor;
  final String day; // MON..SAT
  final String startTime; // "HH:mm"
  final String endTime; // "HH:mm"
  final String room;
  final String color; // hex code, e.g. "#FFB3BA"

  ClassSession({
    required this.id,
    required this.subjectCode,
    required this.subjectName,
    required this.section,
    required this.units,
    required this.professor,
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.room,
    required this.color,
  });

  factory ClassSession.fromMap(String id, Map<String, dynamic> map) {
    return ClassSession(
      id: id,
      subjectCode: map['subjectCode'] ?? '',
      subjectName: map['subjectName'] ?? '',
      section: map['section'] ?? '',
      units: map['units'] ?? 0,
      professor: map['professor'] ?? '',
      day: map['day'] ?? 'MON',
      startTime: map['startTime'] ?? '08:00',
      endTime: map['endTime'] ?? '09:00',
      room: map['room'] ?? '',
      color: map['color'] ?? '#90CAF9',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'subjectCode': subjectCode,
      'subjectName': subjectName,
      'section': section,
      'units': units,
      'professor': professor,
      'day': day,
      'startTime': startTime,
      'endTime': endTime,
      'room': room,
      'color': color,
    };
  }

  /// Minutes since midnight, for easy overlap comparisons.
  int get startMinutes => _toMinutes(startTime);
  int get endMinutes => _toMinutes(endTime);

  static int _toMinutes(String hhmm) {
    final parts = hhmm.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return h * 60 + m;
  }

  bool overlapsWith(ClassSession other) {
    if (day != other.day) return false;
    return startMinutes < other.endMinutes && other.startMinutes < endMinutes;
  }

  Color get colorValue {
    try {
      final hex = color.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return Colors.blueAccent;
    }
  }
}

/// Checks [candidate] against [existing] classes (same term) and returns
/// the list of sessions it conflicts with. Excludes [candidate.id] itself,
/// which matters when editing an existing class.
List<ClassSession> findConflicts(
  ClassSession candidate,
  List<ClassSession> existing,
) {
  return existing
      .where((c) => c.id != candidate.id && c.overlapsWith(candidate))
      .toList();
}

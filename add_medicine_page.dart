// lib/screens/add_medicine_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';

class AddMedicinePage extends StatefulWidget {
  final String patientId;
  const AddMedicinePage({super.key, required this.patientId});

  @override
  State<AddMedicinePage> createState() => _AddMedicinePageState();
}

class _AddMedicinePageState extends State<AddMedicinePage> {
  final _nameCtrl     = TextEditingController();
  final _doseCtrl     = TextEditingController();
  final _durationCtrl = TextEditingController();
  bool _saving = false;
  int  _freq   = 1;
  List<TimeOfDay> _times = [TimeOfDay.now()];

  // BLUE & WHITE THEME
  static const _bg     = Color(0xFF0A1628);
  static const _card   = Color(0xFF0D1F3C);
  static const _accent = Color(0xFF1E90FF);
  static const _accent2= Color(0xFF63B3FF);
  static const _red    = Color(0xFFFF6B6B);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _doseCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveMedicine() async {
    final name     = _nameCtrl.text.trim();
    final dosage   = _doseCtrl.text.trim();
    final duration = _durationCtrl.text.trim();

    if (name.isEmpty) {
      _snack('Please enter medicine name', color: _red);
      return;
    }

    setState(() => _saving = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final patientCode =
          prefs.getString('patient_code') ?? widget.patientId;

      final timesStr = _times
          .map((t) =>
              "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}")
          .join(',');

      final docRef = await FirebaseFirestore.instance
          .collection('medicines')
          .add({
        'patient_code'      : patientCode,
        'name'              : name,
        'dosage'            : dosage.isEmpty ? '—' : dosage,
        'frequency_per_day' : _freq,
        'duration'          : duration.isEmpty ? '—' : duration,
        'times'             : timesStr,
        'status'            : 'pending',
        'source'            : 'manual',
        'created_at'        : FieldValue.serverTimestamp(),
        'start_date'        : DateTime.now().toIso8601String(),
        'time'              : timesStr.split(',').first,
        'date'              : DateTime.now().toIso8601String().substring(0, 10),
        'createdAt'         : DateTime.now().toIso8601String(),
      });

      for (int i = 0; i < _times.length; i++) {
        final t = _times[i];
        int hash = 0;
        for (final char in docRef.id.codeUnits) {
          hash = (hash * 31 + char) & 0x7FFFFFFF;
        }
        final notifId = (hash % 90000) + i;

        await NotificationService.showMedicineReminder(
          id: notifId, medicineName: name, dosage: dosage,
          time:
              "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}",
          firestoreDocId: docRef.id,
        );

        await NotificationService.scheduleDailyReminder(
          id: notifId, medicineName: name, dosage: dosage,
          hour: t.hour, minute: t.minute, firestoreDocId: docRef.id,
        );

        await NotificationService.scheduleMissedCheck(
          notifId: notifId, medicineName: name,
          hour: t.hour, minute: t.minute, minutesAfter: 30,
          firestoreDocId: docRef.id,
        );
      }

      _snack('✅ Medicine added successfully!', color: _accent2);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _snack('❌ Failed to save: $e', color: _red);
    }

    if (mounted) setState(() => _saving = false);
  }

  void _snack(String msg, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: color ?? _card,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _card,
        foregroundColor: Colors.white,
        title: const Text('Add Medicine',
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          _label('Medicine Name *'),
          _field(controller: _nameCtrl, hint: 'e.g. Paracetamol',
              icon: Icons.medication_rounded),
          const SizedBox(height: 16),

          _label('Dosage'),
          _field(controller: _doseCtrl, hint: 'e.g. 500mg',
              icon: Icons.scale_rounded),
          const SizedBox(height: 16),

          _label('Duration'),
          _field(controller: _durationCtrl, hint: 'e.g. 7 days',
              icon: Icons.calendar_today_rounded),
          const SizedBox(height: 16),

          _label('Times per day'),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: Colors.white.withOpacity(0.07))),
            child: Row(children: [
              const Icon(Icons.repeat_rounded,
                  color: Colors.white38, size: 20),
              const SizedBox(width: 12),
              const Text('Frequency',
                  style: TextStyle(color: Colors.white70)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline,
                    color: Colors.white54),
                onPressed: () {
                  if (_freq > 1) {
                    setState(() {
                      _freq--;
                      _times = _times.take(_freq).toList();
                    });
                  }
                },
              ),
              Text('$_freq',
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 18)),
              IconButton(
                icon: const Icon(Icons.add_circle_outline,
                    color: Colors.white54),
                onPressed: () {
                  if (_freq < 6) {
                    setState(() {
                      _freq++;
                      _times.add(TimeOfDay.now());
                    });
                  }
                },
              ),
            ]),
          ),
          const SizedBox(height: 16),

          _label('Reminder Times'),
          ...List.generate(_freq, (i) {
            return GestureDetector(
              onTap: () async {
                final picked = await showTimePicker(
                    context: context, initialTime: _times[i]);
                if (picked != null) setState(() => _times[i] = picked);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: _accent.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: _accent.withOpacity(0.2))),
                child: Row(children: [
                  const Icon(Icons.access_time_rounded,
                      color: _accent, size: 20),
                  const SizedBox(width: 12),
                  Text('Dose ${i + 1}:  ${_times[i].format(context)}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14)),
                  const Spacer(),
                  const Icon(Icons.edit_rounded,
                      color: Colors.white38, size: 16),
                ]),
              ),
            );
          }),

          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _saving ? null : _saveMedicine,
              child: _saving
                  ? const CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2)
                  : const Text('Save Medicine',
                      style: TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: TextStyle(color: Colors.white.withOpacity(0.55),
                fontSize: 12, fontWeight: FontWeight.w600,
                letterSpacing: 0.5)),
      );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) =>
      TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              TextStyle(color: Colors.white.withOpacity(0.25)),
          prefixIcon: Icon(icon, color: Colors.white38, size: 20),
          filled: true,
          fillColor: _card,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 16),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                  color: Colors.white.withOpacity(0.07))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _accent, width: 1.5)),
        ),
      );
}

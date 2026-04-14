// lib/screens/caregiver_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_page.dart';
import '../services/notification_service.dart';

class CaregiverDashboard extends StatefulWidget {
  final String caregiverUid;
  final String caregiverEmail;

  const CaregiverDashboard({
    super.key,
    required this.caregiverUid,
    required this.caregiverEmail,
  });

  @override
  State<CaregiverDashboard> createState() => _CaregiverDashboardState();
}

class _CaregiverDashboardState extends State<CaregiverDashboard> {
  String caregiverName = 'Caregiver';
  int _tab = 0;
  bool _loading = false;
  List<Map<String, dynamic>> patients = [];

  // BLUE & WHITE THEME
  static const _bg     = Color(0xFF0A1628);
  static const _card   = Color(0xFF0D1F3C);
  static const _accent = Color(0xFF1E90FF);
  static const _accent2= Color(0xFF63B3FF);
  static const _red    = Color(0xFFFF6B6B);
  static const _orange = Color(0xFFFFB347);

  List<StreamSubscription<QuerySnapshot>>? _missedListeners;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _missedListeners?.forEach((l) => l.cancel());
    super.dispose();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => caregiverName = prefs.getString('name') ?? 'Caregiver');
    await _loadLinkedPatients();
  }

  Future<void> _loadLinkedPatients() async {
    setState(() => _loading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('caregivers')
          .doc(widget.caregiverUid)
          .get();

      final codes = List<String>.from(doc.data()?['linked_patients'] ?? []);
      final loaded = <Map<String, dynamic>>[];

      for (final code in codes) {
        final data = await _fetchPatientData(code);
        if (data != null) loaded.add(data);
      }

      setState(() => patients = loaded);
      _setupMissedDoseListeners();
    } catch (e) {
      _snack('Load error: $e');
    }
    setState(() => _loading = false);
  }

  void _setupMissedDoseListeners() {
    _missedListeners?.forEach((l) => l.cancel());
    _missedListeners = [];

    for (final p in patients) {
      final code = p['patient_code'] as String;
      final sub = FirebaseFirestore.instance
          .collection('medicines')
          .where('patient_code', isEqualTo: code)
          .where('status', isEqualTo: 'missed')
          .snapshots()
          .listen((snap) {
        for (final change in snap.docChanges) {
          if (change.type == DocumentChangeType.modified ||
              change.type == DocumentChangeType.added) {
            final m = change.doc.data();
            if (m != null && m['status'] == 'missed') {
              NotificationService.showMissedDose(
                id: change.doc.id.hashCode.abs(),
                medicineName: "${p['name']}: ${m['name']} ${m['dosage']}",
              );
            }
          }
        }
        _refreshPatient(code);
      });
      _missedListeners!.add(sub);
    }
  }

  Future<void> _refreshPatient(String code) async {
    final idx = patients.indexWhere((p) => p['patient_code'] == code);
    if (idx == -1) return;
    final updated = await _fetchPatientData(code);
    if (updated != null && mounted) {
      setState(() => patients[idx] = updated);
    }
  }

  Future<Map<String, dynamic>?> _fetchPatientData(String code) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('patient_code', isEqualTo: code)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return null;
      final user = snap.docs.first.data();

      final medsSnap = await FirebaseFirestore.instance
          .collection('medicines')
          .where('patient_code', isEqualTo: code)
          .get();

      final presSnap = await FirebaseFirestore.instance
          .collection('prescriptions')
          .where('patient_code', isEqualTo: code)
          .orderBy('uploaded_at', descending: true)
          .get();

      return {
        'name'         : user['name']  ?? '',
        'email'        : user['email'] ?? '',
        'phone'        : user['phone'] ?? '',
        'patient_code' : code,
        'medicines'    : medsSnap.docs
            .map((d) => {...d.data(), 'id': d.id}).toList(),
        'prescriptions': presSnap.docs.map((d) => d.data()).toList(),
      };
    } catch (e) {
      debugPrint('_fetchPatientData error: $e');
      return null;
    }
  }

  Future<void> _refreshAll() async {
    setState(() => _loading = true);
    final refreshed = <Map<String, dynamic>>[];
    for (final p in patients) {
      final u = await _fetchPatientData(p['patient_code'] as String);
      if (u != null) refreshed.add(u);
    }
    setState(() { patients = refreshed; _loading = false; });
    _snack('✅ Refreshed', color: _accent2);
  }

  void _showConnectDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Connect Patient',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Enter your patient\'s Patient ID\n(format: PAT-XXXXXX)',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.55), fontSize: 13)),
          const SizedBox(height: 14),
          TextField(
            controller: ctrl,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(color: Colors.white,
                fontWeight: FontWeight.bold, letterSpacing: 2),
            decoration: InputDecoration(
              hintText: 'PAT-XXXXXX',
              hintStyle: const TextStyle(
                  color: Colors.white24, letterSpacing: 1),
              filled: true,
              fillColor: Colors.white.withOpacity(0.07),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _accent, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              final code = ctrl.text.trim().toUpperCase();
              Navigator.pop(context);
              await _connectPatient(code);
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  Future<void> _connectPatient(String code) async {
    if (code.isEmpty) { _snack('Enter a Patient ID'); return; }
    if (!code.startsWith('PAT-') || code.length != 10) {
      _snack('❌ Invalid format. Use PAT-XXXXXX'); return;
    }
    if (patients.any((p) => p['patient_code'] == code)) {
      _snack('Patient already linked'); return;
    }
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('patient_code', isEqualTo: code)
          .where('role', isEqualTo: 'patient')
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        _snack('❌ Patient ID not found.');
        setState(() => _loading = false);
        return;
      }

      await FirebaseFirestore.instance
          .collection('caregivers')
          .doc(widget.caregiverUid)
          .set({
        'linked_patients': FieldValue.arrayUnion([code]),
        'email': widget.caregiverEmail,
        'uid'  : widget.caregiverUid,
      }, SetOptions(merge: true));

      final patientData = await _fetchPatientData(code);
      if (patientData != null) {
        setState(() => patients.add(patientData));
        _snack('✅ Connected to ${patientData['name']}!', color: _accent2);
        _setupMissedDoseListeners();
      }
    } catch (e) {
      _snack('Error: $e');
    }
    setState(() => _loading = false);
  }

  Future<void> _disconnectPatient(String code, String patientName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Disconnect Patient',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Remove $patientName from your monitoring list?\nYou can reconnect anytime using their Patient ID.',
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance
          .collection('caregivers')
          .doc(widget.caregiverUid)
          .update({
        'linked_patients': FieldValue.arrayRemove([code]),
      });
      setState(() => patients.removeWhere((p) => p['patient_code'] == code));
      _snack('Disconnected from $patientName', color: _orange);
    } catch (e) {
      _snack('Error: $e');
    }
    setState(() => _loading = false);
  }

  void _snack(String msg, {Color? color}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg), behavior: SnackBarBehavior.floating,
          backgroundColor: color ?? _card));

  int get totalAlerts => patients.fold(0, (s, p) {
    final meds = List<Map<String, dynamic>>.from(p['medicines'] ?? []);
    return s + meds.where((m) => m['status'] == 'missed').length;
  });

  List<Map<String, dynamic>> get allAlerts {
    final list = <Map<String, dynamic>>[];
    for (final p in patients) {
      for (final m in List<Map<String, dynamic>>.from(p['medicines'] ?? [])
          .where((m) => m['status'] == 'missed')) {
        list.add({...m, 'patient_name': p['name']});
      }
    }
    return list;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _bg,
    body: Column(children: [_header(), Expanded(child: _body())]),
    bottomNavigationBar: _nav(),
  );

  Widget _header() => Container(
    decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [_card, const Color(0xFF0A1F3C)]),
        borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(30))),
    child: SafeArea(child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Row(children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_accent, _accent2]),
              borderRadius: BorderRadius.circular(15)),
          child: Center(child: Text(
            caregiverName.isNotEmpty
                ? caregiverName[0].toUpperCase() : 'C',
            style: const TextStyle(color: Colors.white,
                fontWeight: FontWeight.bold, fontSize: 18))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Hello, $caregiverName!', style: const TextStyle(
              color: Colors.white, fontSize: 16,
              fontWeight: FontWeight.bold)),
          Text('Monitoring ${patients.length} patient(s)',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.5), fontSize: 12)),
        ])),
        GestureDetector(
          onTap: _refreshAll,
          child: Container(
            width: 40, height: 40, margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12)),
            child: _loading
                ? const Padding(padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(
                        color: Colors.white60, strokeWidth: 2))
                : const Icon(Icons.refresh_rounded,
                    color: Colors.white60, size: 20),
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SettingsPage())),
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.settings_rounded,
                color: Colors.white60, size: 20),
          ),
        ),
      ]),
    )),
  );

  Widget _body() {
    switch (_tab) {
      case 0: return _patientsTab();
      case 1: return _alertsTab();
      case 2: return _reportsTab();
      default: return _patientsTab();
    }
  }

  Widget _patientsTab() => Column(children: [
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(children: [
        _statChip('${patients.length}', 'Patients', _accent2),
        const SizedBox(width: 10),
        _statChip('$totalAlerts', 'Alerts', _red),
        const Spacer(),
        GestureDetector(
          onTap: _showConnectDialog,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_accent, _accent2]),
                borderRadius: BorderRadius.circular(12)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.link_rounded, color: Colors.white, size: 16),
              SizedBox(width: 4),
              Text('Connect', style: TextStyle(color: Colors.white,
                  fontWeight: FontWeight.bold, fontSize: 13)),
            ]),
          ),
        ),
      ]),
    ),
    const SizedBox(height: 12),
    Expanded(
      child: _loading && patients.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: _accent))
          : patients.isEmpty
              ? _emptyState(
                  'No patients linked yet.\nTap Connect and enter Patient ID.')
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: patients.length,
                  itemBuilder: (_, i) => _patientCard(patients[i], i)),
    ),
  ]);

  Widget _statChip(String val, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
        color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(val, style: TextStyle(color: color,
          fontWeight: FontWeight.w900, fontSize: 16)),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(
          color: color.withOpacity(0.7), fontSize: 12)),
    ]),
  );

  Widget _patientCard(Map<String, dynamic> p, int idx) {
    final meds   = List<Map<String, dynamic>>.from(p['medicines'] ?? []);
    final pres   = List<Map<String, dynamic>>.from(p['prescriptions'] ?? []);
    final taken  = meds.where((m) => m['status'] == 'taken').length;
    final missed = meds.where((m) => m['status'] == 'missed').length;
    final adh    = meds.isEmpty ? 0.0 : taken / meds.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.08))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_accent, _accent2]),
                borderRadius: BorderRadius.circular(14)),
            child: Center(child: Text(
              (p['name'] as String? ?? '').isNotEmpty
                  ? (p['name'] as String)[0].toUpperCase() : 'P',
              style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.bold, fontSize: 18))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p['name'] ?? '', style: const TextStyle(color: Colors.white,
                fontWeight: FontWeight.bold, fontSize: 15)),
            Text(p['email'] ?? '',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.4), fontSize: 12)),
            Text('ID: ${p['patient_code'] ?? ''}',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.3), fontSize: 11)),
          ])),
          if (missed > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: _red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8)),
              child: Text('$missed missed', style: const TextStyle(
                  color: _red, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Text('Adherence', style: TextStyle(
              color: Colors.white.withOpacity(0.5), fontSize: 12)),
          const Spacer(),
          Text('${(adh * 100).toInt()}%', style: TextStyle(
              color: adh > 0.7 ? _accent2 : _orange,
              fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
              value: adh, minHeight: 7, backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(
                  adh > 0.7 ? _accent2 : _orange)),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _outBtn('Medicines (${meds.length})',
              Icons.medication_rounded, _accent,
              () => _viewMedicines(p))),
          const SizedBox(width: 8),
          Expanded(child: _outBtn('Prescriptions (${pres.length})',
              Icons.image_rounded, _accent2,
              () => _viewPrescriptions(p))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: _outBtn('Refresh', Icons.refresh_rounded,
                Colors.white38, () async {
              setState(() => _loading = true);
              final updated =
                  await _fetchPatientData(p['patient_code'] as String);
              if (updated != null) setState(() => patients[idx] = updated);
              setState(() => _loading = false);
              _snack('✅ ${p['name']} refreshed', color: _accent2);
            }),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _outBtn('Disconnect', Icons.link_off_rounded, _red,
                () => _disconnectPatient(
                    p['patient_code'] as String, p['name'] as String)),
          ),
        ]),
      ]),
    );
  }

  Widget _outBtn(String label, IconData icon, Color color,
          VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.2))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color,
                fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
      );

  void _viewMedicines(Map<String, dynamic> p) {
    final meds = List<Map<String, dynamic>>.from(p['medicines'] ?? []);
    showModalBottomSheet(
      context: context, backgroundColor: _card, isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        expand: false, initialChildSize: 0.6,
        builder: (__, sc) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("${p['name']}'s Medicines",
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),
            Expanded(
              child: meds.isEmpty
                  ? const Center(child: Text('No medicines added yet',
                      style: TextStyle(color: Colors.white38)))
                  : ListView.builder(
                      controller: sc, itemCount: meds.length,
                      itemBuilder: (_, i) {
                        final m      = meds[i];
                        final status = m['status'] ?? 'pending';
                        final Color c = status == 'taken' ? _accent2
                            : status == 'missed' ? _red : _orange;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: c.withOpacity(0.2))),
                          child: Row(children: [
                            Icon(Icons.medication_rounded,
                                color: c, size: 22),
                            const SizedBox(width: 12),
                            Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(m['name'] ?? '',
                                  style: const TextStyle(color: Colors.white,
                                      fontWeight: FontWeight.w600)),
                              Text(
                                  '${m['dosage']} • ${m['frequency_per_day'] ?? 1}x/day',
                                  style: TextStyle(
                                      color: Colors.white.withOpacity(0.4),
                                      fontSize: 12)),
                              Text(
                                  '${m['duration'] ?? ''} • ${m['times'] ?? ''}',
                                  style: TextStyle(
                                      color: Colors.white.withOpacity(0.3),
                                      fontSize: 11)),
                            ])),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                  color: c.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8)),
                              child: Text(
                                  status[0].toUpperCase() +
                                      status.substring(1),
                                  style: TextStyle(color: c,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11)),
                            ),
                          ]),
                        );
                      }),
            ),
          ]),
        ),
      ),
    );
  }

  void _viewPrescriptions(Map<String, dynamic> p) {
    final pres = List<Map<String, dynamic>>.from(p['prescriptions'] ?? []);
    showModalBottomSheet(
      context: context, backgroundColor: _card, isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        expand: false, initialChildSize: 0.5,
        builder: (__, sc) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("${p['name']}'s Prescriptions",
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),
            Expanded(
              child: pres.isEmpty
                  ? const Center(child: Text('No prescriptions saved',
                      style: TextStyle(color: Colors.white38)))
                  : ListView.builder(
                      controller: sc, itemCount: pres.length,
                      itemBuilder: (_, i) {
                        final pr = pres[i];
                        return GestureDetector(
                          onTap: () {
                            final url = pr['image_url'] ?? '';
                            if (url.isEmpty) return;
                            showDialog(
                                context: context,
                                builder: (_) => Dialog(
                                  backgroundColor: Colors.black,
                                  insetPadding: const EdgeInsets.all(12),
                                  child: Stack(children: [
                                    InteractiveViewer(
                                        minScale: 0.5, maxScale: 4.0,
                                        child: Image.network(url,
                                            fit: BoxFit.contain)),
                                    Positioned(top: 8, right: 8,
                                      child: GestureDetector(
                                        onTap: () => Navigator.pop(context),
                                        child: Container(
                                          width: 36, height: 36,
                                          decoration: BoxDecoration(
                                              color: Colors.black
                                                  .withOpacity(0.6),
                                              shape: BoxShape.circle),
                                          child: const Icon(
                                              Icons.close_rounded,
                                              color: Colors.white,
                                              size: 20)),
                                      )),
                                  ]),
                                ));
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(14)),
                            child: Row(children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: pr['image_url'] != null &&
                                        pr['image_url']
                                            .toString()
                                            .isNotEmpty
                                    ? Image.network(pr['image_url'],
                                        width: 48, height: 48,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            Container(
                                                width: 48, height: 48,
                                                color: _accent.withOpacity(0.12),
                                                child: const Icon(
                                                    Icons.image_rounded,
                                                    color: _accent, size: 20)))
                                    : Container(
                                        width: 48, height: 48,
                                        color: _accent.withOpacity(0.12),
                                        child: const Icon(
                                            Icons.image_rounded,
                                            color: _accent, size: 20)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                Text(pr['label'] ?? 'Prescription',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600)),
                                Text(pr['uploaded_at']?.toString() ?? '',
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.4),
                                        fontSize: 12)),
                                if ((pr['ocr_text'] ?? '')
                                    .toString()
                                    .isNotEmpty)
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                        color: _accent.withOpacity(0.15),
                                        borderRadius:
                                            BorderRadius.circular(4)),
                                    child: const Text('OCR Extracted',
                                        style: TextStyle(color: _accent,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold)),
                                  ),
                              ])),
                              const Icon(Icons.zoom_in_rounded,
                                  color: Colors.white24, size: 18),
                            ]),
                          ),
                        );
                      }),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _alertsTab() {
    final alerts = allAlerts;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Row(children: [
          const Text('Missed Dose Alerts',
              style: TextStyle(color: Colors.white, fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const Spacer(),
          if (alerts.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: _red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8)),
              child: Text('${alerts.length} alerts',
                  style: const TextStyle(color: _red,
                      fontWeight: FontWeight.bold, fontSize: 12)),
            ),
        ]),
      ),
      Expanded(
        child: alerts.isEmpty
            ? _emptyState('No missed doses! All patients are on track 🎉')
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: alerts.length,
                itemBuilder: (_, i) {
                  final a = alerts[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: _red.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _red.withOpacity(0.2))),
                    child: Row(children: [
                      Container(
                        width: 46, height: 46,
                        decoration: BoxDecoration(
                            color: _red.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(14)),
                        child: const Icon(Icons.warning_amber_rounded,
                            color: _red, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(a['patient_name'] ?? '',
                            style: const TextStyle(color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        Text('Missed: ${a['name']} ${a['dosage']}',
                            style: const TextStyle(
                                color: _red, fontSize: 13)),
                        Text('Time: ${a['times'] ?? '—'}',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 12)),
                      ])),
                    ]),
                  );
                }),
      ),
    ]);
  }

  Widget _reportsTab() => Column(children: [
    const Padding(
      padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Align(alignment: Alignment.centerLeft,
          child: Text('Reports & Analytics',
              style: TextStyle(color: Colors.white, fontSize: 16,
                  fontWeight: FontWeight.bold))),
    ),
    Expanded(
      child: patients.isEmpty
          ? _emptyState('Link patients first to see reports')
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: patients.length,
              itemBuilder: (_, i) => _reportCard(patients[i])),
    ),
  ]);

  Widget _reportCard(Map<String, dynamic> p) {
    final meds    = List<Map<String, dynamic>>.from(p['medicines'] ?? []);
    final taken   = meds.where((m) => m['status'] == 'taken').length;
    final missed  = meds.where((m) => m['status'] == 'missed').length;
    final pending = meds.where((m) => m['status'] == 'pending').length;
    final adh     = meds.isEmpty ? 0.0 : taken / meds.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.08))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(p['name'] ?? '', style: const TextStyle(color: Colors.white,
            fontWeight: FontWeight.bold, fontSize: 15)),
        Text(p['email'] ?? '', style: TextStyle(
            color: Colors.white.withOpacity(0.4), fontSize: 12)),
        const SizedBox(height: 14),
        Row(children: [
          _rStat('${(adh * 100).toInt()}%', 'Adherence', _accent2),
          const SizedBox(width: 8),
          _rStat('$taken',   'Taken',   _accent2),
          const SizedBox(width: 8),
          _rStat('$missed',  'Missed',  _red),
          const SizedBox(width: 8),
          _rStat('$pending', 'Pending', _orange),
        ]),
      ]),
    );
  }

  Widget _rStat(String val, String label, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Text(val, style: TextStyle(color: color,
            fontWeight: FontWeight.w900, fontSize: 14)),
        Text(label, style: TextStyle(
            color: Colors.white.withOpacity(0.4), fontSize: 10)),
      ]),
    ),
  );

  Widget _emptyState(String msg) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.inbox_rounded, color: Colors.white24, size: 60),
      const SizedBox(height: 12),
      Text(msg, textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white38)),
    ]),
  ));

  Widget _nav() => Container(
    decoration: const BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    child: SafeArea(child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _navItem(Icons.people_rounded, 'Patients', 0),
        _navItem(Icons.warning_amber_rounded, 'Alerts', 1,
            badge: totalAlerts),
        _navItem(Icons.bar_chart_rounded, 'Reports', 2),
      ]),
    )),
  );

  Widget _navItem(IconData icon, String label, int idx, {int badge = 0}) {
    final active = _tab == idx;
    return GestureDetector(
      onTap: () => setState(() => _tab = idx),
      child: Stack(clipBehavior: Clip.none, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
              color: active ? _accent.withOpacity(0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(12)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: active ? _accent : Colors.white38, size: 22),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(
                color: active ? _accent : Colors.white38,
                fontSize: 10, fontWeight: FontWeight.w600)),
          ]),
        ),
        if (badge > 0)
          Positioned(top: -2, right: -2,
            child: Container(
              width: 16, height: 16,
              decoration: const BoxDecoration(
                  color: _red, shape: BoxShape.circle),
              child: Center(child: Text('$badge',
                  style: const TextStyle(color: Colors.white,
                      fontSize: 9, fontWeight: FontWeight.bold))),
            )),
      ]),
    );
  }
}

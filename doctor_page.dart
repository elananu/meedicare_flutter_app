// lib/screens/doctor_page.dart
import 'package:flutter/material.dart';
import '../stores/scan_store.dart';

class DoctorPage extends StatefulWidget {
  const DoctorPage({super.key});

  @override
  State<DoctorPage> createState() => _DoctorPageState();
}

class _DoctorPageState extends State<DoctorPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  // BLUE & WHITE THEME
  static const _accent  = Color(0xFF1E90FF);
  static const _accent2 = Color(0xFF63B3FF);

  final List<Map<String, dynamic>> _staticDoctors = [
    {
      "name"     : "Dr. Rajesh Kumar",
      "specialty": "Cardiologist",
      "hospital" : "Apollo Hospital",
      "lastVisit": "12 Mar 2026",
      "nextVisit": "12 Apr 2026",
      "icon"     : Icons.favorite_rounded,
      "color"    : const Color(0xFF1E90FF),
      "rating"   : 4.8,
      "source"   : "static",
    },
    {
      "name"     : "Dr. Priya Sharma",
      "specialty": "Diabetologist",
      "hospital" : "MIOT Hospital",
      "lastVisit": "20 Feb 2026",
      "nextVisit": "20 May 2026",
      "icon"     : Icons.bloodtype_rounded,
      "color"    : const Color(0xFF63B3FF),
      "rating"   : 4.6,
      "source"   : "static",
    },
    {
      "name"     : "Dr. Anand Nair",
      "specialty": "General Physician",
      "hospital" : "Fortis Hospital",
      "lastVisit": "05 Mar 2026",
      "nextVisit": null,
      "icon"     : Icons.local_hospital_rounded,
      "color"    : const Color(0xFF90CAF9),
      "rating"   : 4.5,
      "source"   : "static",
    },
  ];

  final List<Map<String, dynamic>> _appointments = [
    {
      "doctor"   : "Dr. Rajesh Kumar",
      "specialty": "Cardiologist",
      "date"     : "12 Apr 2026",
      "time"     : "10:30 AM",
      "hospital" : "Apollo Hospital",
      "color"    : const Color(0xFF1E90FF),
      "icon"     : Icons.favorite_rounded,
    },
    {
      "doctor"   : "Dr. Priya Sharma",
      "specialty": "Diabetologist",
      "date"     : "20 May 2026",
      "time"     : "02:00 PM",
      "hospital" : "MIOT Hospital",
      "color"    : const Color(0xFF63B3FF),
      "icon"     : Icons.bloodtype_rounded,
    },
  ];

  List<Map<String, dynamic>> get _allDoctors {
    final list = List<Map<String, dynamic>>.from(_staticDoctors);
    for (final sd in ScanStore.doctors) {
      final exists = list.any((d) =>
          d['name'].toString().toLowerCase() == sd.name.toLowerCase());
      if (!exists) {
        list.add({
          "name"     : sd.name,
          "specialty": "Scanned from Prescription",
          "hospital" : sd.hospital,
          "lastVisit": sd.lastVisit,
          "nextVisit": null,
          "icon"     : Icons.document_scanner_rounded,
          "color"    : const Color(0xFF90CAF9),
          "rating"   : null,
          "source"   : "scan",
        });
      }
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    ScanStore.addListener(_onStoreChange);
  }

  @override
  void dispose() {
    _tab.dispose();
    ScanStore.removeListener(_onStoreChange);
    super.dispose();
  }

  void _onStoreChange() { if (mounted) setState(() {}); }

  @override
  Widget build(BuildContext context) {
    final doctors = _allDoctors;
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: Column(children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1565C0), Color(0xFF1E90FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
            borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(32)),
          ),
          child: SafeArea(child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(children: [
                const Icon(Icons.local_hospital_rounded,
                    color: Colors.white, size: 28),
                const SizedBox(width: 10),
                const Expanded(child: Text("My Doctors",
                    style: TextStyle(color: Colors.white, fontSize: 22,
                        fontWeight: FontWeight.bold))),
                if (ScanStore.doctors.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.document_scanner_rounded,
                          color: Colors.white, size: 12),
                      const SizedBox(width: 4),
                      Text("${ScanStore.doctors.length} scanned",
                          style: const TextStyle(color: Colors.white,
                              fontSize: 11, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () =>
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text(
                              "Scan a prescription to add doctors"))),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.add_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
              ]),
            ),
            TabBar(
              controller: _tab,
              indicator: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(12)),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withOpacity(0.6),
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              tabs: [
                Tab(text: "My Doctors (${doctors.length})"),
                Tab(text: "Appointments (${_appointments.length})"),
              ],
            ),
            const SizedBox(height: 12),
          ])),
        ),

        Expanded(child: TabBarView(
          controller: _tab,
          children: [
            doctors.isEmpty
              ? _emptyState(
                  "No doctors yet.\nScan a prescription to add doctors.")
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  itemCount: doctors.length,
                  itemBuilder: (_, i) => _DoctorCard(doctor: doctors[i]),
                ),
            _appointments.isEmpty
              ? _emptyState("No upcoming appointments")
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  itemCount: _appointments.length,
                  itemBuilder: (_, i) =>
                      _AppointmentCard(appt: _appointments[i]),
                ),
          ],
        )),
      ]),
    );
  }

  Widget _emptyState(String msg) => Center(child: Column(
      mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.local_hospital_rounded,
        color: Colors.white24, size: 60),
    const SizedBox(height: 12),
    Text(msg, textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white38)),
  ]));
}

class _DoctorCard extends StatelessWidget {
  final Map<String, dynamic> doctor;
  const _DoctorCard({required this.doctor});

  @override
  Widget build(BuildContext context) {
    final color     = doctor['color'] as Color;
    final isScanned = doctor['source'] == 'scan';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(18)),
              child: Icon(doctor['icon'] as IconData,
                  color: color, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(doctor['name'],
                    style: const TextStyle(color: Colors.white,
                        fontSize: 15, fontWeight: FontWeight.bold))),
                if (isScanned) Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6)),
                  child: Text("Scanned", style: TextStyle(
                      color: color, fontSize: 9,
                      fontWeight: FontWeight.bold)),
                ),
              ]),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(doctor['specialty'],
                    style: TextStyle(color: color, fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.location_on_rounded,
                    size: 12, color: Colors.white38),
                const SizedBox(width: 3),
                Expanded(child: Text(doctor['hospital'],
                    style: const TextStyle(color: Colors.white38,
                        fontSize: 12),
                    overflow: TextOverflow.ellipsis)),
              ]),
            ])),
            if (doctor['rating'] != null)
              Column(children: [
                const Icon(Icons.star_rounded,
                    color: Color(0xFFFFB347), size: 18),
                Text("${doctor['rating']}",
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 13)),
              ]),
          ]),

          const SizedBox(height: 14),
          Divider(color: Colors.white.withOpacity(0.06), height: 1),
          const SizedBox(height: 12),

          Row(children: [
            _visitChip("Last Visit", doctor['lastVisit'] ?? "—",
                const Color(0xFF63B3FF)),
            const SizedBox(width: 10),
            if (doctor['nextVisit'] != null)
              _visitChip("Next Visit", doctor['nextVisit'],
                  const Color(0xFF1E90FF))
            else
              _visitChip("No upcoming", "Book now", Colors.orange),
          ]),
        ]),
      ),
    );
  }

  Widget _visitChip(String label, String? value, Color color) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(
            color: Colors.white.withOpacity(0.4), fontSize: 10)),
        const SizedBox(height: 2),
        Text(value ?? '', style: TextStyle(color: color,
            fontWeight: FontWeight.bold, fontSize: 12)),
      ]),
    ));
  }
}

class _AppointmentCard extends StatelessWidget {
  final Map<String, dynamic> appt;
  const _AppointmentCard({required this.appt});

  @override
  Widget build(BuildContext context) {
    final color = appt['color'] as Color;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 56,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              Text(appt['date'].toString().split(' ')[0],
                  style: TextStyle(color: color,
                      fontWeight: FontWeight.bold, fontSize: 16)),
              Text(appt['date'].toString().split(' ')[1],
                  style: TextStyle(color: color, fontSize: 11)),
              Text(appt['date'].toString().split(' ')[2],
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 10)),
            ]),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(appt['doctor'], style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold,
                fontSize: 14)),
            const SizedBox(height: 3),
            Text(appt['specialty'],
                style: TextStyle(color: color, fontSize: 12)),
            const SizedBox(height: 3),
            Row(children: [
              const Icon(Icons.access_time_rounded,
                  size: 12, color: Colors.white38),
              const SizedBox(width: 4),
              Text(appt['time'],
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 12)),
              const SizedBox(width: 10),
              const Icon(Icons.location_on_rounded,
                  size: 12, color: Colors.white38),
              const SizedBox(width: 4),
              Expanded(child: Text(appt['hospital'],
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 12))),
            ]),
          ])),
          const Icon(Icons.chevron_right_rounded, color: Colors.white24),
        ]),
      ),
    );
  }
}

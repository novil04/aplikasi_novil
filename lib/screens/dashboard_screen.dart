import 'package:flutter/material.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  DashboardScreenState createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  double suhu = 45.2;
  double berat = 350;

  bool pemanasKipasIn = false; // satu tombol untuk pemanas & kipas in
  bool kipasOut = false;

  final double suhuMaxKipasOut = 60.0;

  bool get kipasOutOtomatis => suhu >= suhuMaxKipasOut;

  void _logout() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Color warnaStatus(bool status) => status ? Colors.green : Colors.red;

  Widget kartuStatus(String label, bool status, {String? keterangan}) {
    return Card(
      elevation: 4,
      child: ListTile(
        leading: Icon(
          status ? Icons.check_circle : Icons.cancel,
          color: warnaStatus(status),
          size: 36,
        ),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              status ? "$label ON" : "$label OFF",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: warnaStatus(status),
              ),
            ),
            if (keterangan != null)
              Text(keterangan,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool statusKipasOut = kipasOutOtomatis ? true : kipasOut;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Monitoring Pengering Ikan"),
        centerTitle: true,
      ),

      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Colors.blue),
              accountName: const Text("Operator",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              accountEmail: const Text("operator@pengering.com"),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 40, color: Colors.blue),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard, color: Colors.blue),
              title: const Text("Dashboard"),
              onTap: () => Navigator.pop(context),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("Logout",
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("Konfirmasi Logout"),
                    content: const Text("Apakah Anda yakin ingin keluar?"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text("Batal"),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: _logout,
                        child: const Text("Logout",
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
              },
            ),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text("v1.0.0 - Pengering Ikan",
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),
          ],
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 10),

            // ── Sensor Suhu ──────────────────────────────────────
            Card(
              elevation: 4,
              color: suhu >= suhuMaxKipasOut ? Colors.red.shade50 : null,
              child: ListTile(
                leading: Icon(Icons.thermostat,
                    color: suhu >= suhuMaxKipasOut ? Colors.red : Colors.deepOrange,
                    size: 36),
                title: const Text("Suhu"),
                subtitle: Text(
                  "$suhu °C",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: suhu >= suhuMaxKipasOut ? Colors.red : Colors.black,
                  ),
                ),
                trailing: suhu >= suhuMaxKipasOut
                    ? const Icon(Icons.warning_amber_rounded,
                        color: Colors.red, size: 28)
                    : null,
              ),
            ),

            const SizedBox(height: 10),

            // ── Sensor Berat ─────────────────────────────────────
            Card(
              elevation: 4,
              child: ListTile(
                leading: const Icon(Icons.scale, color: Colors.teal, size: 36),
                title: const Text("Berat Ikan"),
                subtitle: Text(
                  "$berat gram",
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Tombol ON/OFF Pemanas & Kipas In ─────────────────
            GestureDetector(
              onTap: () => setState(() => pemanasKipasIn = !pemanasKipasIn),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: pemanasKipasIn ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: (pemanasKipasIn ? Colors.green : Colors.red)
                          // ignore: deprecated_member_use
                          .withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      pemanasKipasIn ? Icons.power : Icons.power_off,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      pemanasKipasIn
                          ? "Pemanas & Kipas In ON"
                          : "Pemanas & Kipas In OFF",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Status Perangkat ─────────────────────────────────
            kartuStatus("Pemanas", pemanasKipasIn),
            const SizedBox(height: 8),
            kartuStatus("Kipas In", pemanasKipasIn),
            const SizedBox(height: 8),
            kartuStatus(
              "Kipas Out",
              statusKipasOut,
              keterangan: kipasOutOtomatis
                  ? "⚡ Otomatis ON — Suhu mencapai $suhuMaxKipasOut°C"
                  : null,
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
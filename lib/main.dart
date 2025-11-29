import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IoT Device Dashboard',
      debugShowCheckedModeBanner: false,
      home: const IoTDeviceDashboard(),
    );
  }
}

class IoTDeviceDashboard extends StatefulWidget {
  const IoTDeviceDashboard({super.key});
  @override
  State<IoTDeviceDashboard> createState() => _IoTDeviceDashboardState();
}

class _IoTDeviceDashboardState extends State<IoTDeviceDashboard> {
  final _baseUrl = 'http://172.20.10.12:8080';

  List<Device> _devices = [];

  final _deviceNameController = TextEditingController();
  final _deviceTopicController = TextEditingController();

  // map id → controller để mỗi thiết bị có ô input riêng
  final Map<int, TextEditingController> _payloadControllers = {};

  @override
  void initState() {
    super.initState();
    fetchDevices();
  }

  // lấy danh sách thiết bị
  Future<void> fetchDevices() async {
    final response = await http.get(Uri.parse('$_baseUrl/devices'));
    if (response.statusCode == 200) {
      final List list = json.decode(response.body);
      setState(() {
        _devices = list.map((json) => Device.fromJson(json)).toList();

        // tạo controller riêng cho từng thiết bị
        for (var d in _devices) {
          _payloadControllers[d.id] = TextEditingController();
        }
      });
    }
  }

  // tạo thiết bị mới
  Future<void> createDevice() async {
    if (_deviceNameController.text.isEmpty ||
        _deviceTopicController.text.isEmpty) return;

    final response = await http.post(
      Uri.parse('$_baseUrl/devices'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'name': _deviceNameController.text,
        'topic': _deviceTopicController.text,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      _deviceNameController.clear();
      _deviceTopicController.clear();
      fetchDevices();
    }
  }

  // gửi lệnh điều khiển
  Future<void> controlDevice(int id) async {
    final controller = _payloadControllers[id];
    if (controller == null) return;

    final response = await http.post(
      Uri.parse('$_baseUrl/devices/$id/control'),
      headers: {'Content-Type': 'text/plain'},
      body: controller.text,
    );

    if (response.statusCode == 200 && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Lệnh đã gửi')));
    }
  }

  // xem telemetry
  Future<void> _showTelemetryDialog(int id, String name) async {
    final telemetries = await fetchTelemetry(id);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Telemetry • $name"),
        content: SizedBox(
          width: double.maxFinite,
          child: telemetries.isEmpty
              ? const Text("Không có dữ liệu")
              : ListView(
                  shrinkWrap: true,
                  children: telemetries
                      .map((t) => ListTile(
                            title: Text(t.payload),
                            subtitle: Text(t.timestamp),
                          ))
                      .toList(),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Đóng"),
          )
        ],
      ),
    );
  }

  Future<List<Telemetry>> fetchTelemetry(int deviceId) async {
    final response =
        await http.get(Uri.parse("$_baseUrl/telemetry/$deviceId"));
    if (response.statusCode == 200) {
      final List list = json.decode(response.body);
      return list.map((j) => Telemetry.fromJson(j)).toList();
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: const [
                Icon(Icons.memory, color: Colors.blue, size: 30),
                SizedBox(width: 8),
                Text(
                  "IoT Device Dashboard",
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),

            const SizedBox(height: 20),
            const Text(
              "📋 Danh sách thiết bị",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // danh sách thiết bị
            ..._devices.map((d) => _buildDeviceCard(d)),
            const SizedBox(height: 20),

            // thêm thiết bị mới
            const Text(
              "➕ Thêm thiết bị mới",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            _buildInput(_deviceNameController, "Tên thiết bị"),
            const SizedBox(height: 10),
            _buildInput(_deviceTopicController, "Topic MQTT"),

            const SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade100,
                foregroundColor: Colors.green.shade800,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: createDevice,
              child: const Text("+  Tạo thiết bị"),
            ),
          ],
        ),
      ),
    );
  }

  // widget ô input
  Widget _buildInput(TextEditingController c, String label) {
    return TextField(
      controller: c,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
      ),
    );
  }

  // card hiển thị thiết bị
  Widget _buildDeviceCard(Device d) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(d.name,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold)),
          Text(
            "MQTT Topic: ${d.topic}",
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 10),

          // ô nhập lệnh
          TextField(
            controller: _payloadControllers[d.id],
            decoration: InputDecoration(
              hintText: "Lệnh điều khiển",
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),

          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade100,
                  foregroundColor: Colors.green.shade800,
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: () => controlDevice(d.id),
                icon: const Icon(Icons.send),
                label: const Text("Gửi lệnh"),
              ),
              InkWell(
                onTap: () => _showTelemetryDialog(d.id, d.name),
                child: Text(
                  "Xem dữ liệu",
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            ],
          )
        ],
      ),
    );
  }
}

class Device {
  final int id;
  final String name;
  final String topic;
  Device({required this.id, required this.name, required this.topic});

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'],
      name: json['name'],
      topic: json['topic'],
    );
    }
}

class Telemetry {
  final String timestamp;
  final String payload;
  Telemetry({required this.timestamp, required this.payload});

  factory Telemetry.fromJson(Map<String, dynamic> json) {
    return Telemetry(
      timestamp: json['timestamp'],
      payload: json['payload'],
    );
  }
}

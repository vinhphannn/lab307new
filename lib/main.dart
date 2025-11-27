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
      home: const IoTDeviceDashboard(),
      debugShowCheckedModeBanner: false,
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
  final _payloadController = TextEditingController();
  @override
  void initState() {
    super.initState();
    fetchDevices();
  }

  Future<void> fetchDevices() async {
    final response = await http.get(Uri.parse('$_baseUrl/devices'));
    if (response.statusCode == 200) {
      final List list = json.decode(response.body);
      setState(() {
        _devices = list.map((json) => Device.fromJson(json)).toList();
      });
    }
  }

  Future<void> createDevice() async {
    if (_deviceNameController.text.isEmpty ||
        _deviceTopicController.text.isEmpty)
      return;
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

  Future<void> controlDevice(int id) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/devices/$id/control'),
      headers: {'Content-Type': 'text/plain'},
      body: _payloadController.text,
    );
    if (response.statusCode == 200 && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lệnh đã gửi')));
    }
  }

  Future<void> _showTelemetryDialog(int deviceId, String deviceName) async {
    List<Telemetry> telemetries = await fetchTelemetry(deviceId);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Telemetry - $deviceName'),
        content: SizedBox(
          width: double.maxFinite,
          child: telemetries.isEmpty
              ? const Text('Không có dữ liệu')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: telemetries.length,
                  itemBuilder: (context, index) {
                    final t = telemetries[index];
                    return ListTile(
                      title: Text(t.payload),
                      subtitle: Text(t.timestamp),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Future<List<Telemetry>> fetchTelemetry(int deviceId) async {
    final response = await http.get(Uri.parse('$_baseUrl/telemetry/$deviceId'));
    if (response.statusCode == 200) {
      final List list = json.decode(response.body);
      return list.map((json) => Telemetry.fromJson(json)).toList();
    } else {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IoT Device Dashboard'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text(
              '📋 Danh sách thiết bị',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            ..._devices.map(
              (d) => Card(
                color: Colors.blue.shade50,
                child: ListTile(
                  title: Text(d.name),
                  subtitle: Text(d.topic),
                  trailing: ElevatedButton(
                    onPressed: () => controlDevice(d.id),
                    child: const Text('Gửi lệnh'),
                  ),
                  onTap: () => _showTelemetryDialog(d.id, d.name),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              ' Thêm thiết bị mới',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: _deviceNameController,
              decoration: const InputDecoration(labelText: 'Tên thiết bị'),
            ),
            TextField(
              controller: _deviceTopicController,
              decoration: const InputDecoration(labelText: 'Topic MQTT'),
            ),
            ElevatedButton(
              onPressed: createDevice,
              child: const Text('Tạo thiết bị'),
            ),
            const SizedBox(height: 20),
            const Text(
              ' Nhập lệnh điều khiển',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: _payloadController,
              decoration: const InputDecoration(hintText: '{data:20}'),
            ),
          ],
        ),
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
    return Device(id: json['id'], name: json['name'], topic: json['topic']);
  }
}

class Telemetry {
  final String timestamp;
  final String payload;
  Telemetry({required this.timestamp, required this.payload});
  factory Telemetry.fromJson(Map<String, dynamic> json) {
    return Telemetry(timestamp: json['timestamp'], payload: json['payload']);
  }
}

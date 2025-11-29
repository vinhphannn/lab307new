import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
  String _baseUrl = ''; // ip máy chủ được load từ SharedPreferences
  List<Device> _devices = [];

  final _deviceNameController = TextEditingController();
  final _deviceTopicController = TextEditingController();

  // mỗi thiết bị có 1 controller riêng
  final Map<int, TextEditingController> _payloadControllers = {};

  @override
  void initState() {
    super.initState();
    _loadServerIp();
  }

  // lấy IP máy chủ từ SharedPreferences
  Future<void> _loadServerIp() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIp = prefs.getString('server_ip');

    if (savedIp == null) {
      _openIpDialog(firstOpen: true);
    } else {
      setState(() => _baseUrl = savedIp);
      fetchDevices();
    }
  }

  // lưu IP vào SharedPreferences
  Future<void> _saveServerIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_ip', ip);
    setState(() => _baseUrl = ip);
    fetchDevices();
  }

  // popup nhập IP
  Future<void> _openIpDialog({bool firstOpen = false}) async {
    final controller = TextEditingController(text: _baseUrl);

    showDialog(
      context: context,
      barrierDismissible: !firstOpen,
      builder: (context) => AlertDialog(
        title: const Text('Nhập IP máy chủ'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
              hintText: 'VD: http://192.168.1.10:8080'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (!firstOpen) Navigator.pop(context);
            },
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              final ip = controller.text.trim();
              if (ip.isNotEmpty) {
                _saveServerIp(ip);
                Navigator.pop(context);
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  // lấy danh sách thiết bị
  Future<void> fetchDevices() async {
    if (_baseUrl.isEmpty) return;

    final response = await http.get(Uri.parse('$_baseUrl/devices'));
    if (response.statusCode == 200) {
      final List list = json.decode(response.body);

      setState(() {
        _devices = list.map((json) => Device.fromJson(json)).toList();

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
    if (_baseUrl.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("IoT Device Dashboard"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _openIpDialog(),
          )
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              "Danh sách thiết bị",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),
            ..._devices.map((d) => _buildDeviceCard(d)),
            const SizedBox(height: 20),

            const Text(
              "Thêm thiết bị mới",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),
            _buildInput(_deviceNameController, "Tên thiết bị"),
            const SizedBox(height: 10),
            _buildInput(_deviceTopicController, "Topic MQTT"),

            const SizedBox(height: 10),
            ElevatedButton(
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
          Text("MQTT Topic: ${d.topic}",
              style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 10),

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
                onPressed: () => controlDevice(d.id),
                icon: const Icon(Icons.send),
                label: const Text("Gửi lệnh"),
              ),
              InkWell(
                onTap: () => _showTelemetryDialog(d.id, d.name),
                child: Text("Xem dữ liệu",
                    style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w600)),
              )
            ],
          )
        ],
      ),
    );
  }
}

// model Device
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

// model Telemetry
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

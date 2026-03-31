import 'package:flutter/material.dart';
import 'package:supermarket/core/utils/printer_helper.dart';

class PrinterSettingsPage extends StatefulWidget {
  const PrinterSettingsPage({super.key});

  @override
  State<PrinterSettingsPage> createState() => _PrinterSettingsPageState();
}

class _PrinterSettingsPageState extends State<PrinterSettingsPage> {
  List<dynamic> _devices = [];
  dynamic _selectedDevice;
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    List<dynamic> devices = await PrinterHelper.getAvailableDevices();
    bool connected = await PrinterHelper.isConnected();
    setState(() {
      _devices = devices;
      _connected = connected;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Printer Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButton<dynamic>(
              hint: const Text("Select Device"),
              value: _selectedDevice,
              items: _devices.map((device) {
                return DropdownMenuItem(
                  value: device,
                  child: Text(device.name ?? "Unknown"),
                );
              }).toList(),
              onChanged: (device) {
                setState(() {
                  _selectedDevice = device;
                });
              },
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _connected
                      ? null
                      : () async {
                          if (_selectedDevice != null) {
                            await PrinterHelper.connect(_selectedDevice!);
                            _loadDevices();
                          }
                        },
                  child: const Text("Connect"),
                ),
                ElevatedButton(
                  onPressed: !_connected
                      ? null
                      : () async {
                          await PrinterHelper.disconnect();
                          _loadDevices();
                        },
                  child: const Text("Disconnect"),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text("Status: ${_connected ? 'Connected' : 'Disconnected'}"),
          ],
        ),
      ),
    );
  }
}

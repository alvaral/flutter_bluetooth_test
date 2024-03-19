import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_test/service_dropdown.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BLE Scanner',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final FlutterReactiveBle reactiveBle = FlutterReactiveBle();
  final List<DiscoveredDevice> _discoveredDevices = [];
  bool _isScanning = false; // Flag to track scanning state
  DiscoveredDevice? _selectedDevice; // Selected device for connection
  List<Service> _services = [];
  late StreamSubscription<ConnectionStateUpdate> _connectionSubscription;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  @override
  dispose() {
    super.dispose();
    _connectionSubscription?.cancel();
  }

  Future<void> _requestPermissions() async {
    // Request all necessary permissions in parallel:
    var statuses = await [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    // Evaluate granted permissions:
    _isScanning = statuses[Permission.location] == PermissionStatus.granted &&
        statuses[Permission.bluetoothScan] == PermissionStatus.granted &&
        statuses[Permission.bluetoothConnect] == PermissionStatus.granted;

    // Optionally handle individual permission statuses for more granular feedback
  }

  Future<void> _startScan() async {
    await _requestPermissions();

    if (_isScanning) {
      try {
        reactiveBle.scanForDevices(withServices: [Uuid.parse('181A')]).listen(
            (device) {
          setState(() {
            _discoveredDevices.add(device);
          });
        });
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error scanning for devices: $error'),
          ),
        );
      }
    }
  }

  Future<void> _connectToDevice(DiscoveredDevice device) async {
    try {
      log('connect to device ${device.id}');
      await reactiveBle.connectToDevice(id: device.id);
      setState(() {
        _selectedDevice = device;
      });
      await reactiveBle
          .getDiscoveredServices(device.id)
          .then((discoveredServices) {
        setState(() {
          _services = discoveredServices;
        });
        for (Service d in discoveredServices) {
          log(d.characteristics.toString());
        }
      });
      _showServicesAndCharacteristics(device); // Call to show modal
    } catch (error) {
      debugPrint('Error connecting to device: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error connecting to device: $error'),
        ),
      );
    }
  }

  void _showServicesAndCharacteristics(DiscoveredDevice device) async {
    final serviceUUIDList = device.serviceUuids;

    // Show modal with list of services (replace with your desired modal implementation)
    // ignore: use_build_context_synchronously
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Device: ${device.name ?? 'Unnamed Device'}'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                for (var serviceUUID in serviceUUIDList)
                  ListTile(
                    title: Text(serviceUUID.toString()),
                    onTap: () =>
                        _showCharacteristics(device, serviceUUID.toString()),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showCharacteristics(DiscoveredDevice device, String serviceUUID) async {
    try {
      final characteristics =
          await reactiveBle.characteristicValueStream.listen((data) {
        log(data.toString());
      });

      final characteristic = QualifiedCharacteristic(
          serviceId: Uuid.parse(serviceUUID),
          characteristicId: Uuid.parse('2a6e'),
          deviceId: device.id);

      final response = await reactiveBle.readCharacteristic(characteristic);
      log(response.toString());

      // final characteristic = QualifiedCharacteristic(
      //     serviceId: serviceUuid,
      //     characteristicId: characteristicUuid,
      //     deviceId: foundDeviceId);
      // final response =
      //     await flutterReactiveBle.readCharacteristic(characteristic);

      // showDialog(
      //   context: context,
      //   builder: (BuildContext context) {
      //     return AlertDialog(
      //       title: Text('Service UUID: $serviceUUID'),
      //       content: SingleChildScrollView(
      //         child: Column(
      //           children: [
      //             for (var characteristic in characteristics)
      //               ListTile(
      //                 title:
      //                     Text('Characteristic UUID: ${characteristic.uuid}'),
      //                 subtitle: Text('Value: ${characteristic.value}'),
      //               ),
      //           ],
      //         ),
      //       ),
      //       actions: [
      //         TextButton(
      //           onPressed: () => Navigator.pop(context),
      //           child: const Text('Close'),
      //         ),
      //       ],
      //     );
      //   },
      // );
    } catch (error) {
      debugPrint('Error loading characteristics: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading characteristics: $error'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Scanner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _startScan,
          ),
        ],
      ),
      body: _discoveredDevices.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _discoveredDevices.length,
              itemBuilder: (context, index) {
                final device = _discoveredDevices[index];
                return ListTile(
                  title: Text(device.name ?? 'Unnamed Device'),
                  subtitle: Text(device.id.toString()),
                  onTap: () => _connectToDevice(device),
                );
              },
            ),
    );
  }
}

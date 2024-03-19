import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_test/main.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

class ServiceDropdown extends StatefulWidget {
  final String serviceUUID;
  final DiscoveredDevice device;

  const ServiceDropdown({
    required this.serviceUUID,
    required this.device,
    Key? key,
  }) : super(key: key);

  @override
  _ServiceDropdownState createState() => _ServiceDropdownState();
}

class _ServiceDropdownState extends State<ServiceDropdown> {
  List<Characteristic> _characteristics = [];
  Characteristic? _selectedCharacteristic;
  final FlutterReactiveBle reactiveBle = FlutterReactiveBle();

  @override
  void initState() {
    super.initState();
    _loadCharacteristics();
  }

  Future<void> _loadCharacteristics() async {
    try {
      final characteristic = QualifiedCharacteristic(
          serviceId: Uuid.parse(widget.serviceUUID),
          characteristicId: Uuid.parse('0x2a6e'),
          deviceId: widget.device.id);
      final response = await reactiveBle.readCharacteristic(characteristic);
      log(response.toString());
    } catch (error) {
      debugPrint('Error loading characteristics: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          title: Text('UUID: ${widget.serviceUUID}'),
          subtitle: _characteristics.isEmpty
              ? CircularProgressIndicator()
              : DropdownButtonFormField<Characteristic>(
                  value: _selectedCharacteristic,
                  items: _characteristics
                      .map((characteristic) => DropdownMenuItem<Characteristic>(
                            value: characteristic,
                            child: Text(characteristic.id.toString()),
                          ))
                      .toList(),
                  onChanged: (characteristic) {
                    setState(() {
                      _selectedCharacteristic = characteristic;
                    });
                  },
                ),
        ),
        if (_selectedCharacteristic != null) ...[
          ListTile(
            title: Text('Characteristic UUID: ${_selectedCharacteristic!.id}'),
            subtitle: Text('Value: ${_selectedCharacteristic!}'),
          ),
          // Add more ListTile widgets here for additional characteristic properties
        ],
      ],
    );
  }
}

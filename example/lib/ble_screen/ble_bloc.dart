import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:esp_provisioning_example/ble_service.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:rxdart/rxdart.dart';
import 'ble.dart';

class BleBloc extends Bloc<BleEvent, BleState> {
  var bleService = BleService.getInstance();
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  List<Map<String, dynamic>> bleDevices = [];

  BleBloc(BleState initialState) : super(initialState) {
    on<BleEventStart>((event, emit) async {
      var permissionIsGranted = await bleService.requestBlePermissions();
      if (!permissionIsGranted) {
        add(BleEventPermissionDenied());
        return;
      }
      var bleState = await bleService.start();
      if (bleState == BluetoothAdapterState.unauthorized) {
        add(BleEventPermissionDenied());
        return;
      }
      await _scanSubscription?.cancel();
      _scanSubscription = bleService
          .scanBle()
          .debounceTime(Duration(milliseconds: 100))
          .listen((List<ScanResult> scanResults) {
            for (var scanResult in scanResults) {
              var bleDevice = BleDevice(scanResult);
              if (bleDevice.name != "Unknown") {
                var idx = bleDevices.indexWhere((e) => e['id'] == bleDevice.id);
                if (idx < 0) {
                  bleDevices.add(bleDevice.toMap());
                } else {
                  bleDevices[idx] = bleDevice.toMap();
                }
              }
            }
            add(BleEventDeviceUpdated(bleDevices));
          });
    });

    on<BleEventDeviceUpdated>((event, emit) {
      emit(BleStateLoaded(List.from(event.bleDevices)));
    });

    on<BleEventSelect>((event, emit) {
      bleService.select(event.selectedDevice['device']);
    });

    on<BleEventStopScan>((event, emit) async {
      await bleService.stopScanBle();
    });
  }

  @override
  Future<void> close() async {
    await _scanSubscription?.cancel();
    await bleService.stopScanBle();
    return super.close();
  }
}

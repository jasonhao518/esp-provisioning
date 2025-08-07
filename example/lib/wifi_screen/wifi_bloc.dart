import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:esp_provisioning/esp_provisioning.dart';
import 'package:logger/logger.dart';
import '../ble_service.dart';
import './wifi.dart';

class WifiBloc extends Bloc<WifiEvent, WifiState> {
  final bleService = BleService.getInstance();
  EspProv? prov;
  Logger log = Logger(printer: PrettyPrinter());

  WifiBloc(WifiState initialState) : super(initialState) {
    on<WifiEventLoad>((event, emit) async {
      emit(WifiStateConnecting());
      log.i('Emitted WifiStateConnecting');
      try {
        prov = await bleService.startProvisioning();
        log.i('Provisioning started');
      } catch (e) {
        log.e('Error connecting to device: $e');
        emit(WifiStateError('Error connecting to device'));
        return;
      }
      emit(WifiStateScanning());
      log.i('Emitted WifiStateScanning');
      // Add a delay before starting scan
      await Future.delayed(Duration(seconds: 1));
      try {
        if (prov == null) {
          log.e('prov is null before scanning WiFi');
          emit(WifiStateError('Internal error: prov not initialized'));
          return;
        }
        var listWifi = await prov!.startScanWiFi();
        log.i('WiFi scan complete: $listWifi');
        List<Map<String, dynamic>> mapListWifi = [];
        for (var element in listWifi) {
          mapListWifi.add({
            'ssid': element.ssid,
            'rssi': element.rssi,
            'auth': element.private.toString() != 'Open',
          });
        }
        emit(WifiStateLoaded(wifiList: mapListWifi));
        log.v('Wifi $listWifi');
      } catch (e, stack) {
        log.e('Error scan WiFi network: $e\n$stack');
        emit(WifiStateError('Error scan WiFi network'));
      }
    });

    on<WifiEventStartProvisioning>((event, emit) async {
      emit(WifiStateProvisioning());
      await prov?.sendWifiConfig(ssid: event.ssid, password: event.password);
      await prov?.applyWifiConfig();
      for(int i = 0; i < 10; i++) {
        var status = await prov?.getStatus();
        if (status?.state == WifiConnectionState.Connected) {
          log.i('Device connected successfully');
          break;
        }
        log.w('Waiting for device to connect... Attempt $i');
        await Future.delayed(Duration(seconds: 1));
      }
      emit(WifiStateProvisioned());
    });
  }

  @override
  Future<void> close() async {
    await prov?.dispose();
    return super.close();
  }
}

import 'dart:async';
import 'dart:io' show InternetAddressType;
import 'package:nsd/nsd.dart' as nsd;

class DiscoveredHost {
  final String name;
  final String ip;
  final int port;

  const DiscoveredHost({
    required this.name,
    required this.ip,
    required this.port,
  });

  String get wsUrl => 'ws://$ip:$port';

  @override
  bool operator ==(Object other) =>
      other is DiscoveredHost && other.ip == ip && other.port == port;

  @override
  int get hashCode => Object.hash(ip, port);
}

class DiscoveryService {
  static const String serviceType = '_cueflow._tcp';

  nsd.Registration? _registration;
  nsd.Discovery? _discovery;

  /// Called by the Host to advertise the relay on the LAN.
  Future<void> advertise(
      {required int port, String name = 'CueFlow Host'}) async {
    await stopAdvertising();
    try {
      _registration = await nsd.register(
        nsd.Service(name: name, type: serviceType, port: port),
      );
    } catch (_) {}
  }

  Future<void> stopAdvertising() async {
    final reg = _registration;
    _registration = null;
    if (reg != null) {
      try {
        await nsd.unregister(reg);
      } catch (_) {}
    }
  }

  /// Called by clients to find Hosts. Emits the live list on each change.
  Stream<List<DiscoveredHost>> discover() {
    final controller = StreamController<List<DiscoveredHost>>.broadcast();
    final found = <String, DiscoveredHost>{};

    void resolveAndEmit(nsd.Service service) {
      final addresses = service.addresses;
      if (addresses == null || addresses.isEmpty) return;
      String? ip;
      for (final a in addresses) {
        if (a.type == InternetAddressType.IPv4 && a.address != '0.0.0.0') {
          ip = a.address;
          break;
        }
      }
      ip ??= addresses.first.address;
      final host = DiscoveredHost(
        name: service.name ?? 'CueFlow Host',
        ip: ip,
        port: service.port ?? 8080,
      );
      found['${host.ip}:${host.port}'] = host;
      if (!controller.isClosed) controller.add(found.values.toList());
    }

    nsd.startDiscovery(serviceType).then((d) {
      _discovery = d;
      d.addListener(() {
        for (final s in d.services) {
          resolveAndEmit(s);
        }
      });
    }).catchError((_) {});

    controller.onCancel = () async {
      final disc = _discovery;
      _discovery = null;
      if (disc != null) {
        try {
          await nsd.stopDiscovery(disc);
        } catch (_) {}
      }
    };

    return controller.stream;
  }

  Future<void> stopDiscovery() async {
    final disc = _discovery;
    _discovery = null;
    if (disc != null) {
      try {
        await nsd.stopDiscovery(disc);
      } catch (_) {}
    }
  }
}

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final class DemoGenerator {
  const DemoGenerator({
    required this.id,
    required this.name,
    required this.location,
    required this.capacityAmps,
  });

  final String id;
  final String name;
  final String location;
  final int capacityAmps;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'location': location,
        'capacity_amperes': capacityAmps,
      };

  factory DemoGenerator.fromJson(Map<String, dynamic> json) => DemoGenerator(
        id: json['id'].toString(),
        name: json['name'].toString(),
        location: json['location'].toString(),
        capacityAmps: (json['capacity_amperes'] as num).toInt(),
      );
}

final class DemoRoute {
  const DemoRoute({
    required this.id,
    required this.name,
    required this.generatorId,
  });

  final String id;
  final String name;
  final String generatorId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'generator_id': generatorId,
      };

  factory DemoRoute.fromJson(Map<String, dynamic> json) => DemoRoute(
        id: json['id'].toString(),
        name: json['name'].toString(),
        generatorId: json['generator_id'].toString(),
      );
}

final class DemoCollector {
  const DemoCollector({
    required this.id,
    required this.name,
    required this.phone,
    required this.assignedRouteIds,
  });

  final String id;
  final String name;
  final String phone;
  final List<String> assignedRouteIds;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'assigned_route_ids': assignedRouteIds,
      };

  factory DemoCollector.fromJson(Map<String, dynamic> json) => DemoCollector(
        id: json['id'].toString(),
        name: json['name'].toString(),
        phone: json['phone'].toString(),
        assignedRouteIds: (json['assigned_route_ids'] as List? ?? const [])
            .map((item) => item.toString())
            .toList(growable: false),
      );
}

final class DemoSubscriber {
  const DemoSubscriber({
    required this.id,
    required this.name,
    required this.phone,
    required this.accountNumber,
    required this.meterNumber,
    required this.routeId,
    required this.amperage,
    required this.lastReading,
  });

  final String id;
  final String name;
  final String phone;
  final String accountNumber;
  final String meterNumber;
  final String routeId;
  final int amperage;
  final int lastReading;

  DemoSubscriber copyWith({int? lastReading}) => DemoSubscriber(
        id: id,
        name: name,
        phone: phone,
        accountNumber: accountNumber,
        meterNumber: meterNumber,
        routeId: routeId,
        amperage: amperage,
        lastReading: lastReading ?? this.lastReading,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'account_number': accountNumber,
        'meter_number': meterNumber,
        'route_id': routeId,
        'amperage': amperage,
        'last_reading': lastReading,
      };

  factory DemoSubscriber.fromJson(Map<String, dynamic> json) => DemoSubscriber(
        id: json['id'].toString(),
        name: json['name'].toString(),
        phone: json['phone'].toString(),
        accountNumber: json['account_number'].toString(),
        meterNumber: json['meter_number'].toString(),
        routeId: json['route_id'].toString(),
        amperage: (json['amperage'] as num).toInt(),
        lastReading: (json['last_reading'] as num).toInt(),
      );
}

final class DemoInvoice {
  const DemoInvoice({
    required this.id,
    required this.number,
    required this.subscriberId,
    required this.totalIqd,
    required this.paidIqd,
    required this.dueDate,
  });

  final String id;
  final String number;
  final String subscriberId;
  final int totalIqd;
  final int paidIqd;
  final DateTime dueDate;

  int get remainingIqd => totalIqd - paidIqd;
  bool get isPaid => remainingIqd <= 0;
  bool get isPartial => paidIqd > 0 && remainingIqd > 0;
  String get statusLabel => isPaid ? 'مسددة' : isPartial ? 'جزئي' : 'غير مسددة';

  DemoInvoice copyWith({int? paidIqd}) => DemoInvoice(
        id: id,
        number: number,
        subscriberId: subscriberId,
        totalIqd: totalIqd,
        paidIqd: paidIqd ?? this.paidIqd,
        dueDate: dueDate,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'subscriber_id': subscriberId,
        'total_iqd': totalIqd,
        'paid_iqd': paidIqd,
        'due_date': dueDate.toIso8601String(),
      };

  factory DemoInvoice.fromJson(Map<String, dynamic> json) => DemoInvoice(
        id: json['id'].toString(),
        number: json['number'].toString(),
        subscriberId: json['subscriber_id'].toString(),
        totalIqd: (json['total_iqd'] as num).toInt(),
        paidIqd: (json['paid_iqd'] as num).toInt(),
        dueDate: DateTime.parse(json['due_date'].toString()),
      );
}

final class DemoReceipt {
  const DemoReceipt({
    required this.id,
    required this.number,
    required this.invoiceId,
    required this.amountIqd,
    required this.paymentMethod,
    required this.receivedBy,
    required this.createdAt,
  });

  final String id;
  final String number;
  final String invoiceId;
  final int amountIqd;
  final String paymentMethod;
  final String receivedBy;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'invoice_id': invoiceId,
        'amount_iqd': amountIqd,
        'payment_method': paymentMethod,
        'received_by': receivedBy,
        'created_at': createdAt.toIso8601String(),
      };

  factory DemoReceipt.fromJson(Map<String, dynamic> json) => DemoReceipt(
        id: json['id'].toString(),
        number: json['number'].toString(),
        invoiceId: json['invoice_id'].toString(),
        amountIqd: (json['amount_iqd'] as num).toInt(),
        paymentMethod: json['payment_method'].toString(),
        receivedBy: json['received_by'].toString(),
        createdAt: DateTime.parse(json['created_at'].toString()),
      );
}

final class DemoReading {
  const DemoReading({
    required this.id,
    required this.subscriberId,
    required this.value,
    required this.createdAt,
    required this.recordedBy,
  });

  final String id;
  final String subscriberId;
  final int value;
  final DateTime createdAt;
  final String recordedBy;

  Map<String, dynamic> toJson() => {
        'id': id,
        'subscriber_id': subscriberId,
        'value': value,
        'created_at': createdAt.toIso8601String(),
        'recorded_by': recordedBy,
      };

  factory DemoReading.fromJson(Map<String, dynamic> json) => DemoReading(
        id: json['id'].toString(),
        subscriberId: json['subscriber_id'].toString(),
        value: (json['value'] as num).toInt(),
        createdAt: DateTime.parse(json['created_at'].toString()),
        recordedBy: json['recorded_by'].toString(),
      );
}

final class DemoSnapshot {
  const DemoSnapshot({
    required this.generators,
    required this.routes,
    required this.collectors,
    required this.subscribers,
    required this.invoices,
    required this.receipts,
    required this.readings,
  });

  final List<DemoGenerator> generators;
  final List<DemoRoute> routes;
  final List<DemoCollector> collectors;
  final List<DemoSubscriber> subscribers;
  final List<DemoInvoice> invoices;
  final List<DemoReceipt> receipts;
  final List<DemoReading> readings;

  int get billedIqd => invoices.fold(0, (sum, item) => sum + item.totalIqd);
  int get collectedIqd => invoices.fold(0, (sum, item) => sum + item.paidIqd);
  int get remainingIqd => invoices.fold(0, (sum, item) => sum + item.remainingIqd);

  DemoSnapshot copyWith({
    List<DemoSubscriber>? subscribers,
    List<DemoInvoice>? invoices,
    List<DemoReceipt>? receipts,
    List<DemoReading>? readings,
  }) =>
      DemoSnapshot(
        generators: generators,
        routes: routes,
        collectors: collectors,
        subscribers: subscribers ?? this.subscribers,
        invoices: invoices ?? this.invoices,
        receipts: receipts ?? this.receipts,
        readings: readings ?? this.readings,
      );

  Map<String, dynamic> toJson() => {
        'generators': generators.map((item) => item.toJson()).toList(),
        'routes': routes.map((item) => item.toJson()).toList(),
        'collectors': collectors.map((item) => item.toJson()).toList(),
        'subscribers': subscribers.map((item) => item.toJson()).toList(),
        'invoices': invoices.map((item) => item.toJson()).toList(),
        'receipts': receipts.map((item) => item.toJson()).toList(),
        'readings': readings.map((item) => item.toJson()).toList(),
      };

  factory DemoSnapshot.fromJson(Map<String, dynamic> json) => DemoSnapshot(
        generators: _decodeList(json['generators'], DemoGenerator.fromJson),
        routes: _decodeList(json['routes'], DemoRoute.fromJson),
        collectors: _decodeList(json['collectors'], DemoCollector.fromJson),
        subscribers: _decodeList(json['subscribers'], DemoSubscriber.fromJson),
        invoices: _decodeList(json['invoices'], DemoInvoice.fromJson),
        receipts: _decodeList(json['receipts'], DemoReceipt.fromJson),
        readings: _decodeList(json['readings'], DemoReading.fromJson),
      );

  static List<T> _decodeList<T>(
    dynamic raw,
    T Function(Map<String, dynamic>) decoder,
  ) =>
      (raw as List? ?? const [])
          .map((item) => decoder(Map<String, dynamic>.from(item as Map)))
          .toList(growable: false);

  factory DemoSnapshot.seed() {
    final now = DateTime.now();
    return DemoSnapshot(
      generators: const [
        DemoGenerator(
          id: 'g1',
          name: 'مولدة النخبة المركزية',
          location: 'حي الجامعة',
          capacityAmps: 850,
        ),
        DemoGenerator(
          id: 'g2',
          name: 'مولدة السوق الجديدة',
          location: 'شارع السوق',
          capacityAmps: 620,
        ),
      ],
      routes: const [
        DemoRoute(id: 'r1', name: 'مسار الجامعة', generatorId: 'g1'),
        DemoRoute(id: 'r2', name: 'مسار الأطباء', generatorId: 'g1'),
        DemoRoute(id: 'r3', name: 'مسار السوق', generatorId: 'g2'),
      ],
      collectors: const [
        DemoCollector(
          id: 'c1',
          name: 'أحمد كريم',
          phone: '0780 111 2233',
          assignedRouteIds: ['r1', 'r3'],
        ),
        DemoCollector(
          id: 'c2',
          name: 'حسين علي',
          phone: '0770 555 8899',
          assignedRouteIds: ['r2'],
        ),
      ],
      subscribers: const [
        DemoSubscriber(id: 's1', name: 'علي جبار', phone: '0781 201 1001', accountNumber: 'A-1001', meterNumber: 'M-501', routeId: 'r1', amperage: 10, lastReading: 1280),
        DemoSubscriber(id: 's2', name: 'سارة مهدي', phone: '0772 345 1170', accountNumber: 'A-1002', meterNumber: 'M-502', routeId: 'r1', amperage: 15, lastReading: 1645),
        DemoSubscriber(id: 's3', name: 'محمود سالم', phone: '0783 712 9900', accountNumber: 'A-1003', meterNumber: 'M-503', routeId: 'r2', amperage: 20, lastReading: 2230),
        DemoSubscriber(id: 's4', name: 'زينب كاظم', phone: '0771 802 4431', accountNumber: 'A-1004', meterNumber: 'M-504', routeId: 'r2', amperage: 10, lastReading: 910),
        DemoSubscriber(id: 's5', name: 'كرار ناصر', phone: '0780 661 2399', accountNumber: 'A-1005', meterNumber: 'M-505', routeId: 'r3', amperage: 25, lastReading: 3055),
        DemoSubscriber(id: 's6', name: 'مريم حيدر', phone: '0773 992 2218', accountNumber: 'A-1006', meterNumber: 'M-506', routeId: 'r3', amperage: 15, lastReading: 1770),
        DemoSubscriber(id: 's7', name: 'مصطفى رعد', phone: '0782 411 7788', accountNumber: 'A-1007', meterNumber: 'M-507', routeId: 'r1', amperage: 10, lastReading: 1440),
        DemoSubscriber(id: 's8', name: 'نور حسين', phone: '0774 312 9870', accountNumber: 'A-1008', meterNumber: 'M-508', routeId: 'r3', amperage: 20, lastReading: 2510),
      ],
      invoices: [
        DemoInvoice(id: 'i1', number: 'INV-2026-0701', subscriberId: 's1', totalIqd: 123000, paidIqd: 50000, dueDate: now.add(const Duration(days: 4))),
        DemoInvoice(id: 'i2', number: 'INV-2026-0702', subscriberId: 's2', totalIqd: 180000, paidIqd: 180000, dueDate: now.add(const Duration(days: 4))),
        DemoInvoice(id: 'i3', number: 'INV-2026-0703', subscriberId: 's3', totalIqd: 243000, paidIqd: 0, dueDate: now.add(const Duration(days: 3))),
        DemoInvoice(id: 'i4', number: 'INV-2026-0704', subscriberId: 's4', totalIqd: 123000, paidIqd: 0, dueDate: now.add(const Duration(days: 3))),
        DemoInvoice(id: 'i5', number: 'INV-2026-0705', subscriberId: 's5', totalIqd: 303000, paidIqd: 100000, dueDate: now.add(const Duration(days: 5))),
        DemoInvoice(id: 'i6', number: 'INV-2026-0706', subscriberId: 's6', totalIqd: 183000, paidIqd: 0, dueDate: now.add(const Duration(days: 5))),
        DemoInvoice(id: 'i7', number: 'INV-2026-0707', subscriberId: 's7', totalIqd: 123000, paidIqd: 123000, dueDate: now.add(const Duration(days: 4))),
        DemoInvoice(id: 'i8', number: 'INV-2026-0708', subscriberId: 's8', totalIqd: 243000, paidIqd: 0, dueDate: now.add(const Duration(days: 5))),
      ],
      receipts: [
        DemoReceipt(id: 'p1', number: 'REC-1001', invoiceId: 'i1', amountIqd: 50000, paymentMethod: 'نقد', receivedBy: 'أحمد كريم — جابي', createdAt: now.subtract(const Duration(hours: 5))),
        DemoReceipt(id: 'p2', number: 'REC-1002', invoiceId: 'i2', amountIqd: 180000, paymentMethod: 'تحويل', receivedBy: 'صاحب المولدة', createdAt: now.subtract(const Duration(days: 1))),
        DemoReceipt(id: 'p3', number: 'REC-1003', invoiceId: 'i5', amountIqd: 100000, paymentMethod: 'نقد', receivedBy: 'أحمد كريم — جابي', createdAt: now.subtract(const Duration(hours: 2))),
        DemoReceipt(id: 'p4', number: 'REC-1004', invoiceId: 'i7', amountIqd: 123000, paymentMethod: 'نقد', receivedBy: 'صاحب المولدة', createdAt: now.subtract(const Duration(days: 2))),
      ],
      readings: [
        DemoReading(id: 'rd1', subscriberId: 's1', value: 1280, createdAt: now.subtract(const Duration(days: 2)), recordedBy: 'أحمد كريم'),
        DemoReading(id: 'rd2', subscriberId: 's2', value: 1645, createdAt: now.subtract(const Duration(days: 2)), recordedBy: 'أحمد كريم'),
        DemoReading(id: 'rd3', subscriberId: 's5', value: 3055, createdAt: now.subtract(const Duration(days: 1)), recordedBy: 'أحمد كريم'),
      ],
    );
  }
}

final class DemoStore extends ChangeNotifier {
  DemoStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _storageKey = 'nukhba_generators_demo_snapshot_v1';

  final FlutterSecureStorage _storage;
  DemoSnapshot _snapshot = DemoSnapshot.seed();
  bool _loaded = false;

  DemoSnapshot get snapshot => _snapshot;
  bool get loaded => _loaded;

  Future<void> load() async {
    final raw = await _storage.read(key: _storageKey);
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        _snapshot = DemoSnapshot.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
      } catch (_) {
        _snapshot = DemoSnapshot.seed();
        await _persist();
      }
    } else {
      _snapshot = DemoSnapshot.seed();
      await _persist();
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> reset() async {
    _snapshot = DemoSnapshot.seed();
    await _persist();
    notifyListeners();
  }

  Future<DemoSubscriber> addSubscriber({
    required String name,
    required String phone,
    required String routeId,
    required int amperage,
  }) async {
    final cleanName = name.trim();
    final cleanPhone = phone.trim();
    if (cleanName.isEmpty) throw ArgumentError('اسم المشترك مطلوب');
    if (cleanPhone.isEmpty) throw ArgumentError('رقم الهاتف مطلوب');
    if (!_snapshot.routes.any((item) => item.id == routeId)) {
      throw StateError('المسار المحدد غير موجود');
    }
    if (amperage <= 0) throw ArgumentError('الأمبير يجب أن يكون أكبر من صفر');

    final next = _snapshot.subscribers.length + 1;
    final subscriber = DemoSubscriber(
      id: 's-${DateTime.now().microsecondsSinceEpoch}',
      name: cleanName,
      phone: cleanPhone,
      accountNumber: 'A-${1000 + next}',
      meterNumber: 'M-${500 + next}',
      routeId: routeId,
      amperage: amperage,
      lastReading: 0,
    );
    _snapshot = _snapshot.copyWith(
      subscribers: [..._snapshot.subscribers, subscriber],
    );
    await _persist();
    notifyListeners();
    return subscriber;
  }

  Future<DemoReceipt> recordPayment({
    required String invoiceId,
    required int amountIqd,
    required String paymentMethod,
    required String receivedBy,
  }) async {
    final index = _snapshot.invoices.indexWhere((item) => item.id == invoiceId);
    if (index < 0) throw StateError('الفاتورة غير موجودة');
    final invoice = _snapshot.invoices[index];
    if (invoice.isPaid) throw StateError('الفاتورة مسددة بالكامل');
    if (amountIqd <= 0) throw ArgumentError('مبلغ الدفعة يجب أن يكون أكبر من صفر');
    if (amountIqd > invoice.remainingIqd) {
      throw ArgumentError('مبلغ الدفعة أكبر من المتبقي');
    }

    final invoices = [..._snapshot.invoices];
    invoices[index] = invoice.copyWith(paidIqd: invoice.paidIqd + amountIqd);
    final receiptSequence = 1001 + _snapshot.receipts.length;
    final receipt = DemoReceipt(
      id: 'p-${DateTime.now().microsecondsSinceEpoch}',
      number: 'REC-$receiptSequence',
      invoiceId: invoiceId,
      amountIqd: amountIqd,
      paymentMethod: paymentMethod,
      receivedBy: receivedBy,
      createdAt: DateTime.now(),
    );
    _snapshot = _snapshot.copyWith(
      invoices: invoices,
      receipts: [receipt, ..._snapshot.receipts],
    );
    await _persist();
    notifyListeners();
    return receipt;
  }

  Future<DemoReading> recordReading({
    required String subscriberId,
    required int value,
    required String recordedBy,
  }) async {
    final index = _snapshot.subscribers.indexWhere((item) => item.id == subscriberId);
    if (index < 0) throw StateError('المشترك غير موجود');
    final subscriber = _snapshot.subscribers[index];
    if (value < subscriber.lastReading) {
      throw ArgumentError('القراءة الجديدة لا يمكن أن تكون أقل من السابقة');
    }

    final subscribers = [..._snapshot.subscribers];
    subscribers[index] = subscriber.copyWith(lastReading: value);
    final reading = DemoReading(
      id: 'rd-${DateTime.now().microsecondsSinceEpoch}',
      subscriberId: subscriberId,
      value: value,
      createdAt: DateTime.now(),
      recordedBy: recordedBy,
    );
    _snapshot = _snapshot.copyWith(
      subscribers: subscribers,
      readings: [reading, ..._snapshot.readings],
    );
    await _persist();
    notifyListeners();
    return reading;
  }

  List<DemoSubscriber> subscribersForCollector(DemoCollector collector) =>
      _snapshot.subscribers
          .where((item) => collector.assignedRouteIds.contains(item.routeId))
          .toList(growable: false);

  List<DemoInvoice> invoicesForCollector(DemoCollector collector) {
    final subscriberIds = subscribersForCollector(collector).map((item) => item.id).toSet();
    return _snapshot.invoices
        .where((item) => subscriberIds.contains(item.subscriberId))
        .toList(growable: false);
  }

  DemoSubscriber subscriberById(String id) =>
      _snapshot.subscribers.firstWhere((item) => item.id == id);

  DemoRoute routeById(String id) =>
      _snapshot.routes.firstWhere((item) => item.id == id);

  DemoGenerator generatorById(String id) =>
      _snapshot.generators.firstWhere((item) => item.id == id);

  DemoInvoice invoiceById(String id) =>
      _snapshot.invoices.firstWhere((item) => item.id == id);

  Future<void> _persist() => _storage.write(
        key: _storageKey,
        value: jsonEncode(_snapshot.toJson()),
      );
}

enum PoiType {
  parking,
  gasStation,
}

class MapPoiModel {
  final String id;
  final String title;
  final String description;
  final double latitude;
  final double longitude;
  final PoiType type;
  final String brandOrOperator;
  final String? feeOrCapacity;
  final int? totalCapacity;
  final int? emptyCapacity;
  final String? workHours;
  final String? district;
  final bool isIbb;

  const MapPoiModel({
    required this.id,
    required this.title,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.type,
    required this.brandOrOperator,
    this.feeOrCapacity,
    this.totalCapacity,
    this.emptyCapacity,
    this.workHours,
    this.district,
    this.isIbb = false,
  });

  bool get isFull => emptyCapacity != null && emptyCapacity == 0;
}

class VpnServer {
  const VpnServer({
    required this.id,
    required this.name,
    required this.protocol,
    required this.countryCode,
    required this.countryNameFa,
    required this.countryNameEn,
    required this.locationVerified,
  });

  final String id;
  final String name;
  final String protocol;
  final String? countryCode;
  final String? countryNameFa;
  final String? countryNameEn;
  final bool locationVerified;

  factory VpnServer.fromJson(Map<String, dynamic> json) => VpnServer(
        id: json['id'] as String,
        name: json['name'] as String,
        protocol: json['protocol'] as String,
        countryCode: json['country_code'] as String?,
        countryNameFa: json['country_name_fa'] as String?,
        countryNameEn: json['country_name_en'] as String?,
        locationVerified: json['location_verified'] == true,
      );
}

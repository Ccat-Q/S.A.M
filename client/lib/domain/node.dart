class Node {
  final Map<String, dynamic> data;
  Node(this.data);
  String get id => data['id'] as String;
  String get name => data['name'] as String;
  String get type => data['type'] as String;
  String get subtype => data['subtype'] as String;
  String get module => data['module_id'] as String;
  String get status => data['status'] as String;
  int get version => data['version'] as int;
  String? get fault => data['fault'] as String?;
  List<String> get capabilities => List<String>.from(data['capabilities'] as List);
  Map<String, dynamic> get controls => Map<String, dynamic>.from(data['controls'] as Map);
  Map<String, dynamic> get telemetry => Map<String, dynamic>.from(data['telemetry'] as Map);
  Map<String, dynamic> get metadata => Map<String, dynamic>.from(data['metadata'] as Map);
  double get x => (data['position']['x'] as num).toDouble();
  double get y => (data['position']['y'] as num).toDouble();
}

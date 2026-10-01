import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiError implements Exception {
  final int status;
  final String code;
  ApiError(this.status, this.code);
  @override
  String toString() => code;
}

class SamApi {
  Uri base;
  String? token;
  final http.Client client;
  SamApi(String address, {http.Client? client})
    : base = Uri.parse(address),
      client = client ?? http.Client();
  Uri uri(String path, [Map<String, String>? query]) =>
      base.resolve(path).replace(queryParameters: query);
  Future<dynamic> call(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
  }) async {
    final request = http.Request(method, uri(path, query));
    request.headers['Content-Type'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) request.body = jsonEncode(body);
    final response = await http.Response.fromStream(
      await client.send(request).timeout(const Duration(seconds: 12)),
    );
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw ApiError(
        response.statusCode,
        decoded is Map
            ? decoded['detail'].toString()
            : 'HTTP_${response.statusCode}',
      );
    }
    return decoded;
  }

  void close() => client.close();
}

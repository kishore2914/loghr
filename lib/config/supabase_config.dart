import 'dart:async';
import 'package:loghr_mobile/config/api_client.dart';

class SupabaseConfig {
  static Future<void> initialize() async {
    await api.initialize();
  }

  static MockSupabaseClient get client => MockSupabaseClient();
}

MockSupabaseClient get supabase => SupabaseConfig.client;

class MockSupabaseClient {
  MockAuthClient get auth => MockAuthClient();
  MockStorageClient get storage => MockStorageClient();

  MockQueryBuilder from(String table) {
    return MockQueryBuilder(table);
  }

  MockRpcBuilder rpc(String fnName, {Map<String, dynamic>? params}) {
    return MockRpcBuilder(fnName, params);
  }
}

class MockAuthClient {
  MockUser? get currentUser {
    if (!api.isAuthenticated) return null;
    return MockUser(api.token?.hashCode.toString() ?? 'user-id', 'employee@loghr.com');
  }
}

class MockUser {
  final String id;
  final String? email;
  MockUser(this.id, this.email);
}

class MockStorageClient {
  MockStorageBucket from(String bucket) => MockStorageBucket(bucket);
}

class MockStorageBucket {
  final String bucket;
  MockStorageBucket(this.bucket);
  
  String getPublicUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    return '${api.baseUrl}/storage/$bucket/$path';
  }
  
  Future<String> createSignedUrl(String path, int expiry) async {
    return getPublicUrl(path);
  }
}

class QueryFilter {
  final String column;
  final String operator;
  final dynamic value;
  
  QueryFilter(this.column, this.operator, this.value);
  
  Map<String, dynamic> toJson() => {
    'column': column,
    'operator': operator,
    'value': value,
  };
}

class MockRpcBuilder implements Future<dynamic> {
  final String fnName;
  final Map<String, dynamic>? params;
  bool expectSingle = false;

  MockRpcBuilder(this.fnName, this.params);

  MockRpcBuilder maybeSingle() {
    expectSingle = true;
    return this;
  }

  MockRpcBuilder single() {
    expectSingle = true;
    return this;
  }

  Future<dynamic> execute() async {
    try {
      final response = await api.post('/db/rpc/$fnName', {
        'params': params,
        'expectSingle': expectSingle,
      });
      return response;
    } catch (e) {
      print('MockRpcBuilder: error executing RPC $fnName: $e');
      if (expectSingle) return null;
      return [];
    }
  }

  @override
  Future<dynamic> timeout(Duration timeLimit, {FutureOr<dynamic> Function()? onTimeout}) => execute().timeout(timeLimit, onTimeout: onTimeout);
  
  @override
  Future<R> then<R>(FutureOr<R> Function(dynamic value) onValue, {Function? onError}) => execute().then(onValue, onError: onError);
  
  @override
  Future<dynamic> catchError(Function onError, {bool Function(Object error)? test}) => execute().catchError(onError, test: test);
  
  @override
  Future<dynamic> whenComplete(FutureOr<void> Function() action) => execute().whenComplete(action);
  
  @override
  Stream<dynamic> asStream() => execute().asStream();
}

class MockQueryBuilder implements Future<dynamic> {
  final String table;
  final String method;
  final dynamic data;
  final List<QueryFilter> filters = [];
  String? orderColumn;
  bool orderAscending = true;
  int? limitValue;
  bool expectSingle = false;

  MockQueryBuilder(this.table, {this.method = 'select', this.data});

  MockQueryBuilder select([String? columns]) => this;
  
  MockQueryBuilder eq(String col, dynamic val) {
    filters.add(QueryFilter(col, 'eq', val));
    return this;
  }
  
  MockQueryBuilder neq(String col, dynamic val) {
    filters.add(QueryFilter(col, 'neq', val));
    return this;
  }
  
  MockQueryBuilder lt(String col, dynamic val) {
    filters.add(QueryFilter(col, 'lt', val));
    return this;
  }
  
  MockQueryBuilder gt(String col, dynamic val) {
    filters.add(QueryFilter(col, 'gt', val));
    return this;
  }

  MockQueryBuilder lte(String col, dynamic val) {
    filters.add(QueryFilter(col, 'lte', val));
    return this;
  }
  
  MockQueryBuilder gte(String col, dynamic val) {
    filters.add(QueryFilter(col, 'gte', val));
    return this;
  }

  MockQueryBuilder ilike(String col, String val) {
    filters.add(QueryFilter(col, 'ilike', val));
    return this;
  }
  
  MockQueryBuilder not(String col, String operator, dynamic val) {
    filters.add(QueryFilter(col, 'not_$operator', val));
    return this;
  }
  
  MockQueryBuilder isFilter(String col, dynamic val) {
    filters.add(QueryFilter(col, 'is', val));
    return this;
  }
  
  MockQueryBuilder inFilter(String col, List<dynamic> vals) {
    filters.add(QueryFilter(col, 'in', vals));
    return this;
  }
  
  MockQueryBuilder or(String filtersStr) {
    filters.add(QueryFilter('', 'or', filtersStr));
    return this;
  }
  
  MockQueryBuilder order(String col, {bool ascending = true}) {
    orderColumn = col;
    orderAscending = ascending;
    return this;
  }
  
  MockQueryBuilder limit(int l) {
    limitValue = l;
    return this;
  }
  
  MockQueryBuilder maybeSingle() {
    expectSingle = true;
    return this;
  }
  
  MockQueryBuilder single() {
    expectSingle = true;
    return this;
  }

  MockQueryBuilder insert(dynamic data) {
    return MockQueryBuilder(table, method: 'insert', data: data);
  }

  MockQueryBuilder update(dynamic data) {
    return MockQueryBuilder(table, method: 'update', data: data);
  }

  MockQueryBuilder delete() {
    return MockQueryBuilder(table, method: 'delete');
  }

  Future<dynamic> execute() async {
    // Map table names if needed
    String routeTable = table;
    if (table == 'attendance_records') routeTable = 'attendance';

    final payload = {
      'table': routeTable,
      'method': method,
      'filters': filters.map((f) => f.toJson()).toList(),
      'orderColumn': orderColumn,
      'orderAscending': orderAscending,
      'limit': limitValue,
      'expectSingle': expectSingle,
      'data': data,
    };

    try {
      final response = await api.post('/db/query', payload);
      return response;
    } catch (e) {
      print('MockQueryBuilder: error executing DB query: $e');
      if (expectSingle) {
        return null;
      }
      return [];
    }
  }

  @override
  Future<dynamic> timeout(Duration timeLimit, {FutureOr<dynamic> Function()? onTimeout}) => execute().timeout(timeLimit, onTimeout: onTimeout);
  
  @override
  Future<R> then<R>(FutureOr<R> Function(dynamic value) onValue, {Function? onError}) => execute().then(onValue, onError: onError);
  
  @override
  Future<dynamic> catchError(Function onError, {bool Function(Object error)? test}) => execute().catchError(onError, test: test);
  
  @override
  Future<dynamic> whenComplete(FutureOr<void> Function() action) => execute().whenComplete(action);
  
  @override
  Stream<dynamic> asStream() => execute().asStream();
}

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConstants {
  // for phone debug put your ip of wifi to which you connected here. 
  // make sure htat both phone and pc are connected to same wifi
  static const String _macIpAddress = '10.22.71.101';

  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:8080/api/v1';
    
  
    if (Platform.isAndroid) return 'http://$_macIpAddress:8080/api/v1';
    if (Platform.isIOS) return 'http://$_macIpAddress:8080/api/v1';
    
    return 'http://localhost:8080/api/v1';
  }

  static String get wsUrl {
    if (kIsWeb) return 'ws://localhost:8080/api/v1/ws';
    
    if (Platform.isAndroid) return 'ws://$_macIpAddress:8080/api/v1/ws';
    if (Platform.isIOS) return 'ws://$_macIpAddress:8080/api/v1/ws';
    
    return 'ws://localhost:8080/api/v1/ws';
  }
}
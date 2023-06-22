import 'dart:io';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:udp/udp.dart';
import 'package:crypto/crypto.dart';

class Server{

  String address = "185.228.173.50";
  int port = 9999;
  String clau = "1234567890";

  int retryPeriod = 1000;
  int retryTimes = 3;

  int _messageId = 0;
  int _retryCount = 0;

  UDP? _sender;
  UDP? _receiver;
  Stream? _recStream;
  StreamSubscription? _recSubscription;

  List<String>? _answer;

  Server(this.address, this.port);

  Future sendNoReply(String buff) async {
    if (_sender == null){
      _sender = await UDP.bind(Endpoint.any(port: Port(65000)));
      }
    _messageId += 1;
    String data = "$clau;$_messageId;" + buff;
    var hash = md5.convert(data.codeUnits).toString();
    var message = "$hash;$_messageId;" + buff;
    var endpoint =  Endpoint.unicast(InternetAddress(address), port: Port(port));
    var sentLength = await _sender!.send(message.codeUnits, endpoint);
  }

  void processReceivedData (datagram){
    var str = String.fromCharCodes(datagram!.data);
    var data = str.split(";").toList();

    var hash = data[0];
    var p = str.indexOf(";");
    var someData = "$clau;" + str.substring(p+1, str.length);
    var myHash = md5.convert(someData.codeUnits).toString();

    if (myHash != hash){
      print("Hashed Buffer : $someData");
      print("My Hash : $myHash itsHash : $hash");
    } else {
      var id = data[1];

      var rest = data.getRange(2, data.length).toList();
      print("Resposta $rest");
      _answer = rest;
    }

  }
  Future<List<String>?> sendWithReply(String buff) async {

    if (_sender == null) {
      _sender = await UDP.bind(Endpoint.any(port: Port(65000)));
    }
    if (_recStream == null){
      _recStream = _sender?.asStream();
      _recSubscription = _recStream?.listen(processReceivedData);
    }
    _messageId += 1;
    _answer = null;

    String data = "$clau;$_messageId;" + buff;
    var hash = md5.convert(data.codeUnits).toString();

    var message = "$hash;$_messageId;" + buff;
    var endpoint =  Endpoint.unicast(InternetAddress(address), port: Port(port));
    _retryCount = 0;
    while(_answer == null && _retryCount < retryTimes){
      print("Sending message. Retry $_retryCount");
      var sentLength = await _sender!.send(message.codeUnits, endpoint);
      await Future.delayed(Duration(milliseconds: retryPeriod));
      _retryCount += 1;
    }

    print("Returning $_answer");
    return _answer;

  }


}
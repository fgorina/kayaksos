//import 'dart:ffi';
import 'dart:io';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_compass/flutter_compass.dart';


import 'RadarPainter.dart';
import 'Server.dart';
import 'Sessio.dart';
import 'Usuari.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SKKayak',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Surfski SKKayak'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  LocationData testData = LocationData.fromMap({'latitude' : 42.3822, 'longitude' : 3.17012});

  Server server = Server("185.228.173.50", 9999);
  int _counter = 0;

  String user = "Paco";
  String pos = "45N 67E";
  Location? location;
  LocationData? locationData;
  double heading = 0.0;
  StreamSubscription<LocationData>? stream;
  StreamSubscription<CompassEvent>? compassStream;


  String status = "";
  int session = -1;
  String sessionName = "";
  var estat = "Start";
  var emergency = false;

  var period = 10;
  Timer? timer;

  bool selectSession = false;
  List<Sessio> sessions = [];

  bool followUsers = false;
  List<Usuari> usuaris = [];
  int refreshUsersPeriod = 100;
  double scale = 1.0;

  bool openSettings = false;
  bool fakeLocation = false;
  // State for selecting session

  void stopLocation() async {
    await ping("STOP", locationData);
    session = -1;
    sessionName = "";
    stream?.cancel();
    compassStream?.cancel();
    location = null;
    timer = null;
    emergency = false;
    setState(() {
      estat = "Start";
    });
  }

   void processReceivedData(datagram) {
    var str = String.fromCharCodes(datagram!.data);
    var data = str.split(";").toList();
    if (data.length > 1 && data[0] == "SESSIO") {
      session = int.parse(data[1]);
    } else {
      print(data);
    }
  }

  void startLocation() async {

    location = Location();
    bool _serviceEnabled;
    PermissionStatus _permissionGranted;

    _serviceEnabled = await location!.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location!.requestService();
      if (!_serviceEnabled) {
        return;
      }
    }

    _permissionGranted = await location!.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await location!.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        return;
      }
    }
    location!.enableBackgroundMode(enable: true);
    setState(() {
      estat = "Stop";
    });

    locationData = fakeLocation? testData : await location!.getLocation();
    var data = await ping("START", locationData);
    if (data != null && data.length >= 2) {
      var someSession = int.parse(data[1]);
      if (someSession != session) {
        session = someSession;
        sessionName = "$session";
      }
    } else {
      setState(() {
        estat = "Start";
      });
    }
    stream = location!.onLocationChanged.listen((loc) {
      setState(() {
        locationData = fakeLocation ? testData : loc;
      });
    });

    compassStream = FlutterCompass.events?.listen((event){
      if (event.heading != null && (heading - event.heading!).abs() > 1.0){
        setState(() {
          heading = event.heading!;
        });
      }

    });
    timer = Timer(Duration(seconds: period), handleTimer);
  }

  String lat() {
    if (locationData == null) {
      return "***";
    } else {
      var dir = locationData!.latitude! >= 0 ? "N" : "S";
      var degrees = locationData!.latitude!.floor();
      var minutes = NumberFormat("#.000")
          .format((locationData!.latitude! - degrees) * 60.0);
      return "$degreesº $minutes' $dir";
    }
  }

  String lon() {
    if (locationData == null) {
      return "***";
    } else {
      var dir = locationData!.longitude! >= 0 ? "E" : "W";
      var degrees = locationData!.longitude!.floor();
      var minutes = NumberFormat("#.000")
          .format((locationData!.longitude! - degrees) * 60.0);
      return "$degreesº $minutes' $dir";
    }
  }

  String head() {
    if (heading == null) {
      return "***";
    } else {
      var v = heading.round();
      return "$vº";
      }
  }


  Future<void> call(String phone) async {
    Uri _url = Uri.parse('tel://$phone');
    if (!await launchUrl(_url)) {
      throw Exception('Could not launch $_url');
    }
  }

  Future handleTimer() async {

    await ping(emergency ? "SOS" : "OK", locationData);
    if (estat == "Stop") {
      Timer(Duration(seconds: period), handleTimer);
    }
  }

  @override
  Future<List<String>?> ping(situacio, locationData) async {
    if (estat == "Start") {
      return null;
    }

    // send a simple string to a broadcast endpoint on port 65001.
    //locationData = await location!.getLocation();
    var time = locationData.time;
    var lon = locationData.longitude;
    var lat = locationData.latitude;
    var speed = locationData.speed;
    var heading = locationData.heading;

    pos = "$locationData @ $time";

    var buff = "$situacio;$user;$session; $lon;$lat;$time;$heading;$speed";
    DateFormat dateFormat =
        DateFormat("yyyy-MM-dd HH:mm:ss"); // how you want it to be formatted

    if (situacio == "START" || situacio == "STOP") {
      var answer = await server.sendWithReply(buff);
      return answer;
      print("Answer from Server $answer");
    } else {
      await server.sendNoReply(buff);
      return null;
    }
    print("Sent Location");
  }

  void doSOS() async {
    setState(() {
      emergency = !emergency;
    });
    ping("SOS", locationData);
  }

  void doCall() async {
    doSOS();
    call("900202202");
  }

  Future openSelectSessions() async {
    var someData = await server.sendWithReply("SESSIONS;$user");
    if (someData != null && someData!.length >= 2) {
      sessions = [];
      for (int i = 0; i < someData!.length; i = i + 2) {
        var aSession = Sessio(int.parse(someData![i]!), someData![i + 1]!);
        sessions.add(aSession);
      }
      setState(() {
        selectSession = true;
      });
    }
  }

  Future refreshUsuaris() async {
    while(followUsers) {
      var someData = await server.sendWithReply("USERS;$user;$session");
      print("Received: $someData");
      if (someData != null && someData.length >= 3) {
        List<Usuari> someUsers = [];
        for (int i = 0; i < someData.length; i = i + 3) {
          var aUser = Usuari(
              someData[i], double.parse(someData[i + 1].toString()),
              double.parse(someData[i + 2].toString()));
            someUsers.add(aUser);
        }
        setState(() {

          usuaris = someUsers;
          print("Usuaris $usuaris");
        });
      }
      await Future.delayed(Duration(seconds: refreshUsersPeriod));
    }
  }


  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(estat == "Start"
            ? "Parat $sessionName"
            : (session == -1
                ? "Connectant"
                : "Sessió $sessionName")), //Text(widget.title),
        backgroundColor: emergency
            ? Colors.red
            : (estat == "Stop" ? Colors.green : Colors.lightBlue),
        actions: [
          PopupMenuButton(
            itemBuilder: (context) {
              return [
                const PopupMenuItem<int>(
                  value: 0,
                  child: Text("Ajustos"),
                ),
                PopupMenuItem<int>(
                  value: 1,
                  child: Text("Crear Sessió"),
                  enabled: false,
                ),
                PopupMenuItem<int>(
                  value: 2,
                  child: Text("Unir-se a sessió"),
                ),
                PopupMenuItem<int>(
                  value: 3,
                  child: Text(followUsers ? "Parar de seguir Usuaris" : "Seguir Usuaris"),
                  enabled: estat != "Start",
                ),
              ];
            },
            onSelected: (value) {
              switch (value) {
                case 0:
                  setState(() {
                    openSettings = true;
                  });
                  break;

                case 1:
                  print("Crear Sessió");
                  break;

                case 2:
                  openSelectSessions();
                  break;

                case 3:
                  followUsers = !followUsers;
                  if (followUsers){
                    refreshUsuaris();
                  }
                  break;
              }
            },
          ),
        ],
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Stack(
          alignment: Alignment.center,
          children: [
            followUsers?
                GestureDetector(
            child: CustomPaint(
              size: Size(MediaQuery.of(context).size.width, MediaQuery.of(context).size.height),
              painter: RadarPainter(heading, locationData!, usuaris, scale),
            ) ,
                  onLongPress: (){
                    setState((){
                      scale = scale == 1.0 ? 3.0 : 1.0;
                     });
                  },
                ): SizedBox.shrink(),
            TextButton(

              child: (estat == "Start")
                  ? Icon(
                Icons.play_circle,
                size: 100,
              )
                  : Icon(Icons.stop_circle, size: 100),
              onPressed: () {},
              onLongPress: () {
                if (estat == "Start") {
                  startLocation();
                } else {
                  stopLocation();
                }
              },
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(height: 40),
                Row(
                  children: [
                    Spacer(),
                    Text("${lat()}",
                        style: TextStyle(
                            fontSize: 28, fontWeight: FontWeight.bold)),
                    Spacer(),
                    Text(
                      "${lon()}",
                      style:
                          TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    Spacer()
                  ],
                ),
                Text(head(), style: TextStyle(
                    fontSize: 28, fontWeight: FontWeight.bold)),



                Spacer(flex: 5,),
                Row(children: [
                  Spacer(),
                  OutlinedButton(
                    child: Text("SOS",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.red)),
                    style:
                        OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: () {},
                    onLongPress: estat == "Start" ? null : doSOS,
                  ),
                  Spacer(),
                  OutlinedButton(
                    child: Text("Call SM",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.white)),
                    onPressed: () {},
                    style:
                        OutlinedButton.styleFrom(backgroundColor: Colors.red),
                    onLongPress: estat == "Start" ? null : doCall,
                  ),
                  Spacer(),
                ]),
                Spacer(),
              ],
            ),
            openSettings
                ? Container(
                    width: 300,
                    height: 400,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey, width: 2),
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      color: Colors.white,
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, 0, 0, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 30,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  "Configureu l'aplicació",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Spacer(),
                                IconButton(
                                    onPressed: () {
                                      setState(() {
                                        openSettings = false;
                                      });
                                    },
                                    icon: Icon(Icons.close)),
                              ],
                            ),
                          ),
                          Divider(),
                          Text("Usuari", style: TextStyle(fontSize: 14, color: Colors.black45), textAlign: TextAlign.start, ),
                          Padding(
                            padding: EdgeInsets.fromLTRB(0, 0, 20, 10),
                            child: TextFormField(
                                initialValue: user,
                                decoration: InputDecoration(
                                  hintStyle: TextStyle(color: Colors.black26),
                                  hintText: "Entreu l'usuari",
                                ),
                                onChanged: (v) {
                                  user = v;
                                }),
                          ),
                          Text("Server", style: TextStyle(fontSize: 14, color: Colors.black45), textAlign: TextAlign.start, ),

                          Padding(
                            padding: EdgeInsets.fromLTRB(0, 0, 20, 10),
                            child: TextFormField(
                              initialValue: server.address,
                                decoration: InputDecoration(
                                  hintStyle: TextStyle(color: Colors.black26),
                                  hintText: "Entreu el servidor",
                                ),
                                onChanged: (v) {
                                  server.address = v;
                                }),
                          ),
                          Text("Server Port", style: TextStyle(fontSize: 14, color: Colors.black45), textAlign: TextAlign.start, ),

                          Padding(
                            padding: EdgeInsets.fromLTRB(0, 0, 20, 10),
                            child: TextFormField(
                              initialValue: "${server.port}",
                                decoration: InputDecoration(
                                  hintStyle: TextStyle(color: Colors.black26),
                                  hintText: "Entreu el port",
                                ),
                                onChanged: (v) {
                                  server.port = int.parse(v);
                                }),
                          ),
                          Text("Clau", style: TextStyle(fontSize: 14, color: Colors.black45), textAlign: TextAlign.start, ),

                          Padding(
                            padding: EdgeInsets.fromLTRB(0, 0, 20, 10),
                            child: TextFormField(
                                initialValue: server.clau,
                                decoration: InputDecoration(
                                  hintStyle: TextStyle(color: Colors.black26),
                                  hintText: "Entreu la clau",
                                ),
                                onChanged: (v) {
                                  server.clau = v;
                                }),
                          ),

                        ],
                      ),
                    ),
                  )
                : SizedBox.shrink(),

            selectSession
                ? Container(
                    width: 300,
                    height: 400,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey, width: 2),
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      color: Colors.white,
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, 0, 0, 20),
                      child: Column(
                        children: [
                          Container(
                            height: 30,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  "Seleccioneu una sessió",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Spacer(),
                                IconButton(
                                    onPressed: () {
                                      setState(() {
                                        session = -1;
                                        sessionName = "";
                                        selectSession = false;
                                      });
                                    },
                                    icon: Icon(Icons.close)),
                              ],
                            ),
                          ),
                          Divider(),
                          Container(
                            height: 260,
                            child: ListView(
                              children: sessions
                                  .map(
                                    (e) => InkWell(
                                      onTap: () {
                                        setState(() {
                                          session = e.id;
                                          sessionName = e.name;
                                          selectSession = false;
                                        });
                                      },
                                      child: Text(
                                        e.name,
                                        textAlign: TextAlign.start,
                                      ),
                                    ),
                                  )
                                  .toList(), // map
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : SizedBox.shrink(),
           ],
        ),
      ),
// This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}

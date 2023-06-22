import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'Usuari.dart';
import 'dart:math';

const double degToRad = pi / 180.0;
const double mileToMeters = 1852.0;

class RadarPainter extends CustomPainter {

  double heading;
  LocationData centerLocation;
  List<Usuari> usuaris ;
  double scale;

  RadarPainter(this.heading, this.centerLocation, this.usuaris, this.scale);

  double distance(double xp, double yp){
      return sqrt(xp * xp + yp * yp);
  }

  double xp(double lon){
    return (lon - centerLocation.longitude!) * cos(centerLocation.latitude! * degToRad) * 60.0 * mileToMeters;
  }

  double yp(double lat){
    return -(lat - centerLocation.latitude!) * 60.0 * mileToMeters ;
  }

  @override
  void paint(Canvas canvas, Size size) {


    var viewCenter = Offset(size.width/2.0, size.height/2.0);
    var x = viewCenter + Offset(70, 40);
    var x1 = viewCenter + Offset(80, 30);

    var paint = Paint()
      ..color = Colors.orange
      ..strokeWidth = 15;

    var paintCircle = Paint()
      ..color = Colors.green
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    var paintCircle2 = Paint()
      ..color = Colors.green
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    Offset start = Offset(0, size.height / 2);
    Offset end = Offset(size.width, size.height / 2);

    // 3 Circles de 100 a 300 m de distància.
    for(var r = 100.0 ; r / scale < 400.0; r += 100.0 ) {
      if ((r-500.0).abs() < 1.0 || (r-1000.0).abs() < 1.0){
        canvas.drawCircle(viewCenter, r / scale, paintCircle2);
      }else {
        canvas.drawCircle(viewCenter, r / scale, paintCircle);
      }
     }

    canvas.drawLine(Offset(size.width/2.0,0), Offset(size.width/2.0, size.height ), paintCircle);
    canvas.drawLine(Offset(0, size.height/2.0), Offset(size.width, size.height/2.0), paintCircle);

    // First we compute the maximum distance to compute scale
    var maxDis = 0.0;
    for(var usuari in usuaris){
      var d = distance(xp(usuari.lon), usuari.lat);
      maxDis = max(maxDis, d);
    }

    // Usually a scale of 1.0 (1m -> 1 pt is ok and easier to check)


    for(var usuari in usuaris){
      var x = xp(usuari.lon);
      var y = yp(usuari.lat);

      var o = Offset(x, y);
      var dir = o.direction - (heading  ?? 0.0) * degToRad;
      var d = o.distance / scale;

      var o1 = Offset.fromDirection(dir, d);

      var offset = o1 + viewCenter;

      canvas.drawCircle(offset, 5.0, paint);
    }

  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}
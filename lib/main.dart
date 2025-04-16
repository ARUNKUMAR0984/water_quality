import 'package:flutter/material.dart';
import 'package:water_quality/home_screen.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Water Quality',
      debugShowCheckedModeBanner: false,
      home: HomeScreen(),
    );
  }
}

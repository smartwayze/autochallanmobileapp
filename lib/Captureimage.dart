import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:io';

late List<CameraDescription> cameras;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(ParkingMonitorApp());
}

class ParkingMonitorApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ParkingMonitorScreen(),
    );
  }
}

class ParkingMonitorScreen extends StatefulWidget {
  @override
  _ParkingMonitorScreenState createState() => _ParkingMonitorScreenState();
}

class _ParkingMonitorScreenState extends State<ParkingMonitorScreen> {
  late CameraController _controller;
  bool isCarOutside = false;
  Timer? _timer;
  late Interpreter _interpreter;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _loadModel();
  }

  void _initializeCamera() async {
    _controller = CameraController(cameras[0], ResolutionPreset.medium);
    await _controller.initialize();
    if (!mounted) return;
    setState(() {});
    _startDetection();
  }

  void _loadModel() async {
    _interpreter = await Interpreter.fromAsset('assets/car_detection.tflite');
  }

  void _startDetection() {
    // Mock detection function (Replace with actual TFLite detection)
    Timer.periodic(Duration(seconds: 2), (timer) {
      bool detectedOutside = _detectCarOutside();

      if (detectedOutside && !isCarOutside) {
        isCarOutside = true;
        _startTimer();
      } else if (!detectedOutside && isCarOutside) {
        isCarOutside = false;
        _timer?.cancel();
      }
    });
  }

  bool _detectCarOutside() {
    // Replace this logic with TensorFlow Lite detection
    return DateTime.now().second % 10 < 5; // Mock detection logic
  }

  void _startTimer() {
    _timer = Timer(Duration(minutes: 5), () {
      _captureImage();
    });
  }

  void _captureImage() async {
    final XFile image = await _controller.takePicture();
    final directory = await getApplicationDocumentsDirectory();
    final String imagePath = '${directory.path}/car_outside_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(imagePath).writeAsBytes(await image.readAsBytes());
    print('Image saved: $imagePath');
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Parking Monitor")),
      body: _controller.value.isInitialized
          ? CameraPreview(_controller)
          : Center(child: CircularProgressIndicator()),
    );
  }
}

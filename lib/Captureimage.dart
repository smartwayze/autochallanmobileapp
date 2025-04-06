import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter_countdown_timer/flutter_countdown_timer.dart';

List<CameraDescription> cameras = [];

void main() async {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Remove the debug banner
      home: CaptureImagePage(),
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
    );
  }
}

class CaptureImagePage extends StatefulWidget {
  const CaptureImagePage({super.key});

  @override
  _CaptureImagePageState createState() => _CaptureImagePageState();
}

class _CaptureImagePageState extends State<CaptureImagePage> {
  CameraController? _cameraController;
  late CameraDescription camera;
  bool isWrongParkingDetected = false;
  int endTime = DateTime.now().millisecondsSinceEpoch + 5 * 60 * 1000;
  VehicleDetectionModel vehicleDetectionModel = VehicleDetectionModel();

  @override
  void initState() {
    super.initState();
    camera = cameras[0];
    _cameraController = CameraController(camera, ResolutionPreset.high);
    _cameraController?.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
    });
    vehicleDetectionModel.loadModel();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    vehicleDetectionModel.close();
    super.dispose();
  }

  void startCountdown() {
    setState(() {
      endTime = DateTime.now().millisecondsSinceEpoch + 5 * 60 * 1000;
      isWrongParkingDetected = true;
    });
  }

  void detectVehicle(Uint8List inputData) async {
    List<dynamic> prediction = await vehicleDetectionModel.predict(inputData);
    if (prediction.isNotEmpty && prediction[0] == 'wrong_parking') {
      startCountdown();
    }
  }

  void captureImage() async {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      XFile image = await _cameraController!.takePicture();
      saveToDatabase(image);
    }
  }

  void saveToDatabase(XFile image) {
    String path = image.path;
    DatabaseHelper().insertVehicle({
      'image_path': path,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<Uint8List> convertImageToByteData(XFile image) async {
    final file = File(image.path);
    final bytes = await file.readAsBytes();
    return bytes;
  }

  @override
  Widget build(BuildContext context) {
    if (!_cameraController!.value.isInitialized) {
      return Scaffold(
        backgroundColor: const Color(0xFF1E3A8A), // Set background color
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Vehicle Detection",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white, // Set the text color to white
          ),
        ),
        centerTitle: false,  // Align title to the left
        backgroundColor: const Color(0xFF1E3A8A), // Set AppBar color
        elevation: 0,  // Remove shadow effect
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Camera preview with a rounded border
            ClipRRect(
              borderRadius: BorderRadius.circular(16.0),
              child: Container(
                width: double.infinity,
                height: 400,
                child: CameraPreview(_cameraController!),
              ),
            ),
            SizedBox(height: 16),
            // Only show countdown if wrong parking is detected
            isWrongParkingDetected
                ? Card(
              margin: EdgeInsets.symmetric(horizontal: 20),
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CountdownTimer(
                  endTime: endTime,
                  widgetBuilder: (_, time) {
                    if (time == null && isWrongParkingDetected) {
                      captureImage();
                      isWrongParkingDetected = false; // avoid capturing repeatedly
                    }
                    return Text(
                      'Time remaining: ${time?.min ?? 0}:${time?.sec?.toString().padLeft(2, '0') ?? '00'}',
                      style: TextStyle(fontSize: 24, color: Colors.white),
                    );
                  },
                ),
              ),
            )
                : Container(),
            SizedBox(height: 16),
            // Display message for wrong parking detection
            isWrongParkingDetected
                ? Text(
              "Vehicle detected in wrong parking spot",
              style: TextStyle(color: Colors.red, fontSize: 18),
            )
                : Container(),
          ],
        ),
      ),
      bottomNavigationBar: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: BottomAppBar(
          color: const Color(0xFF1E3A8A), // Set BottomNavigationBar color
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "Parking System",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------
// Vehicle Detection Model
// ------------------------

class VehicleDetectionModel {
  late Interpreter _interpreter;

  Future<void> loadModel() async {
    _interpreter = await Interpreter.fromAsset('assets/best_float32.tflite');
  }

  Future<List<dynamic>> predict(Uint8List inputData) async {
    // Placeholder: real implementation would include image pre-processing
    // and correct input/output tensor shaping.
    var input = [List.filled(224 * 224 * 3, 0.0)]; // Fake input shape for example
    var output = List.filled(1, 0); // Output shape depends on your model
    _interpreter.run(input, output);

    // Example: return dummy result
    return ['wrong_parking']; // Change logic as per your actual model
  }

  void close() {
    _interpreter.close();
  }
}

// ------------------------
// SQLite Helper
// ------------------------

class DatabaseHelper {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await openDatabase(
      join(await getDatabasesPath(), 'parking.db'),
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE vehicles(id INTEGER PRIMARY KEY, image_path TEXT, timestamp TEXT)',
        );
      },
      version: 1,
    );
    return _database!;
  }

  Future<void> insertVehicle(Map<String, dynamic> vehicle) async {
    final db = await database;
    await db.insert(
      'vehicles',
      vehicle,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

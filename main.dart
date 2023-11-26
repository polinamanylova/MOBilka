import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors/sensors.dart';
import 'package:camera/camera.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  //виджет с данными о местоположении
  String _locationData = 'Местоположение не определено';
  String _accelerometerData = 'Данные акселерометра не определены';
  String _gyroscopeData = 'Данные гироскопа не определены';
  String _address = 'Адрес не определен';

  late List<CameraDescription> cameras;
  late CameraController _controller;
  bool isCameraReady = false;
  bool _isCapturing = false;

  late PageController _pageController;
  int _currentPage = 0;

  final String apiKey = 'e47f9f97c3977ec53179cbebc8e06d7716872d03';

  @override
  void initState() {
    super.initState();
    _getLocation();
    _getSensorData();
    _initializeCamera();
    _pageController = PageController(initialPage: 0);
  }

  //работа с камерой
  Future<void> _initializeCamera() async {
    try {
      cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw 'Камера недоступна';
      } //проверка доступных камер

      _controller = CameraController(cameras[0], ResolutionPreset.high);

// Инициализация контроллера камеры
      await _controller.initialize();

      // Установление режима вспышки на автоматический
      await _controller.setFlashMode(FlashMode.auto);

// Проверка, что виджет все еще существует
      if (!mounted) {
        return;
      }

      setState(() {
        isCameraReady = true;
      });
    } catch (e) {
      print('Ошибка инициализации камеры: $e');
      setState(() {
        isCameraReady = false;
      });
    }
  }

  Future<void> _capturePhoto() async {
    if (!_isCapturing &&
        MediaQuery.of(context).orientation == Orientation.portrait) {
      setState(() {
        _isCapturing = true;
      });

      try {
        // Перед съемкой установите режим вспышки на автоматический
        await _controller.setFlashMode(FlashMode.auto);

        final XFile photo = await _controller.takePicture();
        print('Фотография сохранена по пути: ${photo.path}');

        // Сохранение фотографии в галерею
        await GallerySaver.saveImage(photo.path);

        // Здесь вы можете выполнить дополнительные действия с фотографией
      } catch (e) {
        print('Ошибка при съемке фотографии: $e');
      } finally {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _getLocation() async {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    await _getAddressFromApi(position.latitude, position.longitude);

    setState(() {
      _locationData =
          'Широта: ${position.latitude}, Долгота: ${position.longitude}';
    });
  }

  Future<void> _getAddressFromApi(double latitude, double longitude) async {
    final apiUrl =
        'https://suggestions.dadata.ru/suggestions/api/4_1/rs/geolocate/address';
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Token $apiKey',
    };

    final body = jsonEncode({
      'lat': latitude,
      'lon': longitude,
    });

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final address = jsonResponse['suggestions'][0]['value'];

        setState(() {
          _address = 'Текущий адрес: $address';
        });

        print('Текущий адрес: $address');
      } else {
        print('Ошибка при запросе адреса: ${response.statusCode}');
      }
    } catch (e) {
      print('Ошибка при запросе адреса: $e');
    }
  }

  void _getSensorData() {
    accelerometerEvents.listen((AccelerometerEvent event) {
      setState(() {
        _accelerometerData =
            'X: ${event.x.toStringAsFixed(2)}, Y: ${event.y.toStringAsFixed(2)}, Z: ${event.z.toStringAsFixed(2)}';
      });
    });

    gyroscopeEvents.listen((GyroscopeEvent event) {
      setState(() {
        _gyroscopeData =
            'X: ${event.x.toStringAsFixed(2)}, Y: ${event.y.toStringAsFixed(2)}, Z: ${event.z.toStringAsFixed(2)}';
      });
    });
  }

  void _scrollToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildCameraView() {
    if (MediaQuery.of(context).orientation == Orientation.portrait &&
        isCameraReady) {
      return Stack(
        children: [
          CameraPreview(_controller),
          Positioned(
            bottom: 16.0,
            left: 0.0,
            right: 0.0,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: EdgeInsets.only(bottom: 16.0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: FloatingActionButton(
                  onPressed: _capturePhoto,
                  child: _isCapturing
                      ? CircularProgressIndicator()
                      : Icon(Icons.camera_alt),
                  backgroundColor: Colors.blue,
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      return Text(
        'Пожалуйста, переведите устройство в портретный режим, чтобы использовать камеру.',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Особенности устройства'),
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });
        },
        children: [
          // Location tab
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  _locationData,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 20),
                Text(
                  _address,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          // Accelerometer/Gyroscope tab
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  _accelerometerData,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 20),
                Text(
                  _gyroscopeData,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          // Camera tab
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (isCameraReady) _buildCameraView(),
                if (!isCameraReady)
                  Text(
                    'Камера не инициализирована. Пожалуйста, перезапустите приложение.',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.location_on),
            label: 'Location',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.accessibility_new),
            label: 'Motion',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera),
            label: 'Камера',
          ),
        ],
        currentIndex: _currentPage,
        onTap: (index) {
          if (MediaQuery.of(context).orientation == Orientation.portrait) {
            _scrollToPage(index);
          } else {
            print('Пожалуйста, переведите устройство в портретный режим.');
          }
        },
      ),
    );
  }
}

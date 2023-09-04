import 'dart:typed_data';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:usb_serial/usb_serial.dart';
import 'blinkingTimer.dart';
import 'package:http/http.dart' as http;
import 'package:gallery_saver/gallery_saver.dart';
import 'package:web_socket_channel/io.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:hello_cam/videoUtil.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:gesture_zoom_box/gesture_zoom_box.dart';
import 'package:image_gallery_saver_v3/image_gallery_saver.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';
import 'package:progress_dialog_null_safe/progress_dialog_null_safe.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async { 
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}


class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      title: "ESP 32 CAM",
      home: Home(
        channel: IOWebSocketChannel.connect('ws://192.168.1.122:8888'),
      ),
    );
  }
}

class Home extends StatefulWidget {
  final WebSocketChannel channel;

  Home({Key? key, required this.channel}) : super(key: key);

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  late UsbPort _port;
  String _message = '';
  final double videoWidth = 640;
  final double videoHeight = 480;
  final ImageGallerySaver _imageGallerySaver = ImageGallerySaver();

  double newVideoSizeWidth = 640.0; // Initialize with 640.0
  double newVideoSizeHeight = 480.0; // Initialize with 480.0
  late Timer _timer;
  late bool isLandscape; // Mark as late
  late String _timeString;
  late bool isRecording;
  final FlutterFFmpeg _flutterFFmpeg = new FlutterFFmpeg();

  late int frameNum;


  late ProgressDialog pr;
  GlobalKey _globalKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _initSerial();
    isLandscape = false;
    isRecording=false;
    _timeString = _formatDateTime(DateTime.now());
    Timer.periodic(Duration(seconds: 1), (Timer t) => _getTime());
    frameNum = 0;
    VideoUtil.workPath = 'images';
    VideoUtil.getAppTempDirectory();

    pr = ProgressDialog(context,
        type: ProgressDialogType.normal, isDismissible: false, showLogs: false);
    pr.style(
        message: 'Saving video ...',
        borderRadius: 10,
        backgroundColor: Colors.black,
        progressWidget: CircularProgressIndicator(),
        elevation: 10,
        insetAnimCurve: Curves.easeInOut,
        messageTextStyle: TextStyle(
            color: Colors.white70, fontSize: 17, fontWeight: FontWeight.w300));

  }

  @override
  void dispose() {
    widget.channel.sink.close();
    super.dispose();
  }

  // Define functions for button actions
  void startStopVideoRecording() {
    // Add functionality for starting/stopping video recording here
  }

  void takePhoto() {
    // Add functionality for taking a photo here
  }

  void toggleMicrophone() {
    // Add functionality for toggling the microphone here
  }

  void controlSpeakerVolume() {
    // Add functionality for controlling speaker volume here
  }

  void showNotifications() {
    // Add functionality for showing notifications here
  }

  // Function to take a screenshot


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: OrientationBuilder(builder: (context, orientation) {
        var screenWidth = MediaQuery.of(context).size.width;
        var screenHeight = MediaQuery.of(context).size.height;

        if (orientation == Orientation.portrait) {
          isLandscape = false;
          newVideoSizeWidth =
          screenWidth > videoWidth ? videoWidth.toDouble() : screenWidth;
          newVideoSizeHeight = videoHeight * newVideoSizeWidth / videoWidth;
        } else {
          isLandscape = true;
          newVideoSizeHeight = screenHeight > videoHeight
              ? videoHeight.toDouble()
              : screenHeight;
          newVideoSizeWidth = videoWidth * newVideoSizeHeight / videoHeight;
        }

        return Container(
          color: Colors.black,
          child: StreamBuilder(
            stream: widget.channel.stream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                );
              } else {
                if (isRecording) {
                  VideoUtil.saveImageFileToDirectory(
                      snapshot.data, 'image_$frameNum.jpg');
                  frameNum++;
                }
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Column(
                      children: <Widget>[
                        SizedBox(
                          height: isLandscape ? 0 : 30,
                        ),
                        Stack(
                          children: <Widget>[
                            RepaintBoundary(
                              key: _globalKey,
                              child: GestureZoomBox(
                                maxScale: 5.0,
                                doubleTapScale: 2.0,
                                duration: Duration(milliseconds: 200),
                                child: Image.memory(
                                  snapshot.data,
                                  gaplessPlayback: true,
                                  width: newVideoSizeWidth,
                                  height: newVideoSizeHeight,
                                ),
                              ),
                            ),
                            Positioned.fill(
                                child: Align(
                                  child: Column(
                                    children: <Widget>[
                                      SizedBox(
                                        height: 16,
                                      ),
                                      Text(
                                        'ESP32\'s cam',
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w300),
                                      ),
                                      SizedBox(
                                        height: 4,
                                      ),
                                      Text(
                                        'Live | $_timeString',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w300),
                                      ),
                                      SizedBox(
                                        height: 16,
                                      ),
                                      isRecording ? BlinkingTimer() : Container(),
                                    ],
                                  ),
                                  alignment: Alignment.topCenter,
                                ))
                          ],
                        ),
                        Expanded(
                          flex: 1,
                          child: Container(
                            color: Colors.black,
                            width: MediaQuery.of(context).size.width,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment:
                                MainAxisAlignment.spaceEvenly,
                                children: <Widget>[
                                  IconButton(
                                    icon: Icon(
                                      isRecording ? Icons.stop : Icons.videocam,
                                      size: 24,
                                    ),
                                    onPressed: videoRecording,
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.photo_camera, size: 24),
                                    onPressed: takeScreenShot,
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.mic, size: 24),
                                    onPressed: toggleMicrophone,
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.speaker, size: 24),
                                    onPressed: sendDataToESP32,
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.add_alert, size: 24),
                                    onPressed: showNotifications,
                                  )
                                ],
                              ),
                            ),
                          ),
                        )
                      ],
                    ),
                  ],
                );
              }
            },
          ),
        );
      }),
      floatingActionButton: _getFab(),
    );
  }
  takeScreenShot() async {















    RenderRepaintBoundary boundary =
    _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    var image = await boundary.toImage();
    var byteData = await image.toByteData(format: ImageByteFormat.png);

    var pngBytes = byteData?.buffer.asUint8List();
    final directory = await getExternalStorageDirectory();
    if (directory != null && directory.existsSync()) {
      // Check if external storage is available

        // External storage is mounted and available
        final res = await ImageGallerySaver.saveImage(pngBytes!);
        print('Image saved: $res');

    } else {
      print('External storage directory not found.');
    }

    Fluttertoast.showToast(
        msg:  "ScreenShot Saved" ,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0);
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('MM/dd hh:mm:ss aaa').format(dateTime);
  }

  void _getTime() {
    final DateTime now = DateTime.now();
    setState(() {
      _timeString = _formatDateTime(now);
    });
  }

  Widget _getFab() {
    return SpeedDial(
      animatedIcon: AnimatedIcons.menu_close,
      animatedIconTheme: IconThemeData(size: 22),
      visible: isLandscape,
      curve: Curves.bounceIn,
      children: [
        SpeedDialChild(
          child: Icon(Icons.photo_camera),
          onTap: takeScreenShot,
        ),
        SpeedDialChild(
            child: isRecording ? Icon(Icons.stop) : Icon(Icons.videocam),
            onTap: videoRecording)
      ],
    );
  }

  videoRecording() {
    isRecording = !isRecording;

    if (!isRecording && frameNum > 0) {
      frameNum = 0;
      makeVideoWithFFMpeg();
    }
  }

  Future<int> execute(String command) async {
    return await _flutterFFmpeg.execute(command);
  }

  makeVideoWithFFMpeg() {
    pr.show();
    String tempVideofileName = "${DateTime.now().millisecondsSinceEpoch}.mp4";
    execute(VideoUtil.generateEncodeVideoScript("mpeg4", tempVideofileName))
        .then((rc) {
      pr.hide();
      if (rc == 0) {
        print("Video complete");

        String outputPath = VideoUtil.appTempDir + "/$tempVideofileName";
        _saveVideo(outputPath);
      }
    });
  }

  _saveVideo(String path) async {
    GallerySaver.saveVideo(path).then((result) {
      print("Video Save result : $result");

      Fluttertoast.showToast(
          msg: "video saved",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0);

      VideoUtil.deleteTempDirectory();
    });

    }
  void _initSerial() async {
    List<UsbDevice> devices = await UsbSerial.listDevices();
    if (devices.isNotEmpty) {
      UsbDevice device = devices[0]; // Use the first device (you may need to check for the correct one)
      _port = (await device.create())!;
      await _port.open();
    }
  }
  void _sendData() async {
    if (_port != null) {
      String dataToSend = "Your data here";
      await _port.write(Uint8List.fromList(dataToSend.codeUnits));
      setState(() {
        _message = "Sent: $dataToSend";
      });
    } else {
      print("np");
      setState(() {
        _message = "No serial port available.";
      });
    }
  }

  Future<void> sendDataToESP32() async {
    final url = Uri.parse('http://192.168.1.122:8080'); // Replace with your ESP32's IP address

    try {
      final response = await http.post(
        url,
        body: {'key': 'jhgj'}, // Replace with your data
      );

      if (response.statusCode == 200) {
        print('Data sent successfully');
      } else {
        print('Failed to send data. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error sending data: $e');
    }
  }




}


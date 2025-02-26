import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ionicons/ionicons.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'websocket_manager.dart';
import 'file_uploader.dart';
import 'pre_processing.dart';
import 'dart:developer';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Artbot Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Color(0xFF501214)),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Artbot Demo Home Page'),
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
  int currentPageIndex = 0;
  double imageResolution = 100.0;
  double backlashCompensation = 3.0;
  bool isWebSocketConnected = false; // Track WebSocket status
  late WebSocketManager webSocketManager;
  String receivedMessage = "No data received";
  TextEditingController ipController = TextEditingController();

  List<Map<String, dynamic>> settingsList = [];

  @override
  void initState() {
    super.initState();

    webSocketManager = WebSocketManager(
      onMessageReceived: (message) {
        setState(() {
          receivedMessage = message;
        });
      },
    );

    // Listen for WebSocket connection status updates
    webSocketManager.connectionStatusStream.listen((status) {
      setState(() {
        isWebSocketConnected = status;
      });
    });

    _loadIPAddress();
    webSocketManager.connect();

    settingsList = [
      {
        "title": "Wifi IP Address",
        "description": "ESP32 IP Address",
        "getValue": () => webSocketManager.ipAddress,
        "setValue": (double newValue) async {
          String newIp = newValue.toString();
          await webSocketManager.setIPAddress(newIp);
          setState(() => imageResolution = newValue);
        },
      },
      {
        "title": "Backlash Compensation",
        "description":
            "How much the motor will reverse before changing direction",
        "getValue": () => backlashCompensation,
        "setValue": (double newValue) =>
            setState(() => backlashCompensation = newValue),
      },
    ];

    webSocketManager = WebSocketManager(
      onMessageReceived: (message) {
        setState(() {
          receivedMessage = message;
        });
      },
    );
    _loadIPAddress();
    webSocketManager.connect();
  }

  /// Loads the stored IP address
  Future<void> _loadIPAddress() async {
    await webSocketManager.loadIPAddress();
    setState(() {
      ipController.text = webSocketManager.ipAddress;
    });
  }

  /// Saves new IP and reconnects WebSocket
  void _changeIPAddress() async {
    String newIp = ipController.text.trim();
    if (newIp.isNotEmpty) {
      await webSocketManager.setIPAddress(newIp);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("IP Address changed to $newIp")),
      );
    }
  }

  @override
  void dispose() {
    webSocketManager.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF501214),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Artbot Status',
                  style: TextStyle(
                    fontSize: 20, // Adjust font size as needed
                    decoration: TextDecoration.underline, // Add underline
                    decorationColor: Color(0xFFAC9155),
                    color: Color(0xFFAC9155),
                  ),
                ),
                Text(isWebSocketConnected ? 'Connected' : 'Disconnected',
                    style: TextStyle(
                      fontSize: 15,
                      color: isWebSocketConnected
                          ? Color.fromARGB(255, 0, 230, 0) // Green if connected
                          : Colors.red, // Red if disconnected
                    )),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>(
            (Set<WidgetState> states) => states.contains(WidgetState.selected)
                ? const TextStyle(fontSize: 11, color: Color(0xFFAC9155))
                : const TextStyle(fontSize: 11, color: Color(0xFFAC9155)),
          ),
        ),
        child: NavigationBar(
          backgroundColor: Color(0xFF501214),
          onDestinationSelected: (int index) {
            if (index == 1) {
              // Open Camera
              _captureAndProcessImage(context);
            } else if (index == 2) {
              // Open file manager
              _selectAndProcessImage(context);
            } else if (index == 3) {
              // Open Gamepad
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          const GamepadPage(title: 'Gamepad Page')));
            } else {
              setState(() {
                currentPageIndex = index;
              });
            }
          },
          indicatorColor: Color(0xFFAC9155),
          selectedIndex: currentPageIndex,
          destinations: const <Widget>[
            NavigationDestination(
              icon: Icon(Icons.home, color: Color(0xFFAC9155)),
              label: 'Home',
              selectedIcon: Icon(Icons.home, color: Color(0xFF501214)),
            ), //Home
            NavigationDestination(
              icon: Icon(Icons.photo_camera, color: Color(0xFFAC9155)),
              label: 'Camera',
              selectedIcon: Icon(Icons.photo_camera, color: Color(0xFF501214)),
            ), //Camera
            NavigationDestination(
              icon: Icon(Icons.folder, color: Color(0xFFAC9155)),
              label: 'Upload',
              selectedIcon: Icon(Icons.folder, color: Color(0xFF501214)),
            ), //Upload
            NavigationDestination(
              icon: Icon(Icons.sports_esports, color: Color(0xFFAC9155)),
              label: 'Interactive',
              selectedIcon:
                  Icon(Icons.sports_esports, color: Color(0xFF501214)),
            ), //Interactive
            NavigationDestination(
              icon: Icon(Icons.edit, color: Color(0xFFAC9155)),
              label: 'Drawing',
              selectedIcon: Icon(Icons.cruelty_free, color: Color(0xFF501214)),
            ), //Websocket
            NavigationDestination(
              icon: Icon(Icons.settings, color: Color(0xFFAC9155)),
              label: 'Settings',
              selectedIcon: Icon(Icons.settings, color: Color(0xFF501214)),
            ) //Settings
          ],
        ),
      ),
      body: <Widget>[
        /// Home page
        Card(
          shadowColor: Colors.transparent,
          margin: const EdgeInsets.all(8.0),
          color: Colors.white, // Set the background color here
          child: SizedBox.expand(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  //SizedBox(height: 10), // Add some space between the images
                  Image.asset(
                    'assets/Logo v4.png', // Replace with your image path
                    fit: BoxFit.cover,
                  ),
                  SizedBox(height: 50), // Add some space between the images
                ],
              ),
            ),
          ),
        ), //Home
        Card(), //Camera(Blank)
        Card(), //Files(Blank)
        Card(), //Interactive(Blank)
        //Card(), //Interactive(Blank)
        Card(
          shadowColor: Colors.transparent,
          margin: const EdgeInsets.all(8.0),
          color: Colors.white,
          child: SizedBox.expand(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: DrawingBoard(
                      background: Container(
                        width: 400,
                        height: 400,
                        color: Colors.white,
                      ),
                      showDefaultActions: true, /// Enables default toolbar actions
                      showDefaultTools: true,   /// Displays the default drawing tools
                    ),
                  ),
                ],
              ),
            ),
          ),
        ), //Websocket
        Card(
          shadowColor: Colors.transparent,
          margin: const EdgeInsets.all(8.0),
          color: Colors.white,
          child: SizedBox.expand(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text("Received: $receivedMessage"),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => webSocketManager.connect(),
                    child: Text('Reconnect Websocket'),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: settingsList.length, // Use dynamic count
                      itemBuilder: (context, index) {
                        return ListTile(
                          leading:
                              Icon(Icons.settings, color: Color(0xFF501214)),
                          title: Text(settingsList[index]["title"]),
                          subtitle: Text(settingsList[index]["description"]),
                          trailing: Text(
                              settingsList[index]["value"].toString(),
                              style: TextStyle(fontSize: 15)),
                          onTap: () async {
                            String? newValue = await showDialog<String>(
                              context: context,
                              builder: (BuildContext context) {
                                TextEditingController controller =
                                    TextEditingController();
                                return AlertDialog(
                                  title: Text('Enter new value'),
                                  content: TextField(
                                    controller: controller,
                                    decoration:
                                        InputDecoration(hintText: 'New value'),
                                  ),
                                  actions: <Widget>[
                                    TextButton(
                                      child: Text('Cancel'),
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      },
                                    ),
                                    TextButton(
                                      child: Text('OK'),
                                      onPressed: () {
                                        Navigator.of(context)
                                            .pop(controller.text);
                                      },
                                    ),
                                  ],
                                );
                              },
                            );
                            if (newValue != null && newValue.isNotEmpty) {
                              setState(() {
                                settingsList[index]["value"] =
                                    double.parse(newValue);
                              });
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ), //Settings

        /// Notifications page
      ][currentPageIndex],
    );
  }
}

//gamepad page
class GamepadPage extends StatefulWidget {
  const GamepadPage({super.key, required this.title});

  final String title;

  @override
  State<GamepadPage> createState() => _GamepadPageState();
}

//gamepad page state
class _GamepadPageState extends State<GamepadPage> {
  late WebSocketManager webSocketManager;

  @override
  void initState() {
    super.initState();
    // Lock the orientation to landscape when this page is opened
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    webSocketManager = WebSocketManager();
    webSocketManager.connect();
  }

  @override
  void dispose() {
    webSocketManager.disconnect();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  void sendJoystickData(double x, double y) {
    String message = "JOYSTICK:${x.toStringAsFixed(4)}:${y.toStringAsFixed(4)}";
    webSocketManager.sendMessage(message);
  }

  void sendWebSocketMessage(String message) {
    webSocketManager.sendMessage(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Color(0xFFAC9155),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              // Navigate to the first card
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => MyHomePage(title: 'Gamepad Page'),
                ),
                (Route<dynamic> route) => false,
              );
            },
            color: Color(0xFF501214), // Set the arrow color
          ),
        ),
        backgroundColor: Color(0xFFAC9155),
        body: Column(children: [
          Expanded(
              child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            // Center in total screen space
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    children: [
                      Joystick(
                        stick: const CircleAvatar(
                          radius: 45,
                          backgroundColor: Color(0xFFAC9155),
                        ),
                        base: Container(
                          width: 275,
                          height: 275,
                          decoration: BoxDecoration(
                            color: Color(0xFF501214),
                            shape: BoxShape.circle,
                          ),
                        ),
                        listener: (details) {
                          sendJoystickData(details.x, details.y);
                        },
                      ),
                      SizedBox(height: 52),
                    ],
                  ),

                  SizedBox(width: 150),
                  // Space between joystick and buttons

                  // Button layout (plus shape)
                  Column(

                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularButton(
                        icon: Ionicons.triangle,
                        color: Colors.blue.shade700,
                        onPressed: () => sendWebSocketMessage("CMD:TRIANGLE"),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularButton(
                            icon: Ionicons.square,
                            color: Colors.green.shade600,
                            onPressed: () => sendWebSocketMessage("CMD:SQUARE"),
                          ),
                          SizedBox(width: 85),
                          // Space between left and right buttons
                          CircularButton(
                            icon: Icons.circle,
                            color: Colors.yellowAccent.shade400,
                            onPressed: () => sendWebSocketMessage("CMD:CIRCLE"),
                          ),
                        ],
                      ),
                      CircularButton(
                        icon: Icons.edit,
                        color: Colors.red.shade400,
                        onPressed: () => sendWebSocketMessage("CMD:PENTOGGLE"),
                      ),
                      SizedBox(height: 52),
                    ],
                  ),
                ],
              ),
            ],
          ))
        ]));
  }
}

// Custom circular button widget
class CircularButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const CircularButton({
    super.key,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        shape: CircleBorder(),
        padding: EdgeInsets.all(24),
        backgroundColor: color,
      ),
      child: Icon(icon, size: 36, color: Colors.white),
    );
  }
}

//upload from camera
Future<void> _captureAndProcessImage(BuildContext context) async {
  final ImagePicker picker = ImagePicker();
  final XFile? photo = await picker.pickImage(source: ImageSource.camera);

  if (photo != null) {
    // Process image (Assuming PreProcessing has a static method processImage)
    PreProcessing preProcessor = PreProcessing();
    String processedFilePath = await preProcessor.processImage(photo.path);
    // Send file via HTTP POST using the dynamic IP address
    bool success = await FileUploader.uploadFile(processedFilePath);
    // Show result in Snackbar
    if (success) {
      // Display when upload is successful
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("File Transfer Successful.")),
      );
    } else {
      // Display when upload fails
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("File upload failed!")),
      );
    }
  }
}

//upload from folder
Future<void> _selectAndProcessImage(BuildContext context) async {
  FilePickerResult? result = await FilePicker.platform.pickFiles(
    type: FileType.image, // Only allow image files
    withReadStream: true,
  );
  if (result != null) {
    PlatformFile file = result.files.single;


    log("Original File Name: ${file.name}", name: "Artbot");
    debugPrint("Original File Name: ${file.name}");
    debugPrint("Original File Path: ${file.path}"); // Might be cached


    String filePath = result.files.single.path!;
    // Process the selected image (Assuming PreProcessing has a static method processImage)
    PreProcessing preProcessor = PreProcessing();
    String processedFilePath = await preProcessor.processImage(filePath);
    // Send file via HTTP POST using the dynamic IP address
    bool success = await FileUploader.uploadFile(processedFilePath);
    // Show result in Snackbar
    if (success) {
      // Display when upload is successful
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("File Transfer Successful.")),
      );
    } else {
      // Display when upload fails
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("File upload failed!")),
      );
    }
  } else {
    // Display when no file is selected
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("No file selected")),
    );
  }
}

Future<void> _selectAndProcessImageTest(BuildContext context) async {
  FilePickerResult? result = await FilePicker.platform.pickFiles(
    type: FileType.image, // Allow only image files
  );

  if (result != null) {
    String filePath = result.files.single.path!;

    PreProcessing preProcessor = PreProcessing();
    String processedFilePath = await preProcessor.processImage(filePath);

    // Generate new file path by appending "_preprocess" before the extension
    String newFilePath = filePath.replaceAllMapped(RegExp(r"(.+)(\.[^.]+)"), (match) {
      return "${match[1]}_preprocess${match[2]}";
    });


    // Save the processed image
    File processedFile = File(processedFilePath);
    if (processedFile.existsSync()) {
      await processedFile.copy(newFilePath);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("File processed and saved as $newFilePath")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Processing failed, file not saved.")),
      );
    }
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("No file selected")),
    );
  }
}

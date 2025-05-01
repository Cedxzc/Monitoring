import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import 'CollectionListPage.dart';
import 'package:permission_handler/permission_handler.dart'; // Add permission handler
import 'CreateCrr.dart';
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Location Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        inputDecorationTheme: InputDecorationTheme(
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.blue, width: 2),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: const MyHomePage(title: 'Mapping Coordinates'),
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
  String _coordinates = "";
  List<Map<String, String>> _savedCoordinates = [];
  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _contactNumberController = TextEditingController();
  final TextEditingController _agentController = TextEditingController();
  List<String> _selectedPurposes = [];
  String? _selectedAgent;
  String _selectedRemark = "Store Closed";
  bool _isLocationFetched = false;
  bool _isLoading = false;
  List<String> _agents = [];
  bool _isSavedCoordinatesVisible = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCoordinates();
    _loadAgents();
    
  }

  Future<void> _getLocation() async {
    setState(() {
      _isLoading = true;
    });

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _coordinates = "Location services are disabled.";
        _isLoading = false;
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _coordinates = "Location permissions are denied.";
          _isLoading = false;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _coordinates = "Location permissions are permanently denied.";
        _isLoading = false;
      });
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _coordinates = "Lat: ${position.latitude}, Lng: ${position.longitude}";
      _isLocationFetched = true;
      _isLoading = false;
    });
  }

  Future<void> _saveCoordinates() async {
    if (_coordinates.startsWith("Lat")) {
      if (_labelController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Label cannot be empty!"),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      if (_contactNumberController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Contact Number cannot be empty!"),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      if (_selectedAgent == null || _selectedAgent!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Agent cannot be empty!"),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      String timestamp = DateTime.now().toString();
      String label = _labelController.text.trim();
      String contactNumber = _contactNumberController.text.trim();

      Map<String, String> newEntry = {
        "label": label,
        "coordinates": _coordinates,
        "purpose": _selectedPurposes.join(", "),
        "timestamp": timestamp,
        "contactNumber": contactNumber,
        "agent": _selectedAgent!,
        "remarks": _selectedRemark,
      };

      _savedCoordinates.add(newEntry);
      await prefs.setString('saved_coordinates', jsonEncode(_savedCoordinates));

      setState(() {
        _labelController.clear();
        _contactNumberController.clear();
        _coordinates = "";
        _selectedPurposes.clear();
        _selectedAgent = null;
        _isLocationFetched = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Coordinates saved successfully!"),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _loadSavedCoordinates() async {
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString('saved_coordinates');
    if (data != null && data.isNotEmpty) {
      try {
        List<dynamic> jsonData = jsonDecode(data);
        setState(() {
          _savedCoordinates =
              jsonData.map((item) => Map<String, String>.from(item)).toList();
        });
      } catch (e) {
        print("Error loading saved coordinates: $e");
      }
    }
  }

  Future<void> _loadAgents() async {
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString('saved_agents');
    if (data != null && data.isNotEmpty) {
      setState(() {
        _agents = List<String>.from(jsonDecode(data));
      });
    }
  }

  Future<void> _saveAgents() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_agents', jsonEncode(_agents));
  }

  Future<void> _deleteCoordinate(int index) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedCoordinates.removeAt(index);
    });
    await prefs.setString('saved_coordinates', jsonEncode(_savedCoordinates));
  }

  Future<void> _copySingleCoordinate(int index) async {
    Map<String, String> coord = _savedCoordinates[index];

    String copiedText = "Label: ${coord["label"]}\n"
        "Coordinates: ${coord["coordinates"]}\n"
        "Purpose: ${coord["purpose"]}\n"
        "Saved on: ${coord["timestamp"]}\n"
        "Contact Number: ${coord["contactNumber"]}\n"
        "Agent: ${coord["agent"]}\n"
        "Remark: ${coord["remarks"]}";

    await Clipboard.setData(ClipboardData(text: copiedText));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Selected coordinate copied!"),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _addAgent() async {
    String newAgent = _agentController.text.trim();
    if (newAgent.isNotEmpty && !_agents.contains(newAgent)) {
      setState(() {
        _agents.add(newAgent);
        _selectedAgent = newAgent;
        _agentController.clear();
      });
      await _saveAgents();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Agent added successfully!"),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _toggleSavedCoordinatesVisibility() {
    setState(() {
      _isSavedCoordinatesVisible = !_isSavedCoordinatesVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        title: Text(widget.title),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_on,
                    size: 50,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 20),
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Fetching Coordinates...',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  ElevatedButton(
                    onPressed: _getLocation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      elevation: 8,
                    ),
                    child: const Text('Check In', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 10),
                  if (_coordinates.isNotEmpty)
                    Text(
                      _coordinates,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  const SizedBox(height: 10),
                  Visibility(
                    visible: _isLocationFetched,
                    child: Column(
                      children: [
                        TextField(
                          controller: _labelController,
                          decoration: const InputDecoration(
                            labelText: "Enter Label",
                            floatingLabelBehavior: FloatingLabelBehavior.auto,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _contactNumberController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: "Enter Contact Number",
                            floatingLabelBehavior: FloatingLabelBehavior.auto,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            Checkbox(
                              value: _selectedPurposes.contains('SIM Selling'),
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value!) {
                                    _selectedPurposes.add('SIM Selling');
                                  } else {
                                    _selectedPurposes.remove('SIM Selling');
                                  }
                                });
                              },
                            ),
                            const Text('SIM Selling'),
                            Checkbox(
                              value: _selectedPurposes.contains('Load Top Up'),
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value!) {
                                    _selectedPurposes.add('Load Top Up');
                                  } else {
                                    _selectedPurposes.remove('Load Top Up');
                                  }
                                });
                              },
                            ),
                            const Text('Load Top Up'),
                            Checkbox(
                              value: _selectedPurposes.contains('Collection'),
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value!) {
                                    _selectedPurposes.add('Collection');
                                  } else {
                                    _selectedPurposes.remove('Collection');
                                  }
                                });
                              },
                            ),
                            const Text('Collection'),
                          ],
                        ),
                        const SizedBox(height: 10),
                        DropdownButton<String>(
                          value: _selectedRemark,
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedRemark = newValue!;
                            });
                          },
                          items: <String>['Done','Store Closed', 'Customer is not around', 'No money']
                              .map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(value: value, child: Text(value));
                          }).toList(),
                        ),
                        const SizedBox(height: 10),
                        DropdownButton<String>(
                          value: _selectedAgent,
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedAgent = newValue;
                            });
                          },
                          hint: const Text('Select Agent'),
                          items: _agents
                              .map<DropdownMenuItem<String>>((String agent) {
                            return DropdownMenuItem<String>(value: agent, child: Text(agent));
                          }).toList(),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _agentController,
                          decoration: const InputDecoration(
                            labelText: "Add Agent",
                            floatingLabelBehavior: FloatingLabelBehavior.auto,
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _addAgent,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text('Add Agent', style: TextStyle(fontSize: 16)),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                  if (_isLocationFetched)
                    ElevatedButton(
                      onPressed: _saveCoordinates,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        elevation: 8,
                      ),
                      child: const Text('Save Coordinates', style: TextStyle(fontSize: 16)),
                    ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      // Navigate to the Create CRR Page
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const CreateCrrPage()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      elevation: 8,
                    ),
                    child: const Text('Create CRR', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 20),
                ElevatedButton(
  onPressed: () {
    // Navigate to the Collection List Page and pass the saved coordinates
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CollectionListPage(
          savedCoordinates: _savedCoordinates, // Passing the saved coordinates
        ),
      ),
    );
  },
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.orange,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(30),
    ),
    padding: const EdgeInsets.symmetric(vertical: 15),
    elevation: 8,
  ),
  child: const Text('Collection List', style: TextStyle(fontSize: 16)),
),
const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: _toggleSavedCoordinatesVisibility,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      elevation: 8,
                      
                    ),
                    
                    child: const Text('View Saved Coordinates', style: TextStyle(fontSize: 16)),
                  ),
                      if (_isSavedCoordinatesVisible) ...[
                    Expanded(
                      child: ListView.builder(
                        itemCount: _savedCoordinates.length,
                        itemBuilder: (context, index) {
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              title: Text(_savedCoordinates[index]["label"] ?? ''),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Coordinates: ${_savedCoordinates[index]["coordinates"] ?? ''}"),
                                  Text("Purpose: ${_savedCoordinates[index]["purpose"] ?? ''}"),
                                  Text("Contact: ${_savedCoordinates[index]["contactNumber"] ?? ''}"),
                                  Text("Agent: ${_savedCoordinates[index]["agent"] ?? ''}"),
                                  Text("Checked in: ${_savedCoordinates[index]["timestamp"] ?? ''},"),
                                  Text("Remarks: ${_savedCoordinates[index]["remarks"] ?? ''}"),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.copy),
                                    onPressed: () => _copySingleCoordinate(index),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () => _deleteCoordinate(index),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}



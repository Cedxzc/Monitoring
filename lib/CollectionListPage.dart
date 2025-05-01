import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart'; // Add permission handler
class CollectionListPage extends StatefulWidget {
  final List<Map<String, String?>> savedCoordinates;

  const CollectionListPage({super.key, required this.savedCoordinates});

  @override
  _CollectionListPageState createState() => _CollectionListPageState();
}

class _CollectionListPageState extends State<CollectionListPage> {
  List<Map<String, String?>> _filteredCoordinates = [];
  String? _selectedAgentForFilter;
  TextEditingController _labelController = TextEditingController();
  TextEditingController _contactNumberController = TextEditingController();
  String? _selectedAgentForCustomer;

  List<String> _agents = []; // List to store unique agents

  @override
  void initState() {
    super.initState();
    _filteredCoordinates = widget.savedCoordinates;
    _generateAgents();
  }

  // Function to generate unique agents from the savedCoordinates
  void _generateAgents() {
    final agentsSet = <String>{}; // Use a set to ensure unique agents
    for (var coord in widget.savedCoordinates) {
      if (coord['agent'] != null && coord['agent']!.isNotEmpty) {
        agentsSet.add(coord['agent']!); // Add agent to the set
      }
    } 
    setState(() {
      _agents = agentsSet.toList(); // Convert the set back to a list
    });
  }

  // Function to filter coordinates based on selected agent
  void _filterCoordinatesByAgent(String? agent) {
    setState(() {
      if (agent == null || agent.isEmpty) {
        _filteredCoordinates = widget.savedCoordinates;
      } else {
        _filteredCoordinates = widget.savedCoordinates
            .where((coord) => coord['agent'] == agent)
            .toList();
      }
    });
  }

  // Function to show the dialog for adding a customer
  void _showAddCustomerDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Add Customer"),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: _labelController,
                  decoration: const InputDecoration(
                    labelText: "Enter Label",
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _contactNumberController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: "Enter Contact Number",
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButton<String?>(
                  value: _selectedAgentForCustomer,
                  hint: const Text("Select Agent"),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedAgentForCustomer = newValue;
                    });
                  },
                  items: _agents.map<DropdownMenuItem<String?>>((String agent) {
                    return DropdownMenuItem<String?>(
                      value: agent,
                      child: Text(agent),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                if (_labelController.text.isEmpty ||
                    _contactNumberController.text.isEmpty ||
                    _selectedAgentForCustomer == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("All fields are required!"),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                  return;
                }

                // Ensure that the map is of the correct type
                final newCustomer = {
                  'label': _labelController.text,
                  'contact': _contactNumberController.text,
                  'agent': _selectedAgentForCustomer,
                  'coordinates': '0', // Default coordinates value
                };

                setState(() {
                  widget.savedCoordinates.add(newCustomer);
                  _filteredCoordinates = widget.savedCoordinates;
                  _generateAgents(); // Update the agent list after adding a new customer
                });

                _labelController.clear();
                _contactNumberController.clear();
                _selectedAgentForCustomer = null;

                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text('Add Customer'),
            ),
          ],
        );
      },
    );
  }

  // Function to export data to CSV
  Future<void> _exportToCSV() async {
    // Request permission to access storage
    PermissionStatus permissionStatus = await Permission.manageExternalStorage.request();

    if (permissionStatus.isGranted) {
      List<List<String>> rows = [
        ['Label', 'Contact', 'Agent', 'Coordinates'], // CSV header
        ..._filteredCoordinates.map((coord) => [
          coord['label'] ?? 'No label',
          coord['contact'] ?? 'No contact',
          coord['agent'] ?? 'No agent',
          coord['coordinates'] ?? 'No coordinates'
        ])
      ];

      String csvData = const ListToCsvConverter().convert(rows);

      // Get the external storage directory to save the CSV file
      final directory = await getExternalStorageDirectory();
      final path = directory?.path;
      if (path == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Unable to access external storage!")),
        );
        return;
      }

      // Save the CSV file in the external storage directory
      final file = File('$path/customers.csv');
      await file.writeAsString(csvData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("File saved to $path/customers.csv")),
      );
    } else {
      // If permission was denied
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Permission denied! Cannot save file.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        title: const Text('Collection List'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButton<String?>(
              value: _selectedAgentForFilter,
              hint: const Text("Filter by Agent"),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedAgentForFilter = newValue;
                });
                _filterCoordinatesByAgent(newValue);
              },
              items: _agents.map<DropdownMenuItem<String?>>((String agent) {
                return DropdownMenuItem<String?>(
                  value: agent,
                  child: Text(agent),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _showAddCustomerDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(vertical: 15),
                elevation: 8,
              ),
              child: const Text('Add Customer', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _exportToCSV, // Call the export function
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(vertical: 15),
                elevation: 8,
              ),
              child: const Text('Export to CSV', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: _filteredCoordinates.length,
                itemBuilder: (context, index) {
                  final coord = _filteredCoordinates[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    elevation: 5,
                    child: ListTile(  
                      title: Text(coord['label'] ?? 'No label'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Contact: ${coord['contact'] ?? 'No contact'}"),
                          Text("Agent: ${coord['agent'] ?? 'No agent'}"),
                          Text("Coordinates: ${coord['coordinates'] ?? 'No coordinates'}"),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
  
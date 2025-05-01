import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'dart:io';

import 'package:permission_handler/permission_handler.dart'; // Add permission handler

class CreateCrrPage extends StatefulWidget {
  const CreateCrrPage({super.key});

  @override
  _CreateCrrPageState createState() => _CreateCrrPageState();
}

class _CreateCrrPageState extends State<CreateCrrPage> {
  String? _selectedAgent;
  List<String> _agents = []; // This should be loaded from SharedPreferences or some data source.

  @override
  void initState() {
    super.initState();
    // Load the agents here (this can be done from SharedPreferences or any other source).
    _loadAgents();
  }

  Future<void> _loadAgents() async {
    // Assuming you're loading the agents from SharedPreferences (or another source).
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString('saved_agents');
    if (data != null && data.isNotEmpty) {
      setState(() {
        _agents = List<String>.from(jsonDecode(data));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create CRR')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Agent selection dropdown
            DropdownButton<String>(
              value: _selectedAgent,
              hint: const Text('Select Agent'),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedAgent = newValue;
                });
              },
              items: _agents
                  .map<DropdownMenuItem<String>>((String agent) {
                    return DropdownMenuItem<String>(
                      value: agent,
                      child: Text(agent),
                    );
                  }).toList(),
            ),
            const SizedBox(height: 20),

            // Create CRR Button
            ElevatedButton(
              onPressed: () {
                if (_selectedAgent != null) {
                  // Proceed to create CRR with the selected agent
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('CRR Created with Agent: $_selectedAgent'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  // Add your CRR creation logic here
                } else {
                  // Show an error message if no agent is selected
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select an agent.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
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
          ],
        ),
      ),
    );
  }
}
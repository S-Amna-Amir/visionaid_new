import 'package:flutter/material.dart';
import '../shared/colors.dart';

class ModelSelectionPage extends StatelessWidget {
  const ModelSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Select Model"),
        backgroundColor: darkGreen,
      ),
      body: ListView(
        padding: EdgeInsets.all(20),
        children: [

          ListTile(
            title: Text("Assistive Live"),
            onTap: () => Navigator.pushNamed(context, '/assist_live'),
          ),

          ListTile(
            title: Text("Assistive Live Urdu"),
            onTap: () => Navigator.pushNamed(context, '/assist_urdu'),
          )
        ],
      ),
    );
  }
}

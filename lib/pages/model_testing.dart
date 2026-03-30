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
            title: Text("Depth Estimation Model New"),
            onTap: () => Navigator.pushNamed(context, '/onnx'),
          ),
          
          ListTile(
            title: Text("Obstacle Detection Model"),
            onTap: () => Navigator.pushNamed(context, '/yolo10n'),
          ),

          ListTile(
            title: Text("Obstacle Detection Model"),
            onTap: () => Navigator.pushNamed(context, '/best_yolo'),
          ),

          ListTile(
            title: Text("Assistive Live"),
            onTap: () => Navigator.pushNamed(context, '/assist_live'),
          ),
        ],
      ),
    );
  }
}

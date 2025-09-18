import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:snackflix/utils/router.dart';

class PermissionsGateScreen extends StatefulWidget {
  @override
  _PermissionsGateScreenState createState() => _PermissionsGateScreenState();
}

class _PermissionsGateScreenState extends State<PermissionsGateScreen> {
  void _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      Navigator.pushNamed(context, AppRouter.parentSetup);
    } else if (status.isPermanentlyDenied) {
      openAppSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Camera Permission')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                'SnackFlix needs camera access to verify that your child is eating.',
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                child: Text('Allow Camera'),
                onPressed: _requestCameraPermission,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
